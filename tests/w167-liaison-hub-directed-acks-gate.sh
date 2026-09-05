#!/usr/bin/env bash
# Gate W167 — check-liaison-acks lê o HUB declarado no transporte, não a réplica local (issue #84).
#
# Medido em campo: dois repositórios do ecossistema Axis fecharam a rodada com "acks a zero"
# enquanto o hub tinha 15 e 19 mensagens deles pendentes — porque o gate decidia sobre a réplica
# local (o que o último `sync` trouxe), nunca sobre o canal de entrega declarado. Um repositório
# que nunca sincroniza tem, por construção, zero acks pendentes segundo a réplica.
#
#   [1] réplica local NUNCA sincronizada REPROVA acks devidos que só existem no hub — dirigido pelo
#       MESMO caminho do hook real (ACKCHECK roda check-liaison-acks.sh como o pre-push roda),
#       contra um hub `fs` de verdade, SEM nenhum sync de antemão (é exatamente o caso medido: o
#       repositório que mais precisa reprovar é o que nunca puxou)
#   [2] depois de sync + ack, o MESMO canal passa limpo (controle: o gate não fica preso em FAIL)
#   [3] hub inacessível (diretório do transporte removido) REPROVA nomeando o canal — mesmo em
#       enforce:warn, o mesmo raciocínio incondicional do trust-check
#   [4] chaveamento por PAR (canal, msg_id), nunca só por msg_id: um ack publicado no canal ERRADO
#       não satisfaz a cobrança do canal certo, mesmo com o MESMO texto de msg_id nos dois (seq é
#       por remetente-E-canal, então a colisão de string é legítima e esperada)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w167.XXXXXX)"
trap 'rm -rf "$T"' EXIT

CH=contracts-fare
CH2=contracts-device
TH=fare-grpc-v1
HUB="$T/hub"
OWNER=axis-go-cloud
CONSUMER=axis-fare-validator

mk_repo() { # mk_repo <dir-name>
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  cp -R "$WS/template/.forge/ledger" "$dir/.forge/"
  cp "$WS/template/.forge/forge.yaml" "$dir/.forge/forge.yaml"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" commit --allow-empty -qm init >/dev/null
}

LG() { local repo="$1"; shift; FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }

