#!/usr/bin/env bash
# Gate W150 — flag desconhecida e procedência verificável no liaison (issue #51).
#
# Dois defeitos que corrompiam mensagem ou metadado SEM aviso, erro ou exit diferente de zero.
#
# (a) Todo parser de flags de `liaison-ops.sh` terminava em `*) shift ;;` — qualquer argumento que
#     o subcomando não conhecesse era descartado calado. O caso de campo: `ack ... --body-file
#     corpo.md` publicava o ack com rc 0 e SEM corpo nenhum (só `send` aceita `--body-file`), e a
#     sessão que o publicou acreditou ter anexado o relatório. O mesmo caminho engolia typo:
#     `--subjet` publicava mensagem sem assunto.
#
# (b) O campo `trust` era atribuído na escrita e não havia instrumento que o verificasse depois.
#     `content_sha` o exclui DELIBERADAMENTE (varia entre cópias, por desenho), então verificação
#     por hash é estruturalmente cega a ele. Uma restauração de log truncado copiou a réplica de um
#     peer sobre o log próprio: conteúdo íntegro, `msg_id` e `content_sha` conferindo, e as
#     mensagens próprias passaram a se declarar `untrusted-peer` — invertendo a procedência do log
#     inteiro num ecossistema cuja regra é "conteúdo de peer é dado, nunca instrução".
#
#   [1] `ack ... --body-file` reproduz o caso de campo: REPROVA nomeando a flag e dizendo o que usar
#       no lugar, e NÃO publica ack — antes publicava com rc 0, em silêncio, sem corpo algum
#   [2] typo de flag (`--subjet`) no ack REPROVA em vez de publicar mensagem sem assunto
#   [3] flag conhecida continua aceita (controle: parser que reprova tudo não corrige nada)
#   [4] varredura de TODOS os subcomandos declarados no cabeçalho de uso — conjunto não vazio, a
#       tabela do gate cobre cada um, e cada um reprova a flag desconhecida NOMEANDO flag e subcomando
#   [5] estrutura: nenhum `*) shift ;;` sobrou e todo parser de flags reprova o desconhecido
#   [6] procedência: log próprio coerente PASSA, sobre conjunto comprovadamente não vazio
#   [7] procedência: `trust` invertido no log próprio REPROVA nomeando arquivo e msg_id (alvo morto)
#   [8] procedência: mensagem no log de um PEER que se declara `trust: self` REPROVA
#   [9] procedência: `send --authored-by` grava `untrusted-peer` no log PRÓPRIO e isso NÃO reprova
#  [10] procedência que não pôde ser derivada sobre store não vazio REPROVA em vez de sair calada
#  [11] a cobrança de ack diz QUANTAS threads examinou (instância 1 da issue #49)
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPS="$WS/template/.forge/scripts/liaison-ops.sh"
T="$(mktemp -d /tmp/forge-w150.XXXXXX)"
trap 'rm -rf "$T"' EXIT

CH=axis-contracts
TH=tenant-canonical-identity
TH_S=sweep-thread
HUB="$T/hub"
OWNER=axis-go-cloud
CONSUMER=axis-fare-validator
SWEEPER=axis-sweep
BOGUS=--forge-flag-inexistente

mk_repo() { # mk_repo <dir-name>
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/" || return 1
  cp -R "$WS/template/.forge/templates" "$dir/.forge/" || return 1
  git -C "$dir" init -q || return 1
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" commit --allow-empty -qm init >/dev/null || return 1
}

LG() { # LG <repo> <args...>
  local repo="$1"; shift
  FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"
}

ACKCHECK() { # ACKCHECK <repo> — o gate de pre-push do liaison, rodado como o pre-push o roda
  local repo="$1"
  FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/check-liaison-acks.sh"
}

