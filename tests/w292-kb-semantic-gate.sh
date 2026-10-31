#!/usr/bin/env bash
# Gate W292 — busca unificada (/forge:kb), camada semântica com INFERÊNCIA REAL (change
# add-unified-knowledge-search, REQ-05, REQ-06, REQ-07, REQ-08; design §2.6, §2.10).
#
# A camada é instalada pelo `kb.sh semantic install` de produção, a partir de uma cópia da maquinaria
# em que só os pins de modelos apontam para modelos ONNX de fixture servidos em 127.0.0.1; o runtime
# (onnxruntime-web, WASM) vem das devDependencies do workspace pelo `npm` substituto. Embeddings e
# re-rank rodam de verdade no runtime — o que muda em relação à produção são os pesos.
#
#   [1]  instalação real: 6 arquivos baixados do servidor local, npm ci --ignore-scripts, installed.json
#   [2]  build calcula um vetor por trecho; segundo build não recalcula nada
#   [3]  embeddings reais: consulta sem palavra em comum com o documento acha o documento do mesmo
#        tópico pelo canal vetorial (sem BM25), e o de tópico oposto fica abaixo
#   [4]  re-rank real: ce_score numérico nos K primeiros, fórmula no --json; --no-rerank mantém o vetor
#   [5]  cache incremental: documento alterado recalcula só o trecho novo e remove o antigo; build
#        interrompido depois de 200 vetores preserva o que calculou
#   [6]  oito casos degradados caem para lexical com exit 0 e motivo nomeado
#   [7]  módulos envenenados nunca são importados: no node_modules do projeto (4 situações) e por
#        symlink de pacote do runtime para fora do confinamento, com a versão certa
#   [8]  `kb.sh eval` avalia os modos semantic e semantic+rerank; `semantic status` confere integridade; `semantic remove` volta ao lexical e reinstala depois
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w292.XXXXXX)"
# shellcheck source=fixtures/kb/semantic-env.sh
. "$WS/tests/fixtures/kb/semantic-env.sh"
trap 'semantic_env_teardown; rm -rf "$T"' EXIT
ok() { echo "OK [$1]"; }
fail() { echo "FAIL [$1] $2"; exit 1; }
jget() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const o=JSON.parse(s);console.log(eval(process.argv[1]))})' "$1"; }

semantic_env_setup
mkdir -p "$R/docs/plans"
printf '# Grafo\n\ngrafo codigo python\n' > "$R/docs/plans/grafo.md"
printf '# Segredos\n\nsegredo chave credencial\n' > "$R/docs/plans/segredo.md"
printf '# Outro\n\nassunto neutro qualquer\n' > "$R/docs/plans/outro.md"

# [1]
kb semantic install > "$T/inst.out" 2>&1 || fail 1 "install falhou: $(cat "$T/inst.out")"
[ -f "$R/.forge/kb/semantic/installed.json" ] || fail 1 "installed.json ausente"
n="$(sort -u "$SRV/.requests" | wc -l | tr -d ' ')"; [ "$n" = "6" ] || fail 1 "esperados 6 downloads, houve $n"
grep -q 'npm ci --ignore-scripts' "$T/npm.log" || fail 1 "npm ci sem --ignore-scripts: $(cat "$T/npm.log")"
grep -q '127.0.0.1' "$T/inst.out" || fail 1 "install não anunciou o que baixaria"
ok 1

# [2]
kb build > "$T/b1" 2>/dev/null
N="$(sed -n 's/.*OK vetores: \([0-9]*\) calculados, 0 reaproveitados.*/\1/p' "$T/b1")"
[ -n "$N" ] && [ "$N" -ge 3 ] || fail 2 "primeiro build: $(cat "$T/b1")"
kb build > "$T/b2" 2>/dev/null; grep -q "OK vetores: 0 calculados, $N reaproveitados, 0 removidos" "$T/b2" || fail 2 "segundo build recalculou: $(cat "$T/b2")"
ok 2

# [3]
kb query "vazamento token" --json > "$T/q.json"
[ "$(jget 'o.mode' < "$T/q.json")" = "semantic" ] || fail 3 "modo não semântico: $(cat "$T/q.json")"
node -e '
const o=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const s=o.results.findIndex(r=>r.doc==="docs/plans/segredo.md"), g=o.results.findIndex(r=>r.doc==="docs/plans/grafo.md");
if (s!==0) { console.log(JSON.stringify(o.results.map(r=>r.doc))); process.exit(1); }
const r=o.results[0]; if (!r.channels.vector || "bm25" in r.channels) { console.log(JSON.stringify(r.channels)); process.exit(1); }
if (g>=0 && g<s) process.exit(1);
' "$T/q.json" || fail 3 "canal vetorial não achou o documento do mesmo tópico"
ok 3

