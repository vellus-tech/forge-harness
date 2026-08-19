#!/usr/bin/env bash
# Gate W111 — transporte plugável e sync idempotente do liaison (Onda 2):
#   [1] transporte não configurado REPROVA (pré-requisito faltando nunca desliga o sync em silêncio)
#   [2] probe reprova quando o ponto de encontro não existe (manual não cria hub)
#   [3] fs: dois participantes convergem por sync, sem export/import manual
#   [4] quatro participantes: inbox --thread byte-idêntico nos que compartilham a thread
#   [5] participante parcial converge na sua thread sem receber a outra
#   [6] sync repetido é no-op (0 nova(s))
#   [7] push publica APENAS o próprio log — não regride o log de terceiro no hub
#   [8] divergência (peer reescreve posição já conhecida) REPROVA, quarentena a POSIÇÃO e não
#       sobrescreve a versão conhecida
#   [9] mensagem órfã de thread fica retida no sync e é liberada quando o thread-open chega
#   [10] manual é a primitiva: export|import produz o mesmo estado que sync
#   [11] git: transporte por branch dedicada em remote local converge
#   [12] gh: stub reprova com mensagem explícita e NUNCA invoca gh
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
T="$(mktemp -d /tmp/forge-w111.XXXXXX)"
trap 'rm -rf "$T"' EXIT

CH=contracts-fare
HUB="$T/hub"

mk_repo() {
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" commit --allow-empty -qm init >/dev/null
}

LG() { # LG <repo> <args...>
  local repo="$1"; shift
  FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"
}

_craft() { # _craft '<json parcial>' -> linha JSONL com content_sha REAL (nunca reimplementado no teste)
  node - "$LIB" "$1" <<'NODEEOF'
const { pathToFileURL } = require('url');
const { join } = require('path');
(async () => {
  const [, , lib, json] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const msg = JSON.parse(json);
  msg.content_sha = M.computeContentSha(msg);
  if (!msg.trust) msg.trust = 'self';
  process.stdout.write(JSON.stringify(msg));
})();
NODEEOF
}

dump_order() { # dump_order <channel-dir> -> {thread_id: [msg_id...]} determinístico
  node - "$LIB" "$1" <<'NODEEOF'
const { readFileSync, readdirSync, existsSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir] = process.argv;
  const { mergeLogs } = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')).sort() : [];
  const all = [];
  for (const f of files) for (const line of readFileSync(join(logDir, f), 'utf8').split('\n')) {
    const t = line.trim(); if (t) all.push(JSON.parse(t));
  }
  const { threads } = mergeLogs(all);
  const out = {};
  for (const id of Object.keys(threads).sort()) out[id] = threads[id].order;
  process.stdout.write(JSON.stringify(out, null, 2));
})();
NODEEOF
}

sha_of() { node -e "const{createHash}=require('crypto'),fs=require('fs');console.log(createHash('sha256').update(fs.readFileSync(process.argv[1])).digest('hex'))" "$1"; }

# Quatro participantes, espelhando o piloto real: o dono do contrato, dois consumidores, e um
# quarto que chega depois e participa de UMA thread só (participação parcial de verdade).
mk_repo gc; mk_repo fv; mk_repo pad; mk_repo dev
PARTS=axis-go-cloud,axis-fare-validator,axis-pad-simulator,axis-device-platform
LG gc  open "$CH" --self axis-go-cloud        --participants "$PARTS" >/dev/null
LG fv  open "$CH" --self axis-fare-validator  --participants "$PARTS" >/dev/null
LG pad open "$CH" --self axis-pad-simulator   --participants "$PARTS" >/dev/null
LG dev open "$CH" --self axis-device-platform --participants "$PARTS" >/dev/null

echo "[1] transporte não configurado REPROVA"
if LG gc sync "$CH" >"$T/out1.txt" 2>&1; then
  echo "FAIL [1]: sync sem transporte configurado deveria reprovar"; cat "$T/out1.txt"; exit 1