# Conta mensagens de um kind num arquivo de log (0 quando o arquivo não existe).
count_kind() { # count_kind <arquivo-jsonl> <kind>
  node -e '
const fs = require("fs");
const [file, kind] = process.argv.slice(1);
if (!fs.existsSync(file)) { process.stdout.write("0"); process.exit(0); }
let n = 0;
for (const l of fs.readFileSync(file, "utf8").split("\n")) { const t = l.trim(); if (!t) continue; if (JSON.parse(t).kind === kind) n++; }
process.stdout.write(String(n));
' "$1" "$2"
}

# Descreve o corpo da ÚLTIMA mensagem de um kind — é o que a sessão de campo teve de conferir em
# bytes, no destino, para descobrir que o corpo simplesmente não existia.
body_state() { # body_state <arquivo-jsonl> <kind>
  node -e '
const fs = require("fs");
const [file, kind] = process.argv.slice(1);
if (!fs.existsSync(file)) { process.stdout.write("(sem log)"); process.exit(0); }
let last = null;
for (const l of fs.readFileSync(file, "utf8").split("\n")) { const t = l.trim(); if (!t) continue; const m = JSON.parse(t); if (m.kind === kind) last = m; }
if (!last) { process.stdout.write("(nenhuma mensagem do kind)"); process.exit(0); }
process.stdout.write(`${last.msg_id}: body=${last.body ? "presente" : "AUSENTE"} body_ref=${last.body_ref ? "presente" : "AUSENTE"}`);
' "$1" "$2"
}

msgs_in_channel() { # msgs_in_channel <dir-do-canal> -> total de mensagens em todos os logs
  node -e '
const fs = require("fs"), path = require("path");
const dir = path.join(process.argv[1], "log");
if (!fs.existsSync(dir)) { process.stdout.write("0"); process.exit(0); }
let n = 0;
for (const f of fs.readdirSync(dir).filter((x) => x.endsWith(".jsonl"))) {
  for (const l of fs.readFileSync(path.join(dir, f), "utf8").split("\n")) if (l.trim()) n++;
}
process.stdout.write(String(n));
' "$1"
}

# Reescreve o `trust` de UMA mensagem — a corrupção que nenhuma verificação por hash enxerga,
# porque content_sha exclui o campo por desenho. Devolve o msg_id tocado.
set_trust() { # set_trust <arquivo-jsonl> <índice-0-based> <valor>
  node -e '
const fs = require("fs");
const [file, idxRaw, value] = process.argv.slice(1);
const lines = fs.readFileSync(file, "utf8").split("\n").filter((l) => l.trim());
const idx = Number(idxRaw);
if (!lines[idx]) { console.error("índice fora do log"); process.exit(1); }
const m = JSON.parse(lines[idx]);
m.trust = value;
lines[idx] = JSON.stringify(m);
fs.writeFileSync(file, lines.join("\n") + "\n");
process.stdout.write(m.msg_id);
' "$1" "$2" "$3"
}

# --- montagem ------------------------------------------------------------------------------------
mk_repo owner    || { echo "FAIL [setup]: não foi possível montar o repositório do dono do contrato"; exit 1; }
mk_repo consumer || { echo "FAIL [setup]: não foi possível montar o repositório consumidor"; exit 1; }
mk_repo sweep    || { echo "FAIL [setup]: não foi possível montar o repositório da varredura"; exit 1; }

for r in owner:$OWNER consumer:$CONSUMER; do
  repo="${r%%:*}"; id="${r##*:}"
  LG "$repo" open "$CH" --self "$id" --participants "$OWNER,$CONSUMER" >/dev/null \
    || { echo "FAIL [setup]: open do canal em $repo reprovou"; exit 1; }
  LG "$repo" transport set "$CH" --kind fs --path "$HUB" >/dev/null \
    || { echo "FAIL [setup]: transport set em $repo reprovou"; exit 1; }
done

LG owner thread open "$CH" "$TH" --subject "identidade canônica de tenant" --participants "$OWNER,$CONSUMER" >/dev/null \
  || { echo "FAIL [setup]: thread open reprovou"; exit 1; }