# [4]
node -e '
const o=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
if (!o.rerank.applied || !/rank_cross_encoder/.test(o.rerank.formula)) process.exit(1);
if (!o.results.slice(0,3).every(r=>r.rerank && typeof r.rerank.ce_score==="number" && r.rerank.ce_rank>=1 && r.rerank.fusion_rank>=1)) { console.log(JSON.stringify(o.results)); process.exit(1); }
' "$T/q.json" || fail 4 "re-rank sem score real do cross-encoder"
kb query "vazamento token" --json --no-rerank > "$T/q2.json"
node -e 'const o=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));if(o.mode!=="semantic"||o.rerank.applied||!o.results[0].channels.vector)process.exit(1)' "$T/q2.json" || fail 4 "--no-rerank desligou mais que o re-rank"
grep -q 're-rank ce #' <<<"$(kb query "vazamento token")" || fail 4 "saída texto sem o re-rank"
ok 4

# [5]
printf '# Grafo\n\ngrafo codigo python nativo\n' > "$R/docs/plans/grafo.md"
kb build > "$T/b3" 2>/dev/null; grep -q "OK vetores: 1 calculados, $((N - 1)) reaproveitados, 1 removidos" "$T/b3" || fail 5 "incremental: $(cat "$T/b3")"
for i in $(seq 1 450); do printf '# d%s\n\nsegredo numero %s\n' "$i" "$i" > "$R/docs/plans/d$i.md"; done
kb build > "$T/b4" 2> "$T/b4.err" &
bpid=$!
i=0; until grep -q 'embeddings: 200/' "$T/b4.err" 2>/dev/null; do i=$((i + 1)); [ "$i" -gt 600 ] && fail 5 "progresso 200 não apareceu"; sleep 0.1; done
kill "$bpid" 2>/dev/null || true; wait "$bpid" 2>/dev/null || true
kept="$(node -e 'const b=require("fs").readFileSync(process.argv[1]);console.log(b.toString("latin1",0,4)==="FKBV"?b.readUInt32LE(12):0)' "$R/.forge/kb/vectors.bin")"
[ "$kept" -ge 200 ] || fail 5 "build interrompido não preservou vetores (preservados: $kept)"
kb build > "$T/b5" 2>/dev/null
calc="$(sed -n 's/.*OK vetores: \([0-9]*\) calculados.*/\1/p' "$T/b5")"
[ -n "$calc" ] && [ "$calc" -le $((N + 450 - 200)) ] || fail 5 "build seguinte recalculou demais ($calc): $(cat "$T/b5")"
rm -f "$R"/docs/plans/d*.md; kb build >/dev/null 2>&1
ok 5

# [6] oito casos degradados — cada um sobre uma cópia íntegra da camada
cp -R "$R/.forge/kb/semantic" "$T/sem.bak"
restore() { rm -rf "$R/.forge/kb/semantic"; cp -R "$T/sem.bak" "$R/.forge/kb/semantic"; cp "$SRV/models.json" "$R/.forge/scripts/lib/kb-pins/models.json"; }
degraded() { # <rótulo> <regex do motivo>
  local out rc; set +e; out="$(kb query "grafo" 2>/dev/null)"; rc=$?; set -e
  [ "$rc" = "0" ] || fail 6 "$1: exit $rc"
  grep -qE "^modo: lexical \(.*$2" <<<"${out%%$'\n'*}" || fail 6 "$1: primeira linha '${out%%$'\n'*}'"
  set +e; kb build > "$T/db" 2>&1; rc=$?; set -e
  [ "$rc" = "0" ] && grep -q 'vetores não calculados' "$T/db" || fail 6 "$1: build não degradou: $(cat "$T/db")"
}
rm -f "$R/.forge/kb/semantic/installed.json"; degraded ausente 'não instalada'; restore
rm -f "$R/.forge/kb/semantic/models/reranker/tokenizer.json"; degraded modelo-faltando 'arquivo de modelo faltando'; restore
node -e 'const fs=require("fs");const p=process.argv[1];const b=fs.readFileSync(p);b[b.length-5]^=0xff;fs.writeFileSync(p,b)' "$R/.forge/kb/semantic/models/embedder/model.onnx"; degraded sha 'sha256 divergente'; restore
rm -rf "$R/.forge/kb/semantic/runtime/node_modules/long"; degraded pacote-faltando 'pacote do runtime faltando: long'; restore
printf 'x' > "$R/.forge/kb/semantic/runtime/node_modules/addon.node"; degraded nativo-ext 'binário nativo'; restore
printf '\177ELF\002\001\001' > "$R/.forge/kb/semantic/runtime/node_modules/semext"; degraded nativo-elf 'binário nativo'; restore
node -e 'const fs=require("fs");const p=process.argv[1];const m=JSON.parse(fs.readFileSync(p,"utf8"));m.note+=" (alterado)";fs.writeFileSync(p,JSON.stringify(m))' "$R/.forge/scripts/lib/kb-pins/models.json"; degraded pins 'pins mudaram'; restore
entry="$(node -e 'console.log(require("module").createRequire(process.argv[1]+"/package.json").resolve("onnxruntime-web"))' "$R/.forge/kb/semantic/runtime")"
case "$entry" in "$(cd "$R" && pwd -P)/.forge/kb/semantic/runtime/node_modules/"*) : ;; *) fail 6 "entrada do runtime resolvida fora do confinamento: $entry" ;; esac
printf 'throw new Error("boom-import");\n' > "$entry"; degraded importa-lanca 'falha ao carregar: .*boom-import'; restore
kb_fixture_pins --broken-embedder; kb semantic install > /dev/null 2>&1 || fail 6 "reinstalação com embedder quebrado falhou"
degraded inferencia-lanca 'falha ao carregar'
kb_fixture_pins; kb semantic install > /dev/null 2>&1 || fail 6 "reinstalação íntegra falhou"; kb build > /dev/null 2>&1
cp -R "$R/.forge/kb/semantic" "$T/sem.bak2"; rm -rf "$T/sem.bak"; mv "$T/sem.bak2" "$T/sem.bak"
ok 6

