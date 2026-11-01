#!/usr/bin/env bash
# Gate W302 — gates/lint.mjs (TASK-07): travessao, quebra de linha dentro de paragrafo,
# acentuacao ASCII, placeholder, link quebrado.
#
# Cenarios:
#   [1] entrada com travessao -> FAIL
#   [2] entrada com "nao" em vez de "não" -> FAIL
#   [3] entrada limpa -> passa
#   [4] grafias corretas (exemplo, esta, estação, paginação, todo, sub-item) passam
#   [5] --since: só entradas novas são verificadas
#   [6] CRLF não esconde violação
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$WS/template/.forge/skills/readme-generator/scripts/gates/lint.mjs"

T="$(mktemp -d /tmp/forge-w302.XXXXXX)"
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

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] grafias corretas não reprovam (exemplo, esta, estação, paginação, todo, sub-item)"
cat > "$T/corretas.md" <<'EOF'
# Changelog

## [Unreleased]

### Adicionado

- Adiciona um exemplo de configuração
- Ajusta esta rotina e corrige a paginação da estação
- Valida todo commit antes do push
- Novo relatório:
  - exporta em CSV
EOF
out="$(node "$GATE" "$T/corretas.md" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [4]: falso positivo (saída: $out)"; exit 1; }
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] --since: travessão histórico numa versão publicada não trava entrada nova limpa"
printf '# C\n\n## [Unreleased]\n\n## [1.0.0]\n\n### Adicionado\n- Primeira versão — publicada\n' > "$T/hist-old.md"
printf '# C\n\n## [Unreleased]\n\n### Corrigido\n- Corrige a leitura do arquivo\n\n## [1.0.0]\n\n### Adicionado\n- Primeira versão — publicada\n' > "$T/hist-new.md"
out="$(node "$GATE" "$T/hist-new.md" --since "$T/hist-old.md" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [5]: histórico travou o lint (saída: $out)"; exit 1; }
printf '# C\n\n## [Unreleased]\n\n### Corrigido\n- Corrige — a leitura\n\n## [1.0.0]\n\n### Adicionado\n- Primeira versão — publicada\n' > "$T/hist-bad.md"
out="$(node "$GATE" "$T/hist-bad.md" --since "$T/hist-old.md" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL [5]: entrada nova com travessão aprovada com --since (saída: $out)"; exit 1; }
echo "OK [5]"

# ── [6] ──────────────────────────────────────────────────────────────────────────────────────
echo "[6] arquivo em CRLF não esconde violação"
printf '# Changelog\r\n\r\n## [Unreleased]\r\n\r\n### Adicionado\r\n\r\n- nova — TODO nao\r\n' > "$T/crlf.md"
out="$(node "$GATE" "$T/crlf.md" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL [6]: CRLF aprovou violação (saída: $out)"; exit 1; }
echo "OK [6]"

echo "PASS w302-changelog-gate-lint"