LG owner send "$CH" --thread "$TH" --kind contract-change --subject "tenant_id passa a ser obrigatório" --requires-ack >/dev/null \
  || { echo "FAIL [setup]: send do contract-change reprovou"; exit 1; }
LG owner sync "$CH" >/dev/null    || { echo "FAIL [setup]: sync do owner reprovou"; exit 1; }
LG consumer sync "$CH" >/dev/null || { echo "FAIL [setup]: sync do consumer reprovou"; exit 1; }

TARGET="$OWNER-0002"
CHDIR="$T/consumer/.forge/liaison/$CH"
OWN_LOG="$CHDIR/log/$CONSUMER.jsonl"
PEER_LOG="$CHDIR/log/$OWNER.jsonl"
grep -q "\"msg_id\":\"$TARGET\"" "$PEER_LOG" \
  || { echo "FAIL [setup]: $TARGET não chegou ao consumidor — o cenário não reproduz a issue"; exit 1; }

printf 'relatório de adoção do tenant_id\n' > "$T/corpo.md"

echo "[1] ack --body-file reprova nomeando a flag e não publica ack (caso de campo)"
out1="$(LG consumer ack "$CH" "$TARGET" --subject "ack com relatório" --body-file "$T/corpo.md" 2>&1)"; rc1=$?
if [ "$rc1" -eq 0 ]; then
  echo "FAIL [1]: 'ack --body-file' publicou com rc 0 e sem aviso — $(body_state "$OWN_LOG" ack); é o silêncio do caso de campo: a sessão acreditou ter anexado o corpo e o corpo não existe no destino. Saída: $out1"
  exit 1
fi
grep -q "flag desconhecida" <<<"$out1" \
  || { echo "FAIL [1]: a reprovação não diz que a flag é desconhecida: $out1"; exit 1; }
grep -q -- "--body-file" <<<"$out1" \
  || { echo "FAIL [1]: a reprovação não NOMEIA a flag rejeitada: $out1"; exit 1; }
grep -q "subcomando 'ack'" <<<"$out1" \
  || { echo "FAIL [1]: a reprovação não diz QUAL subcomando não aceita a flag — quem escreveu --body-file num ack conclui que ela não existe em lugar nenhum: $out1"; exit 1; }
grep -q -- "--subject" <<<"$out1" \
  || { echo "FAIL [1]: a reprovação não lista as flags aceitas pelo ack: $out1"; exit 1; }
grep -q "send" <<<"$out1" \
  || { echo "FAIL [1]: a reprovação não diz o que usar no lugar (o corpo tem um único caminho de escrita, o send): $out1"; exit 1; }
n_ack1="$(count_kind "$OWN_LOG" ack)"
[ "${n_ack1:-0}" -eq 0 ] \
  || { echo "FAIL [1]: a chamada reprovada AINDA publicou ${n_ack1} ack(s) — reprovar depois de escrever não corrige o caso"; exit 1; }
echo "OK [1]"

echo "[2] typo de flag no ack reprova em vez de publicar mensagem sem assunto"
out2="$(LG consumer ack "$CH" "$TARGET" --subjet "ack do contract-change" 2>&1)"; rc2=$?
[ "$rc2" -ne 0 ] \
  || { echo "FAIL [2]: '--subjet' foi engolido e o ack foi publicado sem assunto (rc 0) — $(body_state "$OWN_LOG" ack). Saída: $out2"; exit 1; }
grep -q -- "--subjet" <<<"$out2" \
  || { echo "FAIL [2]: a reprovação não nomeia a flag digitada errado: $out2"; exit 1; }
n_ack2="$(count_kind "$OWN_LOG" ack)"
[ "${n_ack2:-0}" -eq 0 ] \
  || { echo "FAIL [2]: o typo publicou ${n_ack2} ack(s)"; exit 1; }
echo "OK [2]"

echo "[3] flag conhecida continua aceita (controle contra um parser que reprova tudo)"
out3="$(LG consumer ack "$CH" "$TARGET" --subject "ack do contract-change" --reason acknowledged 2>&1)"; rc3=$?
[ "$rc3" -eq 0 ] \
  || { echo "FAIL [3]: ack com flags conhecidas (--subject/--reason) reprovou (rc $rc3): $out3"; exit 1; }
