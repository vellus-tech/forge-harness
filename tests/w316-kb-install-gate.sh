#!/usr/bin/env bash
# Gate W291 — busca unificada (/forge:kb), instalador da camada semântica (change
# add-unified-knowledge-search, REQ-05; design §2.7). Instalador de produção, pins de fixture
# servidos em 127.0.0.1, `npm` substituto no PATH.
#
#   [1] sem npm no PATH: exit != 0, mensagem clara, sem installed.json
#   [2] URL fora de https (salvo loopback) nos pins: recusada antes de qualquer download
#   [3] sha256 divergente no download: aborta, apaga o .part, sem installed.json
#   [4] binário nativo plantado pelo npm ci: instalação desfeita
#   [5] pacote do lockfile ausente após o npm ci: instalação desfeita
#   [6] instalação íntegra: installed.json por último com pins_sha256; reinstalação não rebaixa arquivo íntegro
#   [7] ninguém além de `semantic install` carrega o instalador: nenhum arquivo do template (fora o
#       próprio kb-cli.mjs no ramo `semantic install`) referencia kb-install.mjs
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w316.XXXXXX)"
# shellcheck source=fixtures/kb/semantic-env.sh
. "$WS/tests/fixtures/kb/semantic-env.sh"
trap 'semantic_env_teardown; rm -rf "$T"' EXIT
ok() { echo "OK [$1]"; }
fail() { echo "FAIL [$1] $2"; exit 1; }
semantic_env_setup
INST="$R/.forge/kb/semantic/installed.json"

# [1]
mkdir -p "$T/nonpm"; for b in node bash env dirname cat; do p="$(command -v "$b")"; ln -sf "$p" "$T/nonpm/$b"; done
set +e; out="$(PATH="$T/nonpm" FORGE_ROOT="$R" "$T/nonpm/bash" "$KBSH" semantic install 2>&1)"; rc=$?; set -e
[ "$rc" -ne 0 ] || fail 1 "install sem npm saiu 0"
grep -q 'npm não encontrado' <<<"$out" || fail 1 "mensagem sem npm: $out"
[ -e "$INST" ] && fail 1 "installed.json criado sem npm"
ok 1

# [2]
P="$R/.forge/scripts/lib/kb-pins/models.json"
node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));m.embedder.files[0].url="http://example.com/model.onnx";fs.writeFileSync(process.argv[1],JSON.stringify(m))' "$P"
: > "$SRV/.requests"
set +e; out="$(kb semantic install 2>&1)"; rc=$?; set -e
[ "$rc" -ne 0 ] && grep -q 'URL recusada' <<<"$out" || fail 2 "URL http externa não recusada: $out"
[ -s "$SRV/.requests" ] && fail 2 "houve download antes da recusa"
[ -e "$INST" ] && fail 2 "installed.json criado"
kb_fixture_pins
ok 2

# [3]
node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));m.reranker.files[0].sha256="0".repeat(64);fs.writeFileSync(process.argv[1],JSON.stringify(m))' "$P"
set +e; out="$(kb semantic install 2>&1)"; rc=$?; set -e
[ "$rc" -ne 0 ] && grep -q 'integridade divergente' <<<"$out" || fail 3 "sha divergente não abortou: $out"
[ -e "$INST" ] && fail 3 "installed.json criado com sha divergente"
ls "$R/.forge/kb/semantic/models/reranker/"*.part >/dev/null 2>&1 && fail 3 ".part sobrou"
[ -e "$R/.forge/kb/semantic/models/reranker/model.onnx" ] && fail 3 "arquivo divergente renomeado para o destino"
kb_fixture_pins
ok 3

# [4]
cat > "$T/bin/npm" <<EOF
#!/usr/bin/env bash
bash "$WS/tests/fixtures/kb/fake-npm.sh" "\$@"; rc=\$?
[ "\${1:-}" = ci ] && printf 'x' > node_modules/plantado.node
exit \$rc
EOF
chmod +x "$T/bin/npm"
set +e; out="$(kb semantic install 2>&1)"; rc=$?; set -e
[ "$rc" -ne 0 ] && grep -q 'binário nativo' <<<"$out" || fail 4 "binário nativo não desfez a instalação: $out"
[ -e "$R/.forge/kb/semantic" ] && fail 4 "instalação não foi desfeita"
cp "$WS/tests/fixtures/kb/fake-npm.sh" "$T/bin/npm"; chmod +x "$T/bin/npm"
ok 4

# [5]
cat > "$T/bin/npm" <<EOF
#!/usr/bin/env bash
bash "$WS/tests/fixtures/kb/fake-npm.sh" "\$@"; rc=\$?
[ "\${1:-}" = ci ] && rm -rf node_modules/long
exit \$rc
EOF
chmod +x "$T/bin/npm"
set +e; out="$(kb semantic install 2>&1)"; rc=$?; set -e
[ "$rc" -ne 0 ] && grep -q 'long' <<<"$out" || fail 5 "pacote ausente não desfez a instalação: $out"
[ -e "$INST" ] && fail 5 "installed.json criado com pacote ausente"
cp "$WS/tests/fixtures/kb/fake-npm.sh" "$T/bin/npm"; chmod +x "$T/bin/npm"
ok 5

# [6]
: > "$SRV/.requests"
kb semantic install > "$T/i1" 2>&1 || fail 6 "instalação íntegra falhou: $(cat "$T/i1")"
node -e 'const o=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));if(!/^[0-9a-f]{64}$/.test(o.pins_sha256)||!o.packages["onnxruntime-web"])process.exit(1)' "$INST" || fail 6 "installed.json incompleto"
n1="$(wc -l < "$SRV/.requests" | tr -d ' ')"
: > "$SRV/.requests"
kb semantic install > "$T/i2" 2>&1 || fail 6 "reinstalação falhou"
n2="$(wc -l < "$SRV/.requests" | tr -d ' ')"
[ "$n1" = "6" ] && [ "$n2" = "0" ] || fail 6 "downloads: primeira $n1 (esperado 6), segunda $n2 (esperado 0)"
ok 6

# [7]
refs="$(grep -rlE "(import\(|from ['\"]|require\().*kb-install" "$WS/template" "$WS/installer" "$WS/bin" 2>/dev/null | grep -v 'kb-install.mjs$' || true)"
[ "$refs" = "$WS/template/.forge/scripts/lib/kb-cli.mjs" ] || fail 7 "kb-install referenciado fora do kb-cli: $refs"
n="$(grep -cE "(import\(|from ['\"]).*kb-install" "$WS/template/.forge/scripts/lib/kb-cli.mjs")"
[ "$n" = "1" ] || fail 7 "kb-cli referencia kb-install.mjs $n vezes (esperado 1, no ramo semantic install)"
ctx="$(grep -B3 'kb-install.mjs' "$WS/template/.forge/scripts/lib/kb-cli.mjs")"; grep -q "sub === 'install'" <<<"$ctx" || fail 7 "kb-install carregado fora do ramo semantic install"
ok 7

echo "PASS w316-kb-install (7 casos)"
