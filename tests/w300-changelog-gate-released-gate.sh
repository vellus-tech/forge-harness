#!/usr/bin/env bash
# Gate W300 — gates/released.mjs (TASK-05): cada secao "## [X.Y.Z]" do arquivo anterior
# identica byte a byte no novo.
#
# Cenarios:
#   [1] versao publicada identica -> passa
#   [2] 1 byte alterado numa versao publicada -> FAIL
#   [3] versao publicada removida -> FAIL
#   [4] arquivo anterior inexistente -> rc 2
#   [5] versão duplicada no arquivo novo -> FAIL
#   [6] versões fora do formato "## [X.Y.Z]" -> rc 2
#   [7] diferença só de terminador de linha (CRLF x LF) -> passa
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$WS/template/.forge/skills/readme-generator/scripts/gates/released.mjs"

T="$(mktemp -d /tmp/forge-w300.XXXXXX)"
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

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] arquivo anterior inexistente -> rc 2 (nunca '0 seções verificadas' como sucesso)"
out="$(node "$GATE" "$T/nao-existe.md" "$T/old.md" 2>&1)"; rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL [4]: rc esperado 2, obtido $rc (saída: $out)"; exit 1; }
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] versão duplicada no arquivo novo (cópia adulterada antes da original) -> FAIL"
printf '# C\n\n## [2.0.0]\n- original\n' > "$T/dup-old.md"
printf '# C\n\n## [2.0.0]\n- adulterada\n\n## [2.0.0]\n- original\n' > "$T/dup-new.md"
out="$(node "$GATE" "$T/dup-old.md" "$T/dup-new.md" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL [5]: rc esperado 1, obtido $rc (saída: $out)"; exit 1; }
echo "OK [5]"

# ── [6] ──────────────────────────────────────────────────────────────────────────────────────
echo "[6] versões fora do formato '## [X.Y.Z]' -> rc 2 (nada conferido não é aprovação)"
printf '# C\n\n## 1.0.0 - 2026-01-01\n- a\n' > "$T/fmt-old.md"
printf '# C\n\n## 1.0.0 - 2026-01-01\n- adulterada\n' > "$T/fmt-new.md"
out="$(node "$GATE" "$T/fmt-old.md" "$T/fmt-new.md" 2>&1)"; rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL [6]: rc esperado 2, obtido $rc (saída: $out)"; exit 1; }
echo "OK [6]"

# ── [7] ──────────────────────────────────────────────────────────────────────────────────────
echo "[7] mesma seção publicada em CRLF (anterior) e LF (novo) -> passa"
printf '# C\r\n\r\n## [1.0.0]\r\n- a\r\n' > "$T/crlf-old.md"
printf '# C\n\n## [1.0.0]\n- a\n' > "$T/crlf-new.md"
out="$(node "$GATE" "$T/crlf-old.md" "$T/crlf-new.md" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [7]: rc=$rc (saída: $out)"; exit 1; }
echo "OK [7]"

echo "PASS w300-changelog-gate-released"
