#!/usr/bin/env bash
# Gate W284 — changelog-engine.mjs, modo explícito (TASK-01).
#
# Cenários:
#   [1] CHANGELOG.md ausente → motor cria com cabeçalho Keep a Changelog padrão.
#   [2] grava "- <description>" na seção "### <Seção-pt-BR>" dentro de [Unreleased].
#   [3] não altera seções de versões já numeradas (byte a byte).
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$WS/template/.forge/skills/readme-generator/scripts/changelog-engine.mjs"

T="$(mktemp -d /tmp/forge-w284.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] CHANGELOG.md ausente -> motor cria com cabecalho Keep a Changelog padrao"
R1="$T/r1"; mkdir -p "$R1"
out="$(node "$ENGINE" --root "$R1" --type added --description "adicionar X" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL [1]: rc=$rc saida: $out"; exit 1
fi
[ -f "$R1/CHANGELOG.md" ] || { echo "FAIL [1]: CHANGELOG.md nao foi criado"; exit 1; }
grep -q '## \[Unreleased\]' "$R1/CHANGELOG.md" || { echo "FAIL [1]: cabecalho [Unreleased] ausente"; exit 1; }
grep -qi 'Keep a Changelog' "$R1/CHANGELOG.md" || { echo "FAIL [1]: referencia a Keep a Changelog ausente no cabecalho"; exit 1; }
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] grava a entrada na secao pt-BR correta dentro de [Unreleased]"
grep -q '### Adicionado' "$R1/CHANGELOG.md" || { echo "FAIL [2]: secao ### Adicionado ausente"; exit 1; }
grep -q -- '- adicionar X' "$R1/CHANGELOG.md" || { echo "FAIL [2]: entrada nao encontrada"; exit 1; }
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] nao altera secoes de versoes ja numeradas"
R3="$T/r3"; mkdir -p "$R3"
cat > "$R3/CHANGELOG.md" <<'EOF'
# Changelog

Todas as mudanças notáveis deste projeto são documentadas (Keep a Changelog).

## [Unreleased]

## [1.0.0] - 2026-01-01

### Adicionado

- entrada original
EOF
before="$(cat "$R3/CHANGELOG.md")"
out="$(node "$ENGINE" --root "$R3" --type fixed --description "corrigir Y" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [3]: rc=$rc saida: $out"; exit 1; }
after_120="$(sed -n '/## \[1.0.0\]/,$p' "$R3/CHANGELOG.md")"
before_120="$(printf '%s\n' "$before" | sed -n '/## \[1.0.0\]/,$p')"
[ "$after_120" = "$before_120" ] || { echo "FAIL [3]: secao [1.0.0] foi alterada"; exit 1; }
grep -q '### Corrigido' "$R3/CHANGELOG.md" || { echo "FAIL [3]: nova secao Corrigido nao criada em Unreleased"; exit 1; }
echo "OK [3]"

echo "PASS w284-changelog-engine-explicito"
