#!/usr/bin/env bash
# Gate W110 — núcleo local do subsistema liaison (Onda 1, SEM transporte):
#   [1] seq sem buracos por remetente
#   [2] lamport monotônico DENTRO da thread, através de remetentes diferentes
#   [3] mensagens de threads distintas não interferem no lamport uma da outra
#   [4] participante que só está numa thread converge nela sem precisar da outra
#   [5] três participantes convergem para a mesma ordem em cada thread, sob PERMUTAÇÃO da
#       ordem de import (propriedade central — embaralha e confirma saída byte-idêntica)
#   [6] corpo grande vira blob com sha conferível
#   [6b] conteúdo ACENTUADO: prefixo do nome do blob bate com o sha256 real dos bytes (#117)
#   [6c] propriedade: buffers aleatórios de 0 a 4KB (incl. bytes acima de 0x7F) — prefixo sempre
#        igual ao sha256 real (#117)
#   [6d] retrocompatibilidade: body_ref com nome ANTIGO (calculado do jeito errado) continua
#        importando sem erro — nenhum leitor recalcula o nome para conferir (#117)
#   [7] body_ref com path traversal recusado no import
#   [8] mensagem órfã de thread fica retida (quarentena) e é liberada quando o thread-open chega
#   [9] requires_ack recusado em kind=answer (CLI) e kind=ack (import de mensagem forjada)
#   [10] spoofing de sender (arquivo log/<X>.jsonl com mensagem sender != X) recusado
#   [11] duplicata (content_sha igual) é no-op; content_sha divergente vira conflito
#   [12] render preserva o bloco NARRATIVE entre regenerações
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo
# obedecerem ao repositório de quem invocou o gate, e não ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
T="$(mktemp -d /tmp/forge-w110.XXXXXX)"
trap 'rm -rf "$T"' EXIT

CH=contract-drift

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