n_ack3="$(count_kind "$OWN_LOG" ack)"
[ "${n_ack3:-0}" -eq 1 ] \
  || { echo "FAIL [3]: esperado exatamente 1 ack publicado, obtidos ${n_ack3:-0}"; exit 1; }
out3b="$(LG consumer inbox "$CH" --thread "$TH" 2>&1)"; rc3b=$?
[ "$rc3b" -eq 0 ] \
  || { echo "FAIL [3]: inbox --thread (flag conhecida) reprovou (rc $rc3b): $out3b"; exit 1; }
echo "OK [3]"

# --- varredura de TODOS os subcomandos ------------------------------------------------------------
# Os subcomandos são LIDOS do cabeçalho de uso do próprio script: um subcomando novo entra na
# varredura sozinho, e se ele não estiver na tabela de invocação abaixo o gate reprova — sem isso,
# o próximo subcomando escrito repete o defeito e nada denuncia.
LABELS="$(grep -E '^#   liaison-ops\.sh ' "$OPS" | sed 's/^#   liaison-ops\.sh //' | awk '{
  lbl = $1;
  if (NF > 1 && $2 ~ /^[a-z][a-z-]*$/) lbl = lbl " " $2;
  print lbl;
}' | LC_ALL=C sort -u)"
n_labels="$(printf '%s\n' "$LABELS" | grep -c .)"

SWEEP_OUT="$T/sweep-out"
mkdir -p "$SWEEP_OUT/log"
LG sweep open "$CH" --self "$SWEEPER" --participants "$SWEEPER,$OWNER" >/dev/null \
  || { echo "FAIL [setup]: open do canal de varredura reprovou"; exit 1; }
LG sweep transport set "$CH" --kind fs --path "$HUB" >/dev/null \
  || { echo "FAIL [setup]: transport set da varredura reprovou"; exit 1; }
LG sweep thread open "$CH" "$TH_S" --subject "varredura" --participants "$SWEEPER,$OWNER" >/dev/null \
  || { echo "FAIL [setup]: thread open da varredura reprovou"; exit 1; }
SWEEP_MSG="$SWEEPER-0001"

run_sub() { # run_sub <label> — invoca o subcomando com a flag desconhecida no fim
  case "$1" in
    "open")              LG sweep open "$CH" --self "$SWEEPER" --participants "$SWEEPER,$OWNER" "$BOGUS" ;;
    "thread open")       LG sweep thread open "$CH" outra-thread --subject s --participants "$SWEEPER,$OWNER" "$BOGUS" ;;
    "thread join")       LG sweep thread join "$CH" "$TH_S" "$BOGUS" ;;
    "thread list")       LG sweep thread list "$CH" "$BOGUS" ;;
    "send")              LG sweep send "$CH" --thread "$TH_S" --kind note --subject s "$BOGUS" ;;
    "ack")               LG sweep ack "$CH" "$SWEEP_MSG" "$BOGUS" ;;
    "inbox")             LG sweep inbox "$CH" "$BOGUS" ;;
    "read")              LG sweep read "$CH" --upto "$SWEEP_MSG" "$BOGUS" ;;
    "status")            LG sweep status "$CH" "$BOGUS" ;;
    "export")            LG sweep export "$CH" --out "$SWEEP_OUT" "$BOGUS" ;;
    "import")            LG sweep import "$CH" --from "$SWEEP_OUT" "$BOGUS" ;;
    "conflicts list")    LG sweep conflicts list "$CH" "$BOGUS" ;;
    "conflicts resolve") LG sweep conflicts resolve "$CH" "$OWNER" 1 "$BOGUS" ;;
    "peer set")          LG sweep peer set "$CH" "$OWNER" --path "$T/owner" "$BOGUS" ;;
    "peer-path")         LG sweep peer-path "$CH" "$OWNER" "$BOGUS" ;;
    "transport set")     LG sweep transport set "$CH" --kind fs --path "$HUB" "$BOGUS" ;;
    "transport show")    LG sweep transport show "$CH" "$BOGUS" ;;
    "transport probe")   LG sweep transport probe "$CH" "$BOGUS" ;;
    "sync")              LG sweep sync "$CH" "$BOGUS" ;;
    "render")            LG sweep render "$CH" "$BOGUS" ;;
    *) return 99 ;;
  esac
}

