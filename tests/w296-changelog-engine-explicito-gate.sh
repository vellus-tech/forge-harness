#!/usr/bin/env bash
# Gate W296 — changelog-engine.mjs, modo explícito (TASK-01).
#
# Cenários:
#   [1] CHANGELOG.md ausente → motor cria com cabeçalho Keep a Changelog padrão.
#   [2] grava "- <description>" na seção "### <Seção-pt-BR>" dentro de [Unreleased].
#   [3] não altera seções de versões já numeradas (byte a byte).
#   [4] padrões $' $& $1 do texto ficam literais (String.replace com função).
#   [5] rodar duas vezes não duplica (deduplicação em [Unreleased]).
#   [6] CRLF preservado, seção publicada intacta.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$WS/template/.forge/skills/readme-generator/scripts/changelog-engine.mjs"

T="$(mktemp -d /tmp/forge-w296.XXXXXX)"
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

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] padrões de String.replace (\$' \$& \$1) no texto da entrada ficam literais"
R4="$T/r4"; mkdir -p "$R4"
printf '# Changelog\n\n## [Unreleased]\n\n### Corrigido\n- antiga\n' > "$R4/CHANGELOG.md"
desc='custo de US$'"'"' por item $& e $1'
node "$ENGINE" --root "$R4" --type fixed --description "$desc" >/dev/null 2>&1 \
  || { echo "FAIL [4]: motor saiu com erro"; exit 1; }
grep -qxF -- "- $desc" "$R4/CHANGELOG.md" || { echo "FAIL [4]: entrada corrompida pela interpretação de padrões do replace"; cat "$R4/CHANGELOG.md"; exit 1; }
[ "$(grep -c -- '- antiga' "$R4/CHANGELOG.md")" -eq 1 ] || { echo "FAIL [4]: entrada antiga duplicada"; cat "$R4/CHANGELOG.md"; exit 1; }
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] rodar o modo explícito duas vezes não duplica a entrada"
node "$ENGINE" --root "$R4" --type fixed --description "$desc" >/dev/null 2>&1 \
  || { echo "FAIL [5]: motor saiu com erro na segunda rodada"; exit 1; }
[ "$(grep -cxF -- "- $desc" "$R4/CHANGELOG.md")" -eq 1 ] || { echo "FAIL [5]: entrada duplicada"; cat "$R4/CHANGELOG.md"; exit 1; }
echo "OK [5]"

# ── [6] ──────────────────────────────────────────────────────────────────────────────────────
echo "[6] CHANGELOG em CRLF: terminadores preservados e seção publicada byte a byte idêntica"
R6="$T/r6"; mkdir -p "$R6"
printf '# Changelog\r\n\r\n## [Unreleased]\r\n\r\n## [1.0.0]\r\n\r\n### Adicionado\r\n- publicado\r\n' > "$R6/CHANGELOG.md"
cp "$R6/CHANGELOG.md" "$T/r6-antes.md"
node "$ENGINE" --root "$R6" --type added --description "nova" >/dev/null 2>&1 || { echo "FAIL [6]: motor saiu com erro"; exit 1; }
if LC_ALL=C grep -q "$(printf '[^\r]$')" "$R6/CHANGELOG.md"; then echo "FAIL [6]: linha sem CR no arquivo CRLF"; od -c "$R6/CHANGELOG.md" | head; exit 1; fi
tail -c 40 "$T/r6-antes.md" | cmp -s - <(tail -c 40 "$R6/CHANGELOG.md") || { echo "FAIL [6]: seção publicada alterada"; exit 1; }
echo "OK [6]"

echo "PASS w296-changelog-engine-explicito"