# Constrói uma mensagem válida (content_sha via a implementação REAL — nunca reimplementada à
# mão no teste) a partir de um JSON parcial (sem content_sha/trust). Uso: _craft '<json>' > arq
_craft() {
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

dump_order() { # dump_order <channel-dir> -> JSON {thread_id: [msg_id...]} determinístico
  node - "$LIB" "$1" <<'NODEEOF'
const { readFileSync, readdirSync, existsSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir] = process.argv;
  const { mergeLogs } = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
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

mk_repo a; mk_repo b; mk_repo c
LG a open "$CH" --self axis-go-cloud --participants axis-go-cloud,axis-fare-validator,ops-bot >/dev/null
LG b open "$CH" --self axis-fare-validator --participants axis-go-cloud,axis-fare-validator,ops-bot >/dev/null
LG c open "$CH" --self ops-bot --participants axis-go-cloud,axis-fare-validator,ops-bot >/dev/null

echo "[1] seq sem buracos por remetente"
LG a thread open "$CH" fare-proto-v2 --subject "Mudança no proto de tarifa" --participants axis-go-cloud,axis-fare-validator --body "abertura" >/dev/null
LG a send "$CH" --thread fare-proto-v2 --kind contract-change --subject "novo campo" --body "fare_cents int64" --contract-files fare.proto >/dev/null
LG a send "$CH" --thread fare-proto-v2 --kind note --subject "nota" --body "explicação" >/dev/null
seqs="$(node -e "const fs=require('fs');console.log(fs.readFileSync('$T/a/.forge/liaison/$CH/log/axis-go-cloud.jsonl','utf8').trim().split('\n').map(l=>JSON.parse(l).seq).join(','))")"
[ "$seqs" = "1,2,3" ] || { echo "FAIL [1]: seq de axis-go-cloud não é 1,2,3 contíguo: $seqs"; exit 1; }
echo "OK [1]"

echo "[2] lamport monotônico dentro da thread, através de remetentes"
LG a export "$CH" --out "$T/bundle-a1" >/dev/null
LG b import "$CH" --from "$T/bundle-a1" >/dev/null
LG b thread join "$CH" fare-proto-v2 --subject "axis-fare-validator entrou" >/dev/null
LG b send "$CH" --thread fare-proto-v2 --kind question --subject "fare_cents é signed?" --body "confirma tipo" --requires-ack >/dev/null
LG b export "$CH" --out "$T/bundle-b1" >/dev/null
LG a import "$CH" --from "$T/bundle-b1" >/dev/null
LG a send "$CH" --thread fare-proto-v2 --kind answer --subject "sim, é unsigned" --body "uint64" >/dev/null
lamports="$(dump_order "$T/a/.forge/liaison/$CH" | node -e "
const { readFileSync, readdirSync } = require('fs');
const order = JSON.parse(readFileSync(0,'utf8'))['fare-proto-v2'];
const files = readdirSync('$T/a/.forge/liaison/$CH/log');
const all = {};
for (const f of files) for (const line of readFileSync('$T/a/.forge/liaison/$CH/log/'+f,'utf8').trim().split('\n')) { if(!line) continue; const m=JSON.parse(line); all[m.msg_id]=m.lamport; }
console.log(order.map(id=>all[id]).join(','));
")"
[ "$lamports" = "1,2,3,4,5,6" ] || { echo "FAIL [2]: lamports fora de sequência monotônica: $lamports"; exit 1; }
echo "OK [2]"

echo "[3] threads distintas não interferem no lamport uma da outra"
LG a thread open "$CH" internal-note --subject "nota interna" --participants axis-go-cloud,ops-bot --body "assunto interno" >/dev/null
t2_first_lamport="$(dump_order "$T/a/.forge/liaison/$CH" | node -e "
const { readFileSync } = require('fs');
const orders = JSON.parse(readFileSync(0,'utf8'));
const order = orders['internal-note'];
const files = require('fs').readdirSync('$T/a/.forge/liaison/$CH/log');
const all = {};
for (const f of files) for (const line of readFileSync('$T/a/.forge/liaison/$CH/log/'+f,'utf8').trim().split('\n')) { if(!line) continue; const m=JSON.parse(line); all[m.msg_id]=m.lamport; }
console.log(all[order[0]]);
")"
[ "$t2_first_lamport" = "1" ] || { echo "FAIL [3]: thread nova não começou em lamport 1 (contaminada pela outra thread, lamport=$t2_first_lamport)"; exit 1; }
echo "OK [3]"

echo "[4] participante que só está numa thread converge nela sem conhecer a outra"
# bundle FILTRADO: só a mensagem de internal-note (não a full-export de a, que teria fare-proto-v2 junto)
mkdir -p "$T/bundle-a-t2-only/log"
node -e "
const fs=require('fs');
const lines=fs.readFileSync('$T/a/.forge/liaison/$CH/log/axis-go-cloud.jsonl','utf8').trim().split('\n').map(l=>JSON.parse(l));
const only=lines.filter(m=>m.thread_id==='internal-note');
fs.writeFileSync('$T/bundle-a-t2-only/log/axis-go-cloud.jsonl', only.map(m=>JSON.stringify(m)).join('\n')+'\n');
"
LG c import "$CH" --from "$T/bundle-a-t2-only" >/dev/null
LG c thread join "$CH" internal-note --subject "ops-bot entrou" >/dev/null
LG c send "$CH" --thread internal-note --kind note --subject "confirmado" --body "ok" >/dev/null
# c NUNCA recebeu nada de fare-proto-v2 (nem quarentena — a thread simplesmente não existe no seu log)
c_threads="$(LG c thread list "$CH")"
grep -q "internal-note" <<<"$c_threads" || { echo "FAIL [4]: internal-note não convergiu em c"; exit 1; }
grep -q "fare-proto-v2" <<<"$c_threads" && { echo "FAIL [4]: c enxergou fare-proto-v2 sem tê-la recebido"; exit 1; }
echo "OK [4]"

echo "[5] três participantes convergem para a mesma ordem, sob permutação da ordem de import"
LG a export "$CH" --out "$T/bundle-a2" >/dev/null
LG b export "$CH" --out "$T/bundle-b2" >/dev/null
LG c export "$CH" --out "$T/bundle-c2" >/dev/null
mk_repo d; mk_repo e
LG d open "$CH" --self observer --participants axis-go-cloud,axis-fare-validator,ops-bot,observer >/dev/null
LG e open "$CH" --self observer --participants axis-go-cloud,axis-fare-validator,ops-bot,observer >/dev/null
LG d import "$CH" --from "$T/bundle-a2" >/dev/null
LG d import "$CH" --from "$T/bundle-b2" >/dev/null
LG d import "$CH" --from "$T/bundle-c2" >/dev/null
LG e import "$CH" --from "$T/bundle-c2" >/dev/null
LG e import "$CH" --from "$T/bundle-b2" >/dev/null
LG e import "$CH" --from "$T/bundle-a2" >/dev/null
order_d="$(dump_order "$T/d/.forge/liaison/$CH")"
order_e="$(dump_order "$T/e/.forge/liaison/$CH")"
[ "$order_d" = "$order_e" ] || { echo "FAIL [5]: ordem divergiu sob permutação de import"; diff <(echo "$order_d") <(echo "$order_e"); exit 1; }
grep -q "fare-proto-v2" <<<"$order_d" || { echo "FAIL [5]: fare-proto-v2 ausente na convergência"; exit 1; }
grep -q "internal-note" <<<"$order_d" || { echo "FAIL [5]: internal-note ausente na convergência"; exit 1; }
echo "OK [5]"

echo "[6] corpo grande vira blob com sha conferível"
head -c 4000 /dev/urandom | base64 > "$T/big.txt"
sha_expected="$(shasum -a 256 "$T/big.txt" | cut -d' ' -f1)"
LG a send "$CH" --thread fare-proto-v2 --kind note --subject "anexo grande" --body-file "$T/big.txt" >/dev/null
blob_ref="$(node -e "const fs=require('fs');const lines=fs.readFileSync('$T/a/.forge/liaison/$CH/log/axis-go-cloud.jsonl','utf8').trim().split('\n').map(l=>JSON.parse(l));const m=lines.find(x=>x.subject==='anexo grande');console.log(m.body_ref)")"
[ -n "$blob_ref" ] || { echo "FAIL [6]: mensagem sem body_ref"; exit 1; }
blob_file="$T/a/.forge/liaison/$CH/${blob_ref}"
[ -f "$blob_file" ] || { echo "FAIL [6]: blob não existe em $blob_file"; exit 1; }
sha_actual="$(shasum -a 256 "$blob_file" | cut -d' ' -f1)"
[ "$sha_actual" = "$sha_expected" ] || { echo "FAIL [6]: sha do blob não confere"; exit 1; }
grep -q "^blobs/$sha_expected" <<<"$blob_ref" || { echo "FAIL [6]: nome do blob não referencia o sha"; exit 1; }
echo "OK [6]"

echo "[6b] conteúdo acentuado: prefixo do blob bate com sha256 real dos bytes (#117)"
printf 'não, ação — acentuação em latin1 indevida quebra o hash do #117' > "$T/accented.txt"
sha_expected_6b="$(shasum -a 256 "$T/accented.txt" | cut -d' ' -f1)"
LG a send "$CH" --thread fare-proto-v2 --kind note --subject "anexo acentuado" --body-file "$T/accented.txt" >/dev/null
blob_ref_6b="$(node -e "const fs=require('fs');const lines=fs.readFileSync('$T/a/.forge/liaison/$CH/log/axis-go-cloud.jsonl','utf8').trim().split('\n').map(l=>JSON.parse(l));const m=lines.find(x=>x.subject==='anexo acentuado');console.log(m.body_ref)")"
[ -n "$blob_ref_6b" ] || { echo "FAIL [6b]: mensagem sem body_ref"; exit 1; }
grep -q "^blobs/$sha_expected_6b-" <<<"$blob_ref_6b" || { echo "FAIL [6b]: nome do blob não bate com sha256 real (obtido $blob_ref_6b, esperado prefixo blobs/$sha_expected_6b-)"; exit 1; }
blob_file_6b="$T/a/.forge/liaison/$CH/${blob_ref_6b}"
[ -f "$blob_file_6b" ] || { echo "FAIL [6b]: blob não existe em $blob_file_6b"; exit 1; }
sha_actual_6b="$(shasum -a 256 "$blob_file_6b" | cut -d' ' -f1)"
[ "$sha_actual_6b" = "$sha_expected_6b" ] || { echo "FAIL [6b]: sha do blob acentuado não confere"; exit 1; }
echo "OK [6b]"

echo "[6c] propriedade: buffers aleatórios de 0 a 4KB — prefixo do blob = sha256 real dos bytes"
for i in 1 2 3 4 5 6 7 8; do
  sz=$(( RANDOM % 4096 ))
  if [ "$sz" -eq 0 ]; then : > "$T/pbt_$i.bin"; else head -c "$sz" /dev/urandom > "$T/pbt_$i.bin"; fi
  sha_exp_c="$(shasum -a 256 "$T/pbt_$i.bin" | cut -d' ' -f1)"
  LG a send "$CH" --thread fare-proto-v2 --kind note --subject "pbt-$i" --body-file "$T/pbt_$i.bin" >/dev/null
  ref_c="$(node -e "const fs=require('fs');const lines=fs.readFileSync('$T/a/.forge/liaison/$CH/log/axis-go-cloud.jsonl','utf8').trim().split('\n').map(l=>JSON.parse(l));const m=lines.filter(x=>x.subject==='pbt-$i').pop();console.log(m.body_ref)")"
  grep -q "^blobs/$sha_exp_c-" <<<"$ref_c" || { echo "FAIL [6c]: iteração $i (tamanho $sz bytes) — prefixo não bate (obtido $ref_c, esperado blobs/$sha_exp_c-)"; exit 1; }
done
echo "OK [6c]"

echo "[6d] retrocompatibilidade: body_ref com nome ANTIGO continua importando sem erro"
printf 'não, ação — conteúdo legado com nome calculado do jeito errado' > "$T/legacy.txt"
# Nome calculado do jeito ANTIGO (o bug em si): sha256 do texto UTF-8 da string latin1 dos bytes,
# em vez do sha256 direto sobre o buffer. Simula um blob publicado ANTES da correção do #117.
old_name_hash="$(node -e "
const fs=require('fs');
const {createHash}=require('crypto');
const buf=fs.readFileSync('$T/legacy.txt');
console.log(createHash('sha256').update(buf.toString('binary'),'utf8').digest('hex'));
")"
LG b export "$CH" --out "$T/legacy_bundle" >/dev/null
node - "$LIB" "$T/legacy_bundle/log" "$T/legacy.txt" "$old_name_hash" "$T/legacy_bundle" <<'NODEEOF'
const { readFileSync, readdirSync, writeFileSync, appendFileSync, copyFileSync, mkdirSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, logDir, legacyFile, oldHash, bundleDir] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const files = readdirSync(logDir).filter((f) => f.endsWith('.jsonl'));
  const all = [];
  for (const f of files) for (const line of readFileSync(join(logDir, f), 'utf8').trim().split('\n')) { if (line) all.push(JSON.parse(line)); }
  const own = all.filter((m) => m.sender === 'axis-fare-validator');
  const threadMsgs = all.filter((m) => m.thread_id === 'fare-proto-v2');
  const seq = M.nextSeq(own);
  const lamport = M.nextLamport(threadMsgs);
  const blobName = `${oldHash}-legacy.txt`;
  const msg = {
    msg_id: `axis-fare-validator-${String(seq).padStart(4, '0')}`, channel: 'contract-drift',
    thread_id: 'fare-proto-v2', sender: 'axis-fare-validator', seq, lamport, kind: 'note',
    in_reply_to: null, requires_ack: false, subject: 'anexo legado (nome antigo)',
    body_ref: `blobs/${blobName}`,
    refs: { change_id: null, contract_files: [], commit: null },
    created_at: '2026-01-01T00:00:00Z',
    trust: 'self',
  };
  msg.content_sha = M.computeContentSha(msg);
  mkdirSync(join(bundleDir, 'blobs'), { recursive: true });
  copyFileSync(legacyFile, join(bundleDir, 'blobs', blobName));
  appendFileSync(join(logDir, 'axis-fare-validator.jsonl'), JSON.stringify(msg) + '\n');
})();
NODEEOF
out6d="$(LG a import "$CH" --from "$T/legacy_bundle")"
echo "$out6d" | grep -q "FAIL" && { echo "FAIL [6d]: import de body_ref com nome antigo foi recusado: $out6d"; exit 1; }
legacy_ref_local="$T/a/.forge/liaison/$CH/blobs/${old_name_hash}-legacy.txt"
[ -f "$legacy_ref_local" ] || { echo "FAIL [6d]: blob de nome antigo não foi copiado para o destino"; exit 1; }
grep -q "anexo legado" "$T/a/.forge/liaison/$CH/log/axis-fare-validator.jsonl" || { echo "FAIL [6d]: mensagem com body_ref antigo não entrou no log local"; exit 1; }
echo "OK [6d]"

