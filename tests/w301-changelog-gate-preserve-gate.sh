#!/usr/bin/env bash
# Gate W301 — gates/preserve.mjs (TASK-06): nenhum bloco antigo removido em relacao ao arquivo
# anterior.
#
# Cenarios:
#   [1] bloco "### Added" com conteudo removido sem substituto -> FAIL
#   [2] conjunto vazio comparado a arquivo vazio anterior -> passa
#   [3] arquivo novo ganhando conteudo -> passa
#   [4] arquivo anterior em CRLF com bloco removido -> FAIL
#   [5] arquivo anterior inexistente -> rc 2
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$WS/template/.forge/skills/readme-generator/scripts/gates/preserve.mjs"

T="$(mktemp -d /tmp/forge-w301.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] bloco Added com conteudo removido sem substituto -> FAIL"
cat > "$T/old1.md" <<'EOF'
# Changelog

## [Unreleased]

### Added

- entrada a manter
- entrada que vai sumir
EOF
cat > "$T/new1.md" <<'EOF'
# Changelog

## [Unreleased]

### Added

- entrada a manter
EOF
out="$(node "$GATE" "$T/old1.md" "$T/new1.md" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [1]: gate aprovou remocao de bloco sem substituto"; exit 1; }
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] conjunto vazio comparado a arquivo vazio anterior -> passa"
: > "$T/old2.md"
: > "$T/new2.md"
out="$(node "$GATE" "$T/old2.md" "$T/new2.md" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [2]: rc=$rc saida: $out"; exit 1; }
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] arquivo novo ganhando conteudo -> passa"
: > "$T/old3.md"
cat > "$T/new3.md" <<'EOF'
# Changelog

## [Unreleased]

### Added

- entrada nova
EOF
out="$(node "$GATE" "$T/old3.md" "$T/new3.md" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [3]: rc=$rc saida: $out"; exit 1; }
echo "OK [3]"

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] arquivo anterior em CRLF com bloco removido -> FAIL (CRLF não esconde a remoção)"
printf '# Changelog\r\n\r\n## [Unreleased]\r\n\r\n### Added\r\n\r\n- entrada antiga A\r\n- entrada antiga B\r\n' > "$T/old4.md"
printf '# Changelog\n\n## [Unreleased]\n\n### Added\n\n- nova\n' > "$T/new4.md"
out="$(node "$GATE" "$T/old4.md" "$T/new4.md" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL [4]: rc esperado 1, obtido $rc (saída: $out)"; exit 1; }
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] arquivo anterior inexistente -> rc 2"
out="$(node "$GATE" "$T/nao-existe.md" "$T/new4.md" 2>&1)"; rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL [5]: rc esperado 2, obtido $rc (saída: $out)"; exit 1; }
echo "OK [5]"

echo "PASS w301-changelog-gate-preserve"
