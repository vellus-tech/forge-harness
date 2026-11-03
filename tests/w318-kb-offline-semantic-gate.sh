#!/usr/bin/env bash
# Gate W293 — busca unificada (/forge:kb): nenhum dado sai da máquina com a camada semântica ativa
# nem nos casos degradados (change add-unified-knowledge-search, REQ-08, REQ-09; design §2.8).
#
#   [1] dinâmico, semântico (fixture): build, query (mode semantic conferido), eval, semantic status
#       sob bloqueio de rede (permissões do Node quando há --allow-net; interceptador --require, que
#       alcança os Workers do runtime WASM, em qualquer Node)
#   [2] dinâmico, degradado: os oito casos do REQ-08 sob o mesmo bloqueio, todos exit 0 em lexical
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w318.XXXXXX)"
# shellcheck source=fixtures/kb/semantic-env.sh
. "$WS/tests/fixtures/kb/semantic-env.sh"
trap 'semantic_env_teardown; rm -rf "$T"' EXIT
LIB="$WS/template/.forge/scripts/lib"
firstline() { local o; o="$("$@")" || return $?; printf '%s\n' "${o%%$'\n'*}"; }
ok() { echo "OK [$1]"; }
fail() { echo "FAIL [$1] $2"; exit 1; }

semantic_env_setup
mkdir -p "$R/docs/plans" "$R/.forge/ledger"
printf '# Grafo\n\ngrafo codigo python\n' > "$R/docs/plans/grafo.md"
printf '# Segredos\n\nsegredo chave credencial\n' > "$R/docs/plans/segredo.md"
printf '[{"q":"grafo python","gold":["grafo.md"]}]\n' > "$T/q.json"

# bloqueio: modos disponíveis neste Node
MECHS="interceptador"
nh="$(node --help 2>/dev/null || true)"; grep -q -- '--allow-net' <<<"$nh" && MECHS="permissoes $MECHS"
echo "INFO mecanismos de bloqueio de rede neste Node ($(node --version)): $MECHS"
blocked() { # <mecanismo> <args do kb...>
  local mech="$1"; shift
  : > "$T/net.log"
  case "$mech" in
    permissoes) NODE_OPTIONS="--permission --allow-fs-read=* --allow-fs-write=$T --allow-worker" kb "$@" ;;
    interceptador) NO_NETWORK_LOG="$T/net.log" NODE_OPTIONS="--require=$WS/tests/fixtures/kb/no-network.cjs" kb "$@" ;;
  esac
}
assert_clean() { [ -s "$T/net.log" ] && fail "$1" "tentativa de rede/processo registrada: $(sort -u "$T/net.log" | tr '\n' ' ')"; return 0; }

# [1]
kb semantic install > /dev/null 2>&1 || fail 1 "instalação da fixture falhou"
for mech in $MECHS; do
  blocked "$mech" build > "$T/o" 2> "$T/e" || fail 1 "[$mech] build semântico falhou: $(tail -3 "$T/e")"; assert_clean 1
  grep -q 'OK vetores' "$T/o" || fail 1 "[$mech] build não calculou vetores sob bloqueio: $(cat "$T/o")"
  mode="$(blocked "$mech" query "vazamento token" --json 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).mode+"|"+JSON.parse(s).rerank.applied))')"; assert_clean 1
  [ "$mode" = "semantic|true" ] || fail 1 "[$mech] query sob bloqueio caiu para '$mode' (o bloqueio derrubou a camada semântica)"
  blocked "$mech" eval "$T/q.json" > "$T/o" 2>/dev/null || fail 1 "[$mech] eval falhou"; assert_clean 1
  grep -q 'semantic+rerank' "$T/o" || fail 1 "[$mech] eval não avaliou o modo semântico: $(cat "$T/o")"
  blocked "$mech" semantic status > "$T/o" 2>/dev/null || fail 1 "[$mech] semantic status falhou"; assert_clean 1
done
ok 1

# [2]
cp -R "$R/.forge/kb/semantic" "$T/sem.bak"
restore() { rm -rf "$R/.forge/kb/semantic"; cp -R "$T/sem.bak" "$R/.forge/kb/semantic"; cp "$SRV/models.json" "$R/.forge/scripts/lib/kb-pins/models.json"; }
deg() { # <rótulo>
  local mech
  for mech in $MECHS; do
    local first; first="$(firstline blocked "$mech" query grafo 2>/dev/null)" || fail 2 "[$mech] $1: exit != 0"
    assert_clean 2
    grep -q '^modo: lexical (' <<<"$first" || fail 2 "[$mech] $1: $first"
  done
}
rm -f "$R/.forge/kb/semantic/installed.json"; deg ausente; restore
rm -f "$R/.forge/kb/semantic/models/embedder/tokenizer.json"; deg modelo-faltando; restore
node -e 'const fs=require("fs");const p=process.argv[1];const b=fs.readFileSync(p);b[b.length-5]^=0xff;fs.writeFileSync(p,b)' "$R/.forge/kb/semantic/models/reranker/model.onnx"; deg sha; restore
rm -rf "$R/.forge/kb/semantic/runtime/node_modules/long"; deg pacote; restore
printf 'x' > "$R/.forge/kb/semantic/runtime/x.node"; deg nativo; restore
node -e 'const fs=require("fs");const p=process.argv[1];const m=JSON.parse(fs.readFileSync(p,"utf8"));m.note+="!";fs.writeFileSync(p,JSON.stringify(m))' "$R/.forge/scripts/lib/kb-pins/models.json"; deg pins; restore
entry="$(node -e 'console.log(require("module").createRequire(process.argv[1]+"/package.json").resolve("onnxruntime-web"))' "$R/.forge/kb/semantic/runtime")"
printf 'throw new Error("boom-import");\n' > "$entry"; deg importa-lanca; restore
kb_fixture_pins --broken-embedder; kb semantic install > /dev/null 2>&1 || fail 2 "reinstalação quebrada falhou"; deg inferencia-lanca
ok 2

echo "PASS w318-kb-offline-semantic (2 casos; bloqueio: $MECHS)"