echo "[7] body_ref com path traversal recusado no import"
mkdir -p "$T/bundle-traversal/log"
msg="$(_craft "{\"msg_id\":\"axis-fare-validator-0090\",\"channel\":\"$CH\",\"thread_id\":\"fare-proto-v2\",\"sender\":\"axis-fare-validator\",\"seq\":90,\"lamport\":90,\"kind\":\"note\",\"in_reply_to\":null,\"requires_ack\":false,\"subject\":\"traversal\",\"body_ref\":\"blobs/../../etc/passwd\",\"refs\":{\"change_id\":null,\"contract_files\":[],\"commit\":null},\"created_at\":\"2026-01-01T00:00:00Z\"}")"
printf '%s\n' "$msg" > "$T/bundle-traversal/log/axis-fare-validator.jsonl"
out7="$(LG a import "$CH" --from "$T/bundle-traversal")"
grep -q "1 conflito" <<<"$out7" || { echo "FAIL [7]: path traversal não foi para conflito: $out7"; exit 1; }
[ -f "$T/a/.forge/liaison/$CH/conflicts/axis-fare-validator-0090.json" ] || { echo "FAIL [7]: conflito não registrado"; exit 1; }
echo "OK [7]"

echo "[8] mensagem órfã de thread fica retida e é liberada quando o thread-open chega"
mkdir -p "$T/bundle-orphan/log"
orphan="$(_craft "{\"msg_id\":\"ops-bot-0050\",\"channel\":\"$CH\",\"thread_id\":\"orphan-thread\",\"sender\":\"ops-bot\",\"seq\":50,\"lamport\":1,\"kind\":\"note\",\"in_reply_to\":null,\"requires_ack\":false,\"subject\":\"chegou antes\",\"body\":\"orfã\",\"refs\":{\"change_id\":null,\"contract_files\":[],\"commit\":null},\"created_at\":\"2026-01-01T00:00:00Z\"}")"
printf '%s\n' "$orphan" > "$T/bundle-orphan/log/ops-bot.jsonl"
out8a="$(LG a import "$CH" --from "$T/bundle-orphan")"
grep -q "1 em quarentena" <<<"$out8a" || { echo "FAIL [8a]: mensagem órfã não ficou em quarentena: $out8a"; exit 1; }
mkdir -p "$T/bundle-orphan-open/log"
opener="$(_craft "{\"msg_id\":\"ops-bot-0051\",\"channel\":\"$CH\",\"thread_id\":\"orphan-thread\",\"sender\":\"ops-bot\",\"seq\":51,\"lamport\":1,\"kind\":\"thread-open\",\"in_reply_to\":null,\"requires_ack\":false,\"subject\":\"abertura tardia\",\"participants\":[\"ops-bot\",\"axis-go-cloud\"],\"refs\":{\"change_id\":null,\"contract_files\":[],\"commit\":null},\"created_at\":\"2026-01-01T00:00:00Z\"}")"
printf '%s\n' "$opener" > "$T/bundle-orphan-open/log/ops-bot.jsonl"
out8b="$(LG a import "$CH" --from "$T/bundle-orphan-open")"
grep -q "0 em quarentena" <<<"$out8b" || { echo "FAIL [8b]: quarentena não foi liberada com o thread-open: $out8b"; exit 1; }
tl_out="$(LG a thread list "$CH" 2>&1)"; tl_rc=$?
[ "$tl_rc" -eq 0 ] || { echo "FAIL [8b]: thread list reprovou (rc $tl_rc): $tl_out"; exit 1; }
grep -q "orphan-thread" <<<"$tl_out" || { echo "FAIL [8b]: orphan-thread não apareceu resolvida ($tl_out)"; exit 1; }
echo "OK [8]"

