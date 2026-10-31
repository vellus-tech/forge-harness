#!/usr/bin/env bash
# Gate W288 — gates/released.mjs (TASK-05): cada secao "## [X.Y.Z]" do arquivo anterior
# identica byte a byte no novo.
#
# Cenarios:
#   [1] versao publicada identica -> passa
#   [2] 1 byte alterado numa versao publicada -> FAIL
#   [3] versao publicada removida -> FAIL
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$WS/template/.forge/skills/readme-generator/scripts/gates/released.mjs"

T="$(mktemp -d /tmp/forge-w288.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cat > "$T/old.md" <<'EOF'
# Changelog

## [Unreleased]

## [1.0.0] - 2026-01-01

### Adicionado

- entrada original
EOF

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] versao publicada identica -> passa"
cp "$T/old.md" "$T/new1.md"
out="$(node "$GATE" "$T/old.md" "$T/new1.md" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [1]: rc=$rc saida: $out"; exit 1; }
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] 1 byte alterado numa versao publicada -> FAIL"
sed 's/entrada original/entrada alterada/' "$T/old.md" > "$T/new2.md"
out="$(node "$GATE" "$T/old.md" "$T/new2.md" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [2]: gate aprovou versao publicada alterada"; exit 1; }
case "$out" in
  *"1.0.0"*) : ;;
  *) echo "FAIL [2]: saida nao nomeia a secao divergente (saida: $out)"; exit 1 ;;
esac
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] versao publicada removida -> FAIL"
printf '# Changelog\n\n## [Unreleased]\n' > "$T/new3.md"
out="$(node "$GATE" "$T/old.md" "$T/new3.md" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [3]: gate aprovou versao publicada removida"; exit 1; }
echo "OK [3]"

echo "PASS w288-changelog-gate-released"