# ACKCHECK — roda check-liaison-acks.sh EXATAMENTE como o pre-push roda (mesmo FORGE_ROOT, sem
# argumento nenhum, cwd dentro do repo): é o requisito explícito desta issue, o gate tem de ser
# dirigido pelo caminho real, não por uma chamada de conveniência do teste.
ACKCHECK() { local repo="$1"; (cd "$T/$repo" && FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/check-liaison-acks.sh"); }

set_enforce() { # set_enforce <repo> <warn|block>
  node -e '
    const fs=require("fs"); const [f,v]=process.argv.slice(1);
    let y=fs.readFileSync(f,"utf8");
    if (/^liaison:/m.test(y)) y=y.replace(/^(liaison:\n(?:[ ].*\n)*?[ ]+enforce:[ ]*)(warn|block)/m, `$1${v}`);
    else y+=`\nliaison:\n  auto: false\n  enforce: ${v}\n`;
    fs.writeFileSync(f,y);
  ' "$T/$1/.forge/forge.yaml" "$2"
}

mk_repo owner
mk_repo consumer

LG owner    open "$CH" --self "$OWNER"    --participants "$OWNER,$CONSUMER" >/dev/null
LG consumer open "$CH" --self "$CONSUMER" --participants "$OWNER,$CONSUMER" >/dev/null
LG owner    transport set "$CH" --kind fs --path "$HUB" >/dev/null
LG consumer transport set "$CH" --kind fs --path "$HUB" >/dev/null
set_enforce consumer block

LG owner thread open "$CH" "$TH" --subject "gRPC device-facing v1" \
  --participants "$OWNER,$CONSUMER" --body "abertura" >/dev/null
MSGID="$(LG owner send "$CH" --thread "$TH" --kind contract-change --subject "fare_cents" \
  --body "novo campo fare_cents" --contract-files contracts/fare.proto --requires-ack)"
MSGID="${MSGID#*— }"; MSGID="${MSGID%% *}"
LG owner sync "$CH" >/dev/null

echo "[1] réplica NUNCA sincronizada reprova, lendo o hub diretamente (dirigido como o pre-push dirige)"
# Pré-condição do bug medido: o consumidor NUNCA rodou sync — a pasta local do canal existe (por
# causa do 'open'), mas o log local não tem thread nem contract-change nenhum.
[ ! -s "$T/consumer/.forge/liaison/$CH/log/$OWNER.jsonl" ] \
  || { echo "FAIL [1]: pré-condição — a réplica do consumidor não deveria conhecer o log do owner"; exit 1; }
set +e
OUT1="$(ACKCHECK consumer 2>&1)"; RC1=$?
set -e
[ "$RC1" -ne 0 ] || { echo "FAIL [1]: check-liaison-acks aprovou com a réplica local desatualizada e o hub com cobrança pendente: $OUT1"; exit 1; }
grep -q "$MSGID" <<<"$OUT1" || { echo "FAIL [1]: a reprovação não cita o msg_id pendente no hub: $OUT1"; exit 1; }
grep -qi "liaison-acks" <<<"$OUT1" || { echo "FAIL [1]: a reprovação não é do gate liaison-acks: $OUT1"; exit 1; }
echo "OK [1]"

echo "[2] depois de sync + ack, o mesmo canal passa limpo (controle)"
LG consumer sync "$CH" >/dev/null
LG consumer ack "$CH" "$MSGID" --body "confirmado, sigo com uint64" >/dev/null
OUT2="$(ACKCHECK consumer 2>&1)"; RC2=$?
[ "$RC2" -eq 0 ] || { echo "FAIL [2]: ack publicado (na réplica local, fonte sempre fresca do próprio) continuou reprovando: $OUT2"; exit 1; }
grep -qi "nenhum ack pendente\|examinada" <<<"$OUT2" || { echo "FAIL [2]: saída não confirma canal limpo: $OUT2"; exit 1; }
echo "OK [2]"

echo "[3] hub inacessível reprova nomeando o canal, mesmo em enforce:warn"
set_enforce consumer warn
mv "$HUB" "$T/hub-removido"
set +e
OUT3="$(ACKCHECK consumer 2>&1)"; RC3=$?
set -e
mv "$T/hub-removido" "$HUB"
[ "$RC3" -ne 0 ] || { echo "FAIL [3]: hub inacessível passou em enforce:warn (deveria reprovar incondicionalmente): $OUT3"; exit 1; }
grep -q "$CH" <<<"$OUT3" || { echo "FAIL [3]: a reprovação não nomeia o canal com hub inacessível: $OUT3"; exit 1; }
grep -qi "hub" <<<"$OUT3" || { echo "FAIL [3]: a reprovação não fala de hub inacessível: $OUT3"; exit 1; }
set_enforce consumer block
echo "OK [3]"

echo "[4] chaveamento por (canal, msg_id): ack no canal ERRADO não satisfaz a cobrança do canal certo"
# Segundo canal, MESMO par owner/consumer, HUB SEPARADO — o seq de 'owner' reinicia em 1 porque é
# um log NOVO (issue #84, ponto 1: seq é por remetente-E-canal, então a MESMA string de msg_id
# nasce legitimamente em dois canais com conteúdo e requires_ack diferentes).
HUB2="$T/hub2"
LG owner    open "$CH2" --self "$OWNER"    --participants "$OWNER,$CONSUMER" >/dev/null
LG consumer open "$CH2" --self "$CONSUMER" --participants "$OWNER,$CONSUMER" >/dev/null
LG owner    transport set "$CH2" --kind fs --path "$HUB2" >/dev/null
LG consumer transport set "$CH2" --kind fs --path "$HUB2" >/dev/null
LG owner thread open "$CH2" "$TH" --subject "device provisioning" --participants "$OWNER,$CONSUMER" --body "abertura" >/dev/null
MSGID2="$(LG owner send "$CH2" --thread "$TH" --kind contract-change --subject "device_id" \
  --body "novo campo device_id" --contract-files contracts/device.proto --requires-ack)"
MSGID2="${MSGID2#*— }"; MSGID2="${MSGID2%% *}"
LG owner sync "$CH2" >/dev/null
[ "$MSGID2" = "$MSGID" ] || { echo "FAIL [4]: pré-condição — os dois msg_id deveriam colidir como STRING ($MSGID vs $MSGID2) para o teste valer algo"; exit 1; }

LG consumer sync "$CH2" >/dev/null
# acka no canal 1 (CH), de novo, deliberadamente redundante — o que importa é que o consumidor
# NUNCA ackou nada no canal 2 (CH2). Se o gate chaveasse só por msg_id, o ack de CH já teria
# "satisfeito" CH2 também, porque o texto do msg_id é idêntico.
set +e
OUT4="$(ACKCHECK consumer 2>&1)"; RC4=$?
set -e
[ "$RC4" -ne 0 ] || { echo "FAIL [4]: o ack publicado no canal $CH satisfez (indevidamente) a cobrança do canal $CH2 — chaveamento só por msg_id"; exit 1; }
grep -q "$CH2/" <<<"$OUT4" || { echo "FAIL [4]: a reprovação não cita o canal $CH2 como pendente: $OUT4"; exit 1; }
grep -q "$MSGID2" <<<"$OUT4" || { echo "FAIL [4]: a reprovação não cita o msg_id pendente em $CH2: $OUT4"; exit 1; }
echo "OK [4]"

echo "PASS w167-liaison-hub-directed-acks-gate"