echo "[9] requires_ack recusado em kind=answer (CLI) e kind=ack (import forjado)"
if LG a send "$CH" --thread fare-proto-v2 --kind answer --subject "x" --body "y" --requires-ack 2>/tmp/w110-err9.txt; then
  echo "FAIL [9a]: send --kind answer --requires-ack deveria falhar"; exit 1
fi
grep -q "requires_ack proibido" /tmp/w110-err9.txt || { echo "FAIL [9a]: mensagem de erro inesperada"; cat /tmp/w110-err9.txt; exit 1; }
mkdir -p "$T/bundle-ack-forged/log"
forged_ack="$(_craft "{\"msg_id\":\"axis-fare-validator-0091\",\"channel\":\"$CH\",\"thread_id\":\"fare-proto-v2\",\"sender\":\"axis-fare-validator\",\"seq\":91,\"lamport\":91,\"kind\":\"ack\",\"in_reply_to\":\"axis-go-cloud-0001\",\"requires_ack\":true,\"subject\":\"ack forjado\",\"refs\":{\"change_id\":null,\"contract_files\":[],\"commit\":null},\"created_at\":\"2026-01-01T00:00:00Z\"}")"
printf '%s\n' "$forged_ack" > "$T/bundle-ack-forged/log/axis-fare-validator.jsonl"
out9b="$(LG a import "$CH" --from "$T/bundle-ack-forged")"
grep -q "1 conflito" <<<"$out9b" || { echo "FAIL [9b]: ack com requires_ack=true não foi recusado: $out9b"; exit 1; }
echo "OK [9]"