fi
grep -q "transporte não configurado" "$T/out1.txt" || { echo "FAIL [1]: mensagem de erro não explica o pré-requisito faltando"; cat "$T/out1.txt"; exit 1; }
echo "OK [1]"

echo "[2] probe reprova quando o ponto de encontro não existe (manual não cria hub)"
LG gc transport set "$CH" --kind manual --path "$T/hub-inexistente" >/dev/null
if LG gc transport probe "$CH" >"$T/out2.txt" 2>&1; then
  echo "FAIL [2]: probe deveria reprovar com ponto de encontro ausente"; cat "$T/out2.txt"; exit 1
fi
grep -qi "não existe\|ausente" "$T/out2.txt" || { echo "FAIL [2]: mensagem de probe não aponta o diretório ausente"; cat "$T/out2.txt"; exit 1; }
echo "OK [2]"

echo "[3] fs: dois participantes convergem por sync"
for r in gc fv pad dev; do LG "$r" transport set "$CH" --kind fs --path "$HUB" >/dev/null; done
LG gc transport probe "$CH" >/dev/null || { echo "FAIL [3]: probe do fs reprovou"; exit 1; }
LG gc thread open "$CH" fare-grpc-v1 --subject "gRPC device-facing v1" \
  --participants axis-go-cloud,axis-fare-validator,axis-pad-simulator --body "abertura" >/dev/null
LG gc send "$CH" --thread fare-grpc-v1 --kind contract-change --subject "fare_cents" \
  --body "novo campo fare_cents" --contract-files contracts/fare.proto --requires-ack >/dev/null
LG gc sync "$CH" >/dev/null
out3="$(LG fv sync "$CH")"
grep -q "2 nova" <<<"$out3" || { echo "FAIL [3]: fv não recebeu as 2 mensagens de gc: $out3"; exit 1; }
LG fv thread list "$CH" | grep -q "fare-grpc-v1" || { echo "FAIL [3]: thread não convergiu em fv"; exit 1; }
echo "OK [3]"

echo "[4] quatro participantes: inbox --thread byte-idêntico entre os que compartilham a thread"
LG fv thread join "$CH" fare-grpc-v1 --subject "axis-fare-validator entrou" >/dev/null
LG fv send "$CH" --thread fare-grpc-v1 --kind question --subject "fare_cents é signed?" --body "confirma tipo" --requires-ack >/dev/null
LG fv sync "$CH" >/dev/null
LG pad sync "$CH" >/dev/null
LG pad thread join "$CH" fare-grpc-v1 --subject "axis-pad-simulator entrou" >/dev/null
LG pad send "$CH" --thread fare-grpc-v1 --kind note --subject "simulador acompanha" --body "ok" >/dev/null
LG pad sync "$CH" >/dev/null
# Convergência total exige uma segunda rodada: quem publicou antes ainda não puxou o que veio depois.
for r in gc fv pad gc fv pad; do LG "$r" sync "$CH" >/dev/null; done
LG gc  inbox "$CH" --thread fare-grpc-v1 > "$T/inbox-gc.txt"
LG fv  inbox "$CH" --thread fare-grpc-v1 > "$T/inbox-fv.txt"
LG pad inbox "$CH" --thread fare-grpc-v1 > "$T/inbox-pad.txt"
cmp -s "$T/inbox-gc.txt" "$T/inbox-fv.txt" || { echo "FAIL [4]: inbox de gc e fv divergem"; diff "$T/inbox-gc.txt" "$T/inbox-fv.txt"; exit 1; }
cmp -s "$T/inbox-gc.txt" "$T/inbox-pad.txt" || { echo "FAIL [4]: inbox de gc e pad divergem"; diff "$T/inbox-gc.txt" "$T/inbox-pad.txt"; exit 1; }
grep -q "fare_cents é signed?" "$T/inbox-gc.txt" || { echo "FAIL [4]: inbox não contém a pergunta do consumidor"; cat "$T/inbox-gc.txt"; exit 1; }
echo "OK [4]"

