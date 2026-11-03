#!/usr/bin/env bash
# Gate W284 — busca unificada (/forge:kb), corpus: fontes, exclusões e corte em trechos
# (change add-unified-knowledge-search, REQ-01; design §2.3).
#
#   [1] as oito fontes entram, uma por documento: baseline, spec arquivada, spec ativa, plano,
#       CHANGELOG, uma entrada de ledger por documento (id ledger:<LDG>), uma mensagem `self` por
#       documento (spec ativa rotulada kind: active-spec — reverte REQ-FHT-072/SCN-FHT-072-A,
#       change extend-kb-corpus-sources, REQ-01), e um extra-path (kb.extra_paths declarado em
#       .forge/forge.yaml + allowlist com motivo — change extend-kb-corpus-sources, REQ-02/REQ-06)
#   [2] blobs do liaison nunca entram, nem quando referenciados por body_ref de mensagem `self`
#   [3] mensagem com trust diferente de `self` (untrusted-peer, ausente, desconhecido), com
#       authored_by, ou de log/<outro>.jsonl nunca entra
#   [4] código-fonte, node_modules, .git e .forge/kb nunca entram
#   [5] linha JSONL ilegível e ledger.json ilegível não abortam: a fonte é pulada e contada
#   [6] raiz sem nenhuma fonte: lista vazia, sem erro
#   [7] duas raízes: ledger e liaison vêm de stateRoot, documentos versionados de docRoot
#   [8] corte em trechos: heading 1-3 abre trecho com heading e linha; teto de 1.500 caracteres
#   [9] impressão digital muda se e só se alguma fonte muda
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w309.XXXXXX)"
trap 'rm -rf "$T"' EXIT
LIB="$WS/template/.forge/scripts/lib"
ok() { echo "OK [$1]"; }
fail() { echo "FAIL [$1] $2"; exit 1; }

R="$T/root"
mkdir -p "$R/.forge/product/current/adr" "$R/.forge/specs/archived/2026-01-01-add-x" "$R/.forge/specs/active/wip" \
  "$R/docs/plans" "$R/.forge/ledger" "$R/.forge/liaison/canal/log" "$R/.forge/liaison/canal/blobs" "$R/src" \
  "$R/node_modules/pkg" "$R/.forge/kb" "$R/.git"
printf '# ADR 0001\n\nDecisão do grafo nativo.\n' > "$R/.forge/product/current/adr/0001-graph.md"
printf 'capability: x\n' > "$R/.forge/product/current/spec.yaml"
printf '# Proposal\n\nTexto da spec arquivada.\n' > "$R/.forge/specs/archived/2026-01-01-add-x/proposal.md"
printf '# WIP\n\nspec ativa não indexada\n' > "$R/.forge/specs/active/wip/proposal.md"
printf '# Plano\n\nplano mestre\n' > "$R/docs/plans/00-master.md"
mkdir -p "$R/docs/adr"
printf '# ADR extra\n\nDecisao extra indexada via kb.extra_paths.\n' > "$R/docs/adr/0100-extra.md"
printf 'kb:\n  extra_paths:\n    - docs/adr/**\n' > "$R/.forge/forge.yaml"
printf 'docs/adr/**  # motivo: indexar ADRs extras do sub-repositorio (fixture w309)\n' > "$R/.forge/kb-extra-paths-allowlist.txt"
printf '# Changelog\n\n## 1.0\n' > "$R/CHANGELOG.md"
printf 'const segredoDoCodigo = 1;\n' > "$R/src/app.md"
printf '# pacote\n' > "$R/node_modules/pkg/README.md"
printf '# derivado\n' > "$R/.forge/kb/x.md"
printf '{"entries":[{"id":"LDG-0001","title":"Primeira entrada","type":"tech-debt","status":"open","detail":"detalhe A"},{"id":"LDG-0002","title":"Segunda","detail":"cita LDG-0001"}]}\n' > "$R/.forge/ledger/ledger.json"
printf 'self:\n  id: eu\n' > "$R/.forge/liaison/liaison.yaml"
printf 'CONTEUDO_DO_BLOB_PEER\n' > "$R/.forge/liaison/canal/blobs/abc-corpo.md"
{
  echo '{"msg_id":"eu-0001","sender":"eu","trust":"self","subject":"assunto proprio","body":"corpo proprio inline"}'
  echo '{"msg_id":"eu-0002","sender":"eu","trust":"self","subject":"so assunto","body_ref":"blobs/abc-corpo.md"}'
  echo '{"msg_id":"eu-0003","sender":"eu","trust":"untrusted-peer","subject":"INJECAO_UNTRUSTED"}'
  echo '{"msg_id":"eu-0004","sender":"eu","subject":"INJECAO_SEM_TRUST"}'
  echo '{"msg_id":"eu-0005","sender":"eu","trust":"weird","subject":"INJECAO_TRUST_DESCONHECIDO"}'
  echo '{"msg_id":"eu-0006","sender":"eu","trust":"self","authored_by":"peer","subject":"INJECAO_AUTHORED_BY"}'
  echo '{"msg_id":"eu-0007","sender":"peer","trust":"self","subject":"INJECAO_SENDER_SPOOFADO"}'
  echo '{"msg_id":"eu-0008","sender":"eu","trust":"self","authored_by":"","subject":"INJECAO_AUTHORED_BY_VAZIO"}'
  echo 'isto nao e json'
} > "$R/.forge/liaison/canal/log/eu.jsonl"
echo '{"msg_id":"peer-0001","sender":"peer","trust":"self","subject":"INJECAO_LOG_DO_PEER"}' > "$R/.forge/liaison/canal/log/peer.jsonl"