echo "[4] todos os subcomandos declarados reprovam flag desconhecida, nomeando flag e subcomando"
[ "${n_labels:-0}" -ge 20 ] \
  || { echo "FAIL [4]: só ${n_labels:-0} subcomando(s) lido(s) do cabeçalho de uso de $OPS — uma varredura sobre conjunto vazio ou raso não mede nada"; exit 1; }
while IFS= read -r label; do
  [ -n "$label" ] || continue
  out="$(run_sub "$label" 2>&1)"; rc=$?
  if [ "$rc" -eq 99 ]; then
    echo "FAIL [4]: subcomando '$label' está declarado no cabeçalho de uso mas NÃO tem invocação na tabela deste gate — subcomando novo entra na varredura ou o defeito volta pela porta seguinte"
    exit 1
  fi
  [ "$rc" -ne 0 ] \
    || { echo "FAIL [4]: '$label' aceitou '$BOGUS' em silêncio (rc 0). Saída: $out"; exit 1; }
  grep -q "flag desconhecida" <<<"$out" \
    || { echo "FAIL [4]: '$label' reprovou (rc $rc) mas por outro motivo — a flag desconhecida segue passando: $out"; exit 1; }
  grep -q -- "$BOGUS" <<<"$out" \
    || { echo "FAIL [4]: '$label' não nomeia a flag rejeitada: $out"; exit 1; }
  grep -q "subcomando '$label'" <<<"$out" \
    || { echo "FAIL [4]: '$label' não nomeia o subcomando na mensagem (o conjunto de flags varia por subcomando): $out"; exit 1; }
done <<EOF_LABELS
$LABELS
EOF_LABELS
echo "OK [4] ($n_labels subcomandos)"

echo "[5] nenhum parser de flags sobrou com o descarte silencioso"
n_silent="$(grep -c '\*) shift ;;' "$OPS")"
[ "${n_silent:-0}" -eq 0 ] \
  || { echo "FAIL [5]: ${n_silent} ocorrência(s) de '*) shift ;;' em $OPS — descarte silencioso de argumento desconhecido"; exit 1; }
n_loops="$(grep -c 'while \[ \$# -gt 0 \]' "$OPS")"
n_reject="$(grep -c '\*) _reject_unknown' "$OPS")"
[ "${n_loops:-0}" -ge 12 ] \
  || { echo "FAIL [5]: só ${n_loops:-0} parser(es) de flags encontrado(s) em $OPS — a contagem virou vácua e a asserção não mede nada"; exit 1; }
[ "${n_reject:-0}" -eq "${n_loops:-0}" ] \
  || { echo "FAIL [5]: ${n_loops} parser(es) de flags e apenas ${n_reject} reprovando o desconhecido — algum parser ainda engole"; exit 1; }
echo "OK [5]"

# --- procedência verificável ---------------------------------------------------------------------
echo "[6] log próprio coerente passa, sobre conjunto varrido não vazio"
n_msgs="$(msgs_in_channel "$CHDIR")"
[ "${n_msgs:-0}" -ge 3 ] \
  || { echo "FAIL [6]: só ${n_msgs:-0} mensagem(ns) no canal do consumidor — a verificação varreria quase nada"; exit 1; }