echo "[10] spoofing de sender recusado"
mkdir -p "$T/bundle-spoof/log"
spoof="$(_craft "{\"msg_id\":\"axis-go-cloud-0099\",\"channel\":\"$CH\",\"thread_id\":\"fare-proto-v2\",\"sender\":\"axis-go-cloud\",\"seq\":99,\"lamport\":99,\"kind\":\"note\",\"in_reply_to\":null,\"requires_ack\":false,\"subject\":\"forjado\",\"body\":\"finjo ser axis-go-cloud\",\"refs\":{\"change_id\":null,\"contract_files\":[],\"commit\":null},\"created_at\":\"2026-01-01T00:00:00Z\"}")"
printf '%s\n' "$spoof" > "$T/bundle-spoof/log/axis-fare-validator.jsonl"   # arquivo de b, sender diz ser a
out10="$(LG a import "$CH" --from "$T/bundle-spoof")"
grep -q "1 conflito" <<<"$out10" || { echo "FAIL [10]: spoofing não foi recusado: $out10"; exit 1; }
echo "OK [10]"

echo "[11] duplicata (content_sha igual) é no-op; content_sha divergente vira conflito"
out11a="$(LG c import "$CH" --from "$T/bundle-a-t2-only")"
grep -q "1 duplicata" <<<"$out11a" || { echo "FAIL [11a]: reimport idêntico não foi no-op: $out11a"; exit 1; }
mkdir -p "$T/bundle-tamper/log"
node -e "
const fs=require('fs');
const lines=fs.readFileSync('$T/c/.forge/liaison/$CH/log/ops-bot.jsonl','utf8').trim().split('\n').map(l=>JSON.parse(l));
const m={...lines[0], subject:'ADULTERADO'};
fs.writeFileSync('$T/bundle-tamper/log/ops-bot.jsonl', JSON.stringify(m)+'\n');
"
out11b="$(LG a import "$CH" --from "$T/bundle-tamper")"
grep -q "1 conflito" <<<"$out11b" || { echo "FAIL [11b]: content_sha divergente não virou conflito: $out11b"; exit 1; }
# fork genuíno: mesmo msg_id, AMBAS as versões internamente válidas (content_sha recalculado
# confere com o declarado em cada uma), mas divergentes entre si. O log de um remetente é
# append-only: reescrever uma posição já conhecida é DIVERGÊNCIA, não conflito de mensagem — o
# import REPROVA (rc != 0), nomeia o remetente, registra a POSIÇÃO em conflicts/ e mantém a versão
# conhecida. O registro é por posição (`<sender>.seq-<n>.divergence.json`), nunca um agregado por
# remetente: agregar esconderia quantas e quais posições estão retidas (issue #48).
LG a import "$CH" --from "$T/bundle-c2" >/dev/null   # estabelece ops-bot-0001 localmente em a
before_fork_sha="$(node -e "const fs=require('fs');const m=fs.readFileSync('$T/a/.forge/liaison/$CH/log/ops-bot.jsonl','utf8').trim().split('\n').map(l=>JSON.parse(l)).find(x=>x.msg_id==='ops-bot-0001');console.log(m.content_sha)")"
mkdir -p "$T/bundle-fork/log"
forked="$(_craft "{\"msg_id\":\"ops-bot-0001\",\"channel\":\"$CH\",\"thread_id\":\"internal-note\",\"sender\":\"ops-bot\",\"seq\":1,\"lamport\":2,\"kind\":\"join\",\"in_reply_to\":null,\"requires_ack\":false,\"subject\":\"versão divergente do join\",\"refs\":{\"change_id\":null,\"contract_files\":[],\"commit\":null},\"created_at\":\"2026-01-01T00:00:00Z\"}")"
printf '%s\n' "$forked" > "$T/bundle-fork/log/ops-bot.jsonl"
if LG a import "$CH" --from "$T/bundle-fork" >"$T/out11c.txt" 2>&1; then
  echo "FAIL [11c]: reescrita de história (mesmo seq, ambos válidos) deveria REPROVAR"; cat "$T/out11c.txt"; exit 1