echo "[5] participante parcial converge na sua thread sem receber a outra"
LG gc thread open "$CH" device-provisioning --subject "provisionamento de device" \
  --participants axis-go-cloud,axis-device-platform --body "abertura" >/dev/null
LG gc sync "$CH" >/dev/null
LG dev sync "$CH" >/dev/null
LG dev thread join "$CH" device-provisioning --subject "axis-device-platform entrou" >/dev/null
LG dev send "$CH" --thread device-provisioning --kind note --subject "entrou depois" --body "ok" >/dev/null
LG dev sync "$CH" >/dev/null
dev_threads="$(LG dev thread list "$CH")"
grep -q "device-provisioning" <<<"$dev_threads" || { echo "FAIL [5]: device-provisioning não convergiu em dev"; exit 1; }
LG gc sync "$CH" >/dev/null
LG gc inbox "$CH" --thread device-provisioning | grep -q "entrou depois" \
  || { echo "FAIL [5]: mensagem do participante parcial não chegou ao dono da thread"; exit 1; }
echo "OK [5]"

echo "[6] sync repetido é no-op"
LG fv sync "$CH" >/dev/null   # aquece: absorve o que [5] publicou
out6="$(LG fv sync "$CH")"
grep -q "0 nova" <<<"$out6" || { echo "FAIL [6]: sync repetido não foi no-op: $out6"; exit 1; }
order_before="$(dump_order "$T/fv/.forge/liaison/$CH")"
LG fv sync "$CH" >/dev/null
order_after="$(dump_order "$T/fv/.forge/liaison/$CH")"
[ "$order_before" = "$order_after" ] || { echo "FAIL [6]: sync repetido alterou a ordem"; exit 1; }
echo "OK [6]"

echo "[7] push publica APENAS o próprio log — não regride o log de terceiro no hub"
# fv avança e publica; gc (que ainda tem a versão curta de fv) faz sync — o push de gc não pode
# reescrever fv.jsonl no hub com a versão que gc conhece.
LG fv send "$CH" --thread fare-grpc-v1 --kind note --subject "avanço só do fv" --body "x" >/dev/null
LG fv send "$CH" --thread fare-grpc-v1 --kind note --subject "avanço 2 só do fv" --body "y" >/dev/null
LG fv sync "$CH" >/dev/null
hub_fv_before="$(sha_of "$HUB/$CH/log/axis-fare-validator.jsonl")"
lines_before="$(grep -c . "$HUB/$CH/log/axis-fare-validator.jsonl")"
local_fv_at_gc="$(grep -c . "$T/gc/.forge/liaison/$CH/log/axis-fare-validator.jsonl")"
[ "$local_fv_at_gc" -lt "$lines_before" ] || { echo "FAIL [7]: pré-condição falhou — gc já conhece o log completo de fv"; exit 1; }
LG gc sync "$CH" --push-only >/dev/null
hub_fv_after="$(sha_of "$HUB/$CH/log/axis-fare-validator.jsonl")"
[ "$hub_fv_before" = "$hub_fv_after" ] || { echo "FAIL [7]: push de gc reescreveu o log de fv no hub (regressão de terceiro)"; exit 1; }
echo "OK [7]"

echo "[8] divergência (peer reescreve posição já conhecida) REPROVA e quarentena a posição"
LG gc sync "$CH" >/dev/null
before_sha="$(sha_of "$T/gc/.forge/liaison/$CH/log/axis-fare-validator.jsonl")"
# Reescreve, no hub, a mensagem seq=1 de fv com outro conteúdo (content_sha internamente válido).
node - "$LIB" "$HUB/$CH/log/axis-fare-validator.jsonl" <<'NODEEOF'
const { readFileSync, writeFileSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, file] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const msgs = readFileSync(file, 'utf8').trim().split('\n').map((l) => JSON.parse(l));
  const i = msgs.findIndex((m) => m.seq === 1);
  const { content_sha, trust, ...rest } = msgs[i];
  const tampered = { ...rest, subject: 'HISTÓRIA REESCRITA', trust: 'self' };
  tampered.content_sha = M.computeContentSha(tampered);
  msgs[i] = tampered;
  writeFileSync(file, msgs.map((m) => JSON.stringify(m)).join('\n') + '\n');
})();
NODEEOF
if LG gc sync "$CH" >"$T/out8.txt" 2>&1; then
  echo "FAIL [8]: sync com log divergente deveria reprovar"; cat "$T/out8.txt"; exit 1
