#!/usr/bin/env bash
# Gate W290 — gates/lint.mjs (TASK-07): travessao, quebra de linha dentro de paragrafo,
# acentuacao ASCII, placeholder, link quebrado.
#
# Cenarios:
#   [1] entrada com travessao -> FAIL
#   [2] entrada com "nao" em vez de "não" -> FAIL
#   [3] entrada limpa -> passa
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$WS/template/.forge/skills/readme-generator/scripts/gates/lint.mjs"

T="$(mktemp -d /tmp/forge-w290.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] entrada com travessao -> FAIL"
cat > "$T/trav.md" <<'EOF'
# Changelog

## [Unreleased]

### Adicionado

- entrada com travessão — não deveria ter travessão
EOF
out="$(node "$GATE" "$T/trav.md" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [1]: gate aprovou entrada com travessao (saida: $out)"; exit 1; }
case "$out" in
  *travess*) : ;;
  *) echo "FAIL [1]: saida nao menciona travessao (saida: $out)"; exit 1 ;;
esac
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] entrada com 'nao' em vez de 'não' -> FAIL"
cat > "$T/ascii.md" <<'EOF'
# Changelog

## [Unreleased]

### Adicionado

- isso nao deveria usar ascii
EOF
out="$(node "$GATE" "$T/ascii.md" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [2]: gate aprovou acentuacao ascii (saida: $out)"; exit 1; }
case "$out" in
  *acentua*) : ;;
  *) echo "FAIL [2]: saida nao menciona acentuacao (saida: $out)"; exit 1 ;;
esac
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] entrada limpa -> passa"
cat > "$T/limpo.md" <<'EOF'
# Changelog

## [Unreleased]

### Adicionado

- entrada limpa, sem problema de formatação
EOF
out="$(node "$GATE" "$T/limpo.md" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [3]: rc=$rc saida: $out"; exit 1; }
echo "OK [3]"

echo "PASS w290-changelog-gate-lint"