run() { node --input-type=module -e "
import { collect, chunk, fingerprint } from '$LIB/kb-corpus.mjs';
const r = collect({ docRoot: process.argv[1], stateRoot: process.argv[2] || process.argv[1] });
console.log(JSON.stringify(r));
" "$@"; }
OUT="$(run "$R")" || fail 1 "kb-corpus.mjs ausente ou falhou"
ids="$(node -e 'const r=JSON.parse(process.argv[1]);console.log(r.docs.map(d=>d.kind+" "+d.id).join("\n"))' "$OUT")"

# [1]
for want in "baseline .forge/product/current/adr/0001-graph.md" "baseline .forge/product/current/spec.yaml" \
  "archived-spec .forge/specs/archived/2026-01-01-add-x/proposal.md" "active-spec .forge/specs/active/wip/proposal.md" \
  "plan docs/plans/00-master.md" "changelog CHANGELOG.md" \
  "ledger ledger:LDG-0001" "ledger ledger:LDG-0002" "liaison liaison:eu-0001" "liaison liaison:eu-0002" \
  "extra-path docs/adr/0100-extra.md"; do
  grep -qxF "$want" <<<"$ids" || fail 1 "documento esperado ausente: $want"
done
n="$(printf '%s\n' "$ids" | wc -l | tr -d ' ')"
[ "$n" = "11" ] || fail 1 "esperados 11 documentos, obtidos $n: $ids"
node -e 'const r=JSON.parse(process.argv[1]);const d=r.docs.find(x=>x.id==="ledger:LDG-0001");if(!/Primeira entrada/.test(d.text)||!/detalhe A/.test(d.text))process.exit(1)' "$OUT" || fail 1 "texto da entrada de ledger sem título/detalhe"
ok 1

# [2]
grep -q 'CONTEUDO_DO_BLOB_PEER' <<<"$OUT" && fail 2 "conteúdo de blob entrou no corpus"
ok 2

# [3]
for bad in INJECAO_UNTRUSTED INJECAO_SEM_TRUST INJECAO_TRUST_DESCONHECIDO INJECAO_AUTHORED_BY INJECAO_LOG_DO_PEER INJECAO_SENDER_SPOOFADO INJECAO_AUTHORED_BY_VAZIO; do
  grep -q "$bad" <<<"$OUT" && fail 3 "mensagem não confiável entrou no corpus: $bad"
done
ok 3

# [4]
grep -qE 'segredoDoCodigo|"# pacote|derivado' <<<"$OUT" && fail 4 "fonte proibida entrou no corpus"
grep -qE 'src/|node_modules|\.forge/kb|\.git/' <<<"$ids" && fail 4 "path proibido no corpus: $ids"
ok 4

# [5]
node -e 'const r=JSON.parse(process.argv[1]);if(r.skipped.liaison!==1)process.exit(1)' "$OUT" || fail 5 "linha JSONL ilegível não contada em skipped.liaison: $OUT"
R2="$T/root2"; mkdir -p "$R2/.forge/ledger"; printf '{ruim' > "$R2/.forge/ledger/ledger.json"; printf '# x\n' > "$R2/CHANGELOG.md"
OUT2="$(run "$R2")" || fail 5 "collect falhou com ledger ilegível"
node -e 'const r=JSON.parse(process.argv[1]);if(r.skipped.ledger!==1||r.docs.length!==1)process.exit(1)' "$OUT2" || fail 5 "ledger ilegível não pulado/contado: $OUT2"
ok 5

# [6]
R3="$T/vazia"; mkdir -p "$R3"
OUT3="$(run "$R3")" || fail 6 "collect falhou na raiz vazia"
node -e 'const r=JSON.parse(process.argv[1]);if(r.docs.length!==0)process.exit(1)' "$OUT3" || fail 6 "raiz vazia deveria dar zero documentos: $OUT3"
ok 6

# [7]
D="$T/doc"; S="$T/state"; mkdir -p "$D/.forge/ledger" "$S/.forge/ledger"
printf '# changelog da branch\n' > "$D/CHANGELOG.md"
printf '{"entries":[{"id":"LDG-0009","title":"ledger da branch"}]}\n' > "$D/.forge/ledger/ledger.json"
printf '{"entries":[{"id":"LDG-0042","title":"ledger do tronco"}]}\n' > "$S/.forge/ledger/ledger.json"
printf '# changelog do tronco\n' > "$S/CHANGELOG.md"
OUT4="$(run "$D" "$S")" || fail 7 "collect falhou com duas raízes"
grep -q 'LDG-0042' <<<"$OUT4" || fail 7 "ledger não veio de stateRoot"
grep -q 'ledger da branch' <<<"$OUT4" && fail 7 "ledger veio de docRoot"
grep -q 'changelog da branch' <<<"$OUT4" || fail 7 "CHANGELOG não veio de docRoot"
grep -q 'changelog do tronco' <<<"$OUT4" && fail 7 "CHANGELOG veio de stateRoot"
ok 7

# [8]
node --input-type=module -e "
import { chunk, CHUNK_MAX } from '$LIB/kb-corpus.mjs';
const big = 'x'.repeat(3200);
const doc = { id: 'docs/plans/a.md', kind: 'plan', text: 'intro\n# Um\ntexto um\n## Dois\n' + big + '\n#### quatro não abre\nfim' };
const cs = chunk(doc);
const h = cs.map((c) => c.heading);
if (CHUNK_MAX !== 1500) { console.log('teto', CHUNK_MAX); process.exit(1); }
if (!cs.every((c) => c.text.length <= 1500)) { console.log('trecho acima do teto'); process.exit(1); }
if (h[0] !== '' || h[1] !== 'Um' || !h.slice(2).every((x) => x === 'Dois')) { console.log('headings', h); process.exit(1); }
if (cs[1].line !== 2 || cs[2].line !== 4) { console.log('linhas', cs.map((c) => c.line)); process.exit(1); }
if (!cs.some((c) => c.text.includes('quatro não abre'))) { console.log('h4 perdido'); process.exit(1); }
const y = chunk({ id: 'a.yaml', kind: 'baseline', text: '# nao e heading em yaml\nk: v\n' });
if (y.length !== 1) { console.log('yaml cortado por #'); process.exit(1); }
" || fail 8 "corte em trechos incorreto"
ok 8

# [9]
node --input-type=module -e "
import { collect, fingerprint } from '$LIB/kb-corpus.mjs';
const a = fingerprint(collect({ docRoot: process.argv[1] }).docs);
const b = fingerprint(collect({ docRoot: process.argv[1] }).docs);
if (a !== b || !/^[0-9a-f]{64}$/.test(a)) process.exit(1);
console.log(a);
" "$R" > "$T/fp1" || fail 9 "impressão digital instável"
printf '# Plano\n\nplano mestre alterado\n' > "$R/docs/plans/00-master.md"
node --input-type=module -e "
import { collect, fingerprint } from '$LIB/kb-corpus.mjs';
console.log(fingerprint(collect({ docRoot: process.argv[1] }).docs));
" "$R" > "$T/fp2"
cmp -s "$T/fp1" "$T/fp2" && fail 9 "impressão digital não mudou com a fonte alterada"
ok 9

echo "PASS w309-kb-corpus (9 casos)"