# [7] módulos envenenados no node_modules do projeto
for p in onnxruntime-web @huggingface/tokenizers long; do
  mkdir -p "$R/node_modules/$p"
  ver="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).version)' "$R/.forge/kb/semantic/runtime/node_modules/$p/package.json")"
  printf '{"name":"%s","version":"%s","main":"index.js","exports":{".":"./index.js"}}\n' "$p" "$ver" > "$R/node_modules/$p/package.json"
  printf 'require("fs").writeFileSync(%s, "importado");\nthrow new Error("envenenado");\n' "\"$T/MARKER\"" > "$R/node_modules/$p/index.js"
done
check_poison() { # <rótulo> <modo esperado> <regex do motivo|->
  local o; o="$(kb query "vazamento token" --json 2>/dev/null)"
  [ -e "$T/MARKER" ] && fail 7 "$1: módulo envenenado foi importado"
  printf '%s' "$o" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const o=JSON.parse(s);if(o.mode!==process.argv[1])process.exit(1);if(process.argv[2]!=="-"&&!new RegExp(process.argv[2]).test(o.mode_reason||""))process.exit(1)})' "$2" "$3" || fail 7 "$1: modo/motivo inesperado: $o"
}
mv "$R/.forge/kb/semantic/installed.json" "$T/inst.json"; check_poison nao-instalada lexical 'não instalada'; mv "$T/inst.json" "$R/.forge/kb/semantic/installed.json"
check_poison completa semantic -
rm -rf "$R/.forge/kb/semantic/runtime/node_modules/onnxruntime-web"; check_poison sem-topo lexical 'pacote do runtime faltando'; restore
rm -rf "$R/.forge/kb/semantic/runtime/node_modules/long"; check_poison sem-transitiva lexical 'pacote do runtime faltando'; restore
# pacote de topo trocado por symlink para FORA do confinamento, com a versão certa e conteúdo
# envenenado: a conferência de versões passa (o package.json é lido pelo symlink), e só a conferência
# do caminho real resolvido impede a importação
mkdir -p "$T/fora"; cp -R "$R/node_modules/onnxruntime-web" "$T/fora/onnxruntime-web"
rm -rf "$R/.forge/kb/semantic/runtime/node_modules/onnxruntime-web"; ln -s "$T/fora/onnxruntime-web" "$R/.forge/kb/semantic/runtime/node_modules/onnxruntime-web"
check_poison symlink-fora lexical 'resolvido fora de runtime/node_modules'; restore
rm -rf "$R/node_modules"
ok 7

# [8]
printf '[{"q":"vazamento token","gold":["segredo.md"]}]\n' > "$T/qs.json"
kb eval "$T/qs.json" --json > "$T/ev.json" 2>/dev/null || fail 8 "eval semântico falhou"
node -e 'const o=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const m=o.modes;if(!m.semantic||!m["semantic+rerank"]||m.semantic.hit1!==1||m["semantic+rerank"].hit1!==1||m.bm25.hit1!==0)process.exit(1)' "$T/ev.json" || fail 8 "eval semântico incompleto: $(cat "$T/ev.json")"
grep -q 'integridade confere' <<<"$(kb semantic status)" || fail 8 "status não confere integridade"
grep -q 'removida' <<<"$(kb semantic remove)" || fail 8 "remove sem confirmação"
[ -e "$R/.forge/kb/semantic" ] && fail 8 "remove não apagou .forge/kb/semantic"
[ -f "$R/.forge/scripts/lib/kb-pins/models.json" ] || fail 8 "remove apagou os pins"
o="$(kb query "grafo")"; grep -q 'não instalada' <<<"${o%%$'\n'*}" || fail 8 "após remove a busca não voltou ao lexical"
kb semantic install > /dev/null 2>&1 && [ -f "$R/.forge/kb/semantic/installed.json" ] || fail 8 "reinstalação após remove falhou"
ok 8

echo "PASS w292-kb-semantic (8 casos)"