[ -s "$OWN_LOG" ] || { echo "FAIL [6]: o log próprio do consumidor está vazio — não há procedência 'self' a verificar"; exit 1; }
[ -s "$PEER_LOG" ] || { echo "FAIL [6]: o log do peer está vazio — não há procedência 'untrusted-peer' a verificar"; exit 1; }
out6="$(ACKCHECK consumer 2>&1)"; rc6=$?
[ "$rc6" -eq 0 ] \
  || { echo "FAIL [6]: canal íntegro reprovou (rc $rc6): $out6"; exit 1; }
grep -q "liaison-trust" <<<"$out6" \
  || { echo "FAIL [6]: o pre-push não verifica procedência — nenhuma linha liaison-trust na saída: $out6"; exit 1; }
grep -qE "liaison-trust — [0-9]+ mensagem" <<<"$out6" \
  || { echo "FAIL [6]: a verificação de procedência não diz QUANTAS mensagens varreu — um 'OK' sobre conjunto vazio é indistinguível de verificação funcionando: $out6"; exit 1; }
echo "OK [6]"

echo "[7] trust invertido no log próprio reprova, nomeando arquivo e msg_id"
cp "$OWN_LOG" "$T/own.bak"
CORRUPTED="$(set_trust "$OWN_LOG" 0 untrusted-peer)" \
  || { echo "FAIL [7]: não foi possível corromper o trust do log próprio"; exit 1; }
out7="$(ACKCHECK consumer 2>&1)"; rc7=$?
[ "$rc7" -ne 0 ] \
  || { echo "FAIL [7]: mensagem PRÓPRIA declarando 'untrusted-peer' passou (rc 0) — é literalmente a corrupção do caso de campo, invisível a qualquer verificação por hash porque content_sha exclui trust: $out7"; exit 1; }
grep -q "$CORRUPTED" <<<"$out7" \
  || { echo "FAIL [7]: a reprovação não nomeia a mensagem corrompida ($CORRUPTED): $out7"; exit 1; }
grep -q "$CONSUMER.jsonl" <<<"$out7" \
  || { echo "FAIL [7]: a reprovação não nomeia o arquivo de log em que a incoerência está: $out7"; exit 1; }
cp "$T/own.bak" "$OWN_LOG"
out7b="$(ACKCHECK consumer 2>&1)"; rc7b=$?
[ "$rc7b" -eq 0 ] \
  || { echo "FAIL [7]: restauração do log não voltou ao verde (rc $rc7b) — o cenário seguinte mediria outro estado: $out7b"; exit 1; }
echo "OK [7]"

echo "[8] mensagem no log de um peer que se declara 'self' reprova"
cp "$PEER_LOG" "$T/peer.bak"
SPOOFED="$(set_trust "$PEER_LOG" 0 self)" \
  || { echo "FAIL [8]: não foi possível corromper o trust do log do peer"; exit 1; }
out8="$(ACKCHECK consumer 2>&1)"; rc8=$?
[ "$rc8" -ne 0 ] \
  || { echo "FAIL [8]: mensagem de peer declarando 'self' passou (rc 0) — a procedência do log inteiro fica sem verificação: $out8"; exit 1; }
grep -q "$SPOOFED" <<<"$out8" \
  || { echo "FAIL [8]: a reprovação não nomeia a mensagem forjada ($SPOOFED): $out8"; exit 1; }
cp "$T/peer.bak" "$PEER_LOG"
echo "OK [8]"

echo "[9] send --authored-by grava untrusted-peer no log próprio e isso NÃO é reprovado"
LG consumer send "$CH" --thread "$TH" --kind note --subject "eco do peer" --authored-by "$OWNER" >/dev/null \
  || { echo "FAIL [9]: send --authored-by reprovou"; exit 1; }
n_authored="$(node -e '
const fs = require("fs");
const file = process.argv[1];
let n = 0;
for (const l of fs.readFileSync(file, "utf8").split("\n")) { const t = l.trim(); if (!t) continue; const m = JSON.parse(t); if (m.authored_by && m.trust === "untrusted-peer") n++; }
process.stdout.write(String(n));
' "$OWN_LOG")"
[ "${n_authored:-0}" -ge 1 ] \
  || { echo "FAIL [9]: nenhuma mensagem com authored_by e trust untrusted-peer no log próprio — o falso positivo que este cenário protege não existiria e o 'OK' não mediria nada"; exit 1; }