fi
grep -q "divergência" "$T/out8.txt" || { echo "FAIL [8]: saída não reporta divergência"; cat "$T/out8.txt"; exit 1; }
grep -q "axis-fare-validator" "$T/out8.txt" || { echo "FAIL [8]: saída não nomeia o remetente divergente"; cat "$T/out8.txt"; exit 1; }
after_sha="$(sha_of "$T/gc/.forge/liaison/$CH/log/axis-fare-validator.jsonl")"
[ "$before_sha" = "$after_sha" ] || { echo "FAIL [8]: log local foi tocado apesar da divergência"; exit 1; }
[ -f "$T/gc/.forge/liaison/$CH/conflicts/axis-fare-validator.seq-1.divergence.json" ] \
  || { echo "FAIL [8]: posição divergente não registrada em conflicts/"; ls "$T/gc/.forge/liaison/$CH/conflicts/"; exit 1; }
[ ! -f "$T/gc/.forge/liaison/$CH/conflicts/axis-fare-validator.divergence.json" ] \
  || { echo "FAIL [8]: registro agregado por remetente — quarentena é por posição (issue #48)"; exit 1; }
# restaura o hub para não contaminar os passos seguintes
LG fv sync "$CH" --push-only >/dev/null
echo "OK [8]"

echo "[9] mensagem órfã de thread fica retida no sync e é liberada quando o thread-open chega"
orphan="$(_craft "{\"msg_id\":\"axis-pad-simulator-0090\",\"channel\":\"$CH\",\"thread_id\":\"late-thread\",\"sender\":\"axis-pad-simulator\",\"seq\":90,\"lamport\":2,\"kind\":\"note\",\"in_reply_to\":null,\"requires_ack\":false,\"subject\":\"chegou antes da abertura\",\"body\":\"orfã\",\"refs\":{\"change_id\":null,\"contract_files\":[],\"commit\":null},\"created_at\":\"2026-01-01T00:00:00Z\"}")"
printf '%s\n' "$orphan" >> "$HUB/$CH/log/axis-pad-simulator.jsonl"
out9a="$(LG gc sync "$CH")"
grep -q "1 em quarentena" <<<"$out9a" || { echo "FAIL [9a]: órfã não ficou em quarentena: $out9a"; exit 1; }
LG gc thread list "$CH" | grep -q "late-thread" && { echo "FAIL [9a]: thread sem abertura apareceu resolvida"; exit 1; }
opener="$(_craft "{\"msg_id\":\"axis-pad-simulator-0091\",\"channel\":\"$CH\",\"thread_id\":\"late-thread\",\"sender\":\"axis-pad-simulator\",\"seq\":91,\"lamport\":1,\"kind\":\"thread-open\",\"in_reply_to\":null,\"requires_ack\":false,\"subject\":\"abertura tardia\",\"participants\":[\"axis-pad-simulator\",\"axis-go-cloud\"],\"refs\":{\"change_id\":null,\"contract_files\":[],\"commit\":null},\"created_at\":\"2026-01-01T00:00:00Z\"}")"
printf '%s\n' "$opener" >> "$HUB/$CH/log/axis-pad-simulator.jsonl"
out9b="$(LG gc sync "$CH")"
grep -q "0 em quarentena" <<<"$out9b" || { echo "FAIL [9b]: quarentena não liberada com o thread-open: $out9b"; exit 1; }
LG gc thread list "$CH" | grep -q "late-thread" || { echo "FAIL [9b]: late-thread não apareceu resolvida"; exit 1; }
echo "OK [9]"

