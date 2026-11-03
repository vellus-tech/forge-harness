#!/usr/bin/env bash
# Gate único do change extend-kb-corpus-sources — cada TASK acrescenta seus casos aqui, nunca cria
# gate próprio (ver tasks.md). Grupos de cenário numerados continuamente, padrão `shell-gate`
# reconhecido por red-classify.mjs (`^FAIL \[[^\]\n]+\]`).
#
#   [1] (TASK-01) active-spec participa do mecanismo de staleness/fingerprint de ponta a ponta,
#       via comportamento observável de kb.sh (build/status/query) — nunca a função interna
#       sourceFiles(), que não é exportada (REQ-06).
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KB="$WS/template/.forge/scripts/kb.sh"
T="$(mktemp -d /tmp/forge-extend-kb.XXXXXX)"
trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL [$1] $2"; exit 1; }
ok() { echo "OK [$1]"; }

# [1]
R="$T/root"
mkdir -p "$R/.forge/specs/active/some-change"
printf '# Requirements\n\nTexto inicial da spec ativa.\n' > "$R/.forge/specs/active/some-change/requirements.md"

OUT1="$(FORGE_ROOT="$R" bash "$KB" build 2>&1)" || fail 1 "kb.sh build inicial falhou: $OUT1"

STATUS1="$(FORGE_ROOT="$R" bash "$KB" status --json 2>&1)" || fail 1 "kb.sh status --json inicial falhou: $STATUS1"
node -e 'const s=JSON.parse(process.argv[1]); if (s.index!=="atual") process.exit(1);' "$STATUS1" \
  || fail 1 "índice deveria estar atual logo após o build: $STATUS1"

printf '# Requirements\n\nTexto NOVO da spec ativa, editado entre dois builds.\n' > "$R/.forge/specs/active/some-change/requirements.md"

STATUS2="$(FORGE_ROOT="$R" bash "$KB" status --json 2>&1)" || fail 1 "kb.sh status --json após edição falhou: $STATUS2"
node -e 'const s=JSON.parse(process.argv[1]); if (s.index!=="defasado") process.exit(1);' "$STATUS2" \
  || fail 1 "status deveria reportar defasado após editar conteúdo active-spec sem rebuild: $STATUS2"

OUT2="$(FORGE_ROOT="$R" bash "$KB" build 2>&1)" || fail 1 "kb.sh build posterior à edição falhou: $OUT2"

QUERY="$(FORGE_ROOT="$R" bash "$KB" query "editado entre dois builds" --json 2>&1)" || fail 1 "kb.sh query falhou: $QUERY"
node -e '
const q = JSON.parse(process.argv[1]);
const hit = q.results.some((r) => r.doc === ".forge/specs/active/some-change/requirements.md");
if (!hit) process.exit(1);
' "$QUERY" || fail 1 "kb.sh query não reflete o texto novo da spec ativa após rebuild: $QUERY"

ok 1

echo "PASS extend-kb-corpus-sources (1 caso)"