out9="$(ACKCHECK consumer 2>&1)"; rc9=$?
[ "$rc9" -eq 0 ] \
  || { echo "FAIL [9]: conteúdo de autoria externa gravado no log próprio (authored_by) foi tratado como incoerência (rc $rc9) — falso positivo que travaria o push de quem usa o ask: $out9"; exit 1; }
echo "OK [9]"

echo "[10] store não vazio cuja procedência não pôde ser derivada reprova, em vez de calar"
# `self` ausente é o único caminho pelo qual a verificação de procedência não tem de onde derivar
# nada. Devolver 0 sem uma linha faria "não verifiquei" e "verifiquei e está coerente" terminarem no
# mesmo silêncio para quem lê a saída do push — a classe de defeito que este gate inteiro fecha. Um
# `liaison.yaml` sem `self` sobre um store COM mensagens não é estado legítimo: `send` e `import`
# exigem `self`, então o store só chegou ali por edição, restauração ou merge do arquivo de config.
cp "$T/consumer/.forge/liaison/liaison.yaml" "$T/cfg.bak"
grep -v -e '^self:' -e '^  id:' "$T/cfg.bak" > "$T/consumer/.forge/liaison/liaison.yaml"
n_orphan="$(msgs_in_channel "$CHDIR")"
[ "${n_orphan:-0}" -ge 1 ] \
  || { echo "FAIL [10]: o store do consumidor está vazio — o cenário não distinguiria 'não verifiquei' de 'nada a verificar'"; exit 1; }
out10="$(ACKCHECK consumer 2>&1)"; rc10=$?
[ "$rc10" -ne 0 ] \
  || { echo "FAIL [10]: ${n_orphan} mensagem(ns) ficaram SEM verificação de procedência e o push seguiu (rc 0): $out10"; exit 1; }
grep -q "liaison-trust" <<<"$out10" \
  || { echo "FAIL [10]: a reprovação não nomeia a verificação que não pôde rodar: $out10"; exit 1; }
cp "$T/cfg.bak" "$T/consumer/.forge/liaison/liaison.yaml"
out10b="$(ACKCHECK consumer 2>&1)"; rc10b=$?
[ "$rc10b" -eq 0 ] \
  || { echo "FAIL [10]: restaurar o self não voltou ao verde (rc $rc10b): $out10b"; exit 1; }
grep -q "OK liaison-trust" <<<"$out10b" \
  || { echo "FAIL [10]: com o self de volta a verificação não voltou a rodar: $out10b"; exit 1; }
echo "OK [10]"

echo "[11] a cobrança de ack diz quantas threads examinou (instância 1 da issue #49)"
# `OK liaison-acks — nenhum ack pendente deste repositório` era o mesmo desfecho para "não
# participo de thread nenhuma neste canal" e para "participo de nove e nenhuma me deve ack". O
# contador de controle separa os dois: cobertura e ausência de cobertura não podem colapsar.
out11="$(ACKCHECK consumer 2>&1)"; rc11=$?
[ "$rc11" -eq 0 ] || { echo "FAIL [11]: canal íntegro reprovou (rc $rc11): $out11"; exit 1; }
grep -qE "liaison-acks — [0-9]+ thread\(s\)" <<<"$out11" \
  || { echo "FAIL [11]: a cobrança de ack não diz quantas threads examinou: $out11"; exit 1; }
n_th="$(sed -n 's/.*liaison-acks — \([0-9]\{1,\}\) thread(s).*/\1/p' <<<"$out11" | head -1)"
[ "${n_th:-0}" -ge 1 ] \
  || { echo "FAIL [11]: contou ${n_th:-0} thread(s) — o 'OK' seria sobre conjunto vazio e não mediria nada: $out11"; exit 1; }
echo "OK [11]"

echo "PASS w150-liaison-flag-and-trust"