echo "[10] manual é a primitiva: export|import produz o mesmo estado que sync"
mk_repo m1; mk_repo m2
LG m1 open "$CH" --self observer --participants "$PARTS",observer >/dev/null
LG m2 open "$CH" --self observer --participants "$PARTS",observer >/dev/null
# m1 pelo caminho manual (export do hub → import); m2 pelo transporte manual apontando ao mesmo dir.
mkdir -p "$T/bundle-manual/log" "$T/bundle-manual/blobs"
find "$HUB/$CH/log" -type f -name '*.jsonl' -exec cp {} "$T/bundle-manual/log/" \;
find "$HUB/$CH/blobs" -type f -exec cp {} "$T/bundle-manual/blobs/" \; 2>/dev/null || true
LG m1 import "$CH" --from "$T/bundle-manual" >/dev/null
LG m2 transport set "$CH" --kind manual --path "$T/bundle-manual" >/dev/null
LG m2 sync "$CH" --pull-only >/dev/null
order_m1="$(dump_order "$T/m1/.forge/liaison/$CH")"
order_m2="$(dump_order "$T/m2/.forge/liaison/$CH")"
[ "$order_m1" = "$order_m2" ] || { echo "FAIL [10]: export|import divergiu de sync"; diff <(echo "$order_m1") <(echo "$order_m2"); exit 1; }
grep -q "fare-grpc-v1" <<<"$order_m1" || { echo "FAIL [10]: estado vazio — comparação sem valor"; exit 1; }
echo "OK [10]"

echo "[11] git: transporte por branch dedicada em remote local converge"
git init -q --bare "$T/hub.git"
mk_repo g1; mk_repo g2
LG g1 open "$CH" --self axis-go-cloud       --participants axis-go-cloud,axis-fare-validator >/dev/null
LG g2 open "$CH" --self axis-fare-validator --participants axis-go-cloud,axis-fare-validator >/dev/null
LG g1 transport set "$CH" --kind git --remote "$T/hub.git" --branch "liaison/$CH" >/dev/null
LG g2 transport set "$CH" --kind git --remote "$T/hub.git" --branch "liaison/$CH" >/dev/null
LG g1 thread open "$CH" git-thread --subject "via git" --participants axis-go-cloud,axis-fare-validator --body "abertura" >/dev/null
LG g1 send "$CH" --thread git-thread --kind contract-change --subject "campo novo" --body "z" >/dev/null
LG g1 sync "$CH" >/dev/null
out11="$(LG g2 sync "$CH")"
grep -q "2 nova" <<<"$out11" || { echo "FAIL [11]: g2 não recebeu via git: $out11"; exit 1; }
LG g2 thread join "$CH" git-thread --subject "entrou" >/dev/null
LG g2 send "$CH" --thread git-thread --kind question --subject "de volta pelo git" --body "w" >/dev/null
LG g2 sync "$CH" >/dev/null
LG g1 sync "$CH" >/dev/null
LG g1 inbox "$CH" --thread git-thread | grep -q "de volta pelo git" || { echo "FAIL [11]: ida e volta pelo git não convergiu"; exit 1; }
echo "OK [11]"

echo "[12] gh: stub reprova com mensagem explícita e nunca invoca gh"
# (a checagem real é o grep abaixo; havia aqui um `grep ... && true` que nunca podia falhar — LDG-0032)
if grep -Eq '(^|[^A-Za-z_-])gh[[:space:]]+(issue|api|pr|repo)' "$WS/template/.forge/scripts/lib/transports/gh.sh"; then
  echo "FAIL [12]: transports/gh.sh invoca o binário gh (convenção: .sh nunca chama gh)"; exit 1
fi
LG g1 transport set "$CH" --kind gh --remote "owner/repo" >/dev/null
if LG g1 sync "$CH" >"$T/out12.txt" 2>&1; then
  echo "FAIL [12]: transporte gh deveria reprovar (stub)"; cat "$T/out12.txt"; exit 1
fi
grep -q "gh" "$T/out12.txt" || { echo "FAIL [12]: mensagem do stub não menciona o transporte"; cat "$T/out12.txt"; exit 1; }
echo "OK [12]"

echo "PASS w111-liaison-sync-gate"