fi
grep -q "divergência" "$T/out11c.txt" || { echo "FAIL [11c]: saída não reporta divergência"; cat "$T/out11c.txt"; exit 1; }
grep -q "ops-bot" "$T/out11c.txt" || { echo "FAIL [11c]: saída não nomeia o remetente divergente"; cat "$T/out11c.txt"; exit 1; }
[ -f "$T/a/.forge/liaison/$CH/conflicts/ops-bot.seq-1.divergence.json" ] || { echo "FAIL [11c]: posição divergente não registrada em conflicts/"; ls "$T/a/.forge/liaison/$CH/conflicts/"; exit 1; }
[ ! -f "$T/a/.forge/liaison/$CH/conflicts/ops-bot.divergence.json" ] || { echo "FAIL [11c]: registro agregado por remetente — não dá para agir sobre a posição"; exit 1; }
after_fork_sha="$(node -e "const fs=require('fs');const m=fs.readFileSync('$T/a/.forge/liaison/$CH/log/ops-bot.jsonl','utf8').trim().split('\n').map(l=>JSON.parse(l)).find(x=>x.msg_id==='ops-bot-0001');console.log(m.content_sha)")"
[ "$before_fork_sha" = "$after_fork_sha" ] || { echo "FAIL [11c]: log local foi tocado por uma reescrita de história"; exit 1; }
echo "OK [11]"

echo "[12] render preserva o bloco NARRATIVE entre regenerações"
CHFILE="$T/a/.forge/liaison/$CH/CHANNEL.md"
node -e "
const fs=require('fs');
let c=fs.readFileSync('$CHFILE','utf8');
c=c.replace(/<!-- FORGE:NARRATIVE:START -->[\s\S]*<!-- FORGE:NARRATIVE:END -->/, '<!-- FORGE:NARRATIVE:START -->\nprioridade: fechar fare-proto-v2 antes do release\n<!-- FORGE:NARRATIVE:END -->');
fs.writeFileSync('$CHFILE', c);
"
LG a send "$CH" --thread fare-proto-v2 --kind note --subject "trigger render" --body "x" >/dev/null
grep -q "prioridade: fechar fare-proto-v2 antes do release" "$CHFILE" || { echo "FAIL [12]: bloco NARRATIVE não foi preservado"; exit 1; }
echo "OK [12]"

echo "PASS w110-liaison-core-gate"
