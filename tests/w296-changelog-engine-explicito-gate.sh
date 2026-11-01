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
#   [7] symlink preservado, alvo recebe a entrada, modo preservado, sem temporário residual.
#   [8] deduplicação por seção + texto.
#   [9] "## [unreleased]" minúsculo reconhecido.
#   [10] falha de escrita sai por FAIL e sem temporário residual
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

# ── [7] ──────────────────────────────────────────────────────────────────────────────────────
echo "[7] CHANGELOG.md symlink continua symlink, o alvo recebe a entrada e o modo é preservado"
R7="$T/r7"; mkdir -p "$R7/docs"
printf '# Changelog\n\n## [Unreleased]\n' > "$R7/docs/CHANGELOG.md"; chmod 664 "$R7/docs/CHANGELOG.md"
ln -s docs/CHANGELOG.md "$R7/CHANGELOG.md"
node "$ENGINE" --root "$R7" --type added --description "entrada via link" >/dev/null 2>&1 || { echo "FAIL [7]: motor saiu com erro"; exit 1; }
[ -L "$R7/CHANGELOG.md" ] || { echo "FAIL [7]: o symlink virou arquivo regular"; exit 1; }
grep -q 'entrada via link' "$R7/docs/CHANGELOG.md" || { echo "FAIL [7]: o alvo do link não recebeu a entrada"; exit 1; }
[ "$(ls -l "$R7/docs/CHANGELOG.md" | cut -c1-10)" = "-rw-rw-r--" ] || { echo "FAIL [7]: modo do arquivo não preservado ($(ls -l "$R7/docs/CHANGELOG.md" | cut -c1-10))"; exit 1; }
ls "$R7/docs" | grep -q '\.tmp-' && { echo "FAIL [7]: temporário deixado para trás"; exit 1; }
echo "OK [7]"

# ── [8] ──────────────────────────────────────────────────────────────────────────────────────
echo "[8] deduplicação considera a seção: mesmo texto em outra seção é gravado"
R8="$T/r8"; mkdir -p "$R8"
printf '# Changelog\n\n## [Unreleased]\n\n### Adicionado\n- suporte a PIX\n' > "$R8/CHANGELOG.md"
node "$ENGINE" --root "$R8" --type removed --description "suporte a PIX" >/dev/null 2>&1 || { echo "FAIL [8]: motor saiu com erro"; exit 1; }
grep -q '### Removido' "$R8/CHANGELOG.md" && [ "$(grep -c -- '- suporte a PIX' "$R8/CHANGELOG.md")" -eq 2 ] \
  || { echo "FAIL [8]: entrada em outra seção suprimida pela deduplicação"; cat "$R8/CHANGELOG.md"; exit 1; }
echo "OK [8]"

# ── [9] ──────────────────────────────────────────────────────────────────────────────────────
echo "[9] '## [unreleased]' em minúscula é reconhecido: nenhum segundo bloco é criado"
R9="$T/r9"; mkdir -p "$R9"
printf '# Changelog\n\n## [unreleased]\n\n### Adicionado\n- pendente\n' > "$R9/CHANGELOG.md"
node "$ENGINE" --root "$R9" --type added --description "nova" >/dev/null 2>&1 || { echo "FAIL [9]: motor saiu com erro"; exit 1; }
[ "$(grep -ci '^## \[unreleased\]' "$R9/CHANGELOG.md")" -eq 1 ] || { echo "FAIL [9]: segundo bloco Unreleased criado"; cat "$R9/CHANGELOG.md"; exit 1; }
echo "OK [9]"

# ── [10] ─────────────────────────────────────────────────────────────────────────────────────
echo "[10] falha na escrita sai por FAIL (sem stack trace) e não deixa temporário"
R10="$T/r10"; mkdir -p "$R10"
printf '# Changelog\n\n## [Unreleased]\n' > "$R10/CHANGELOG.md"
chmod 555 "$R10"
out="$(node "$ENGINE" --root "$R10" --type added --description "x" 2>&1)"; rc=$?
chmod 755 "$R10"
[ "$rc" -ne 0 ] || { echo "FAIL [10]: rc 0 com diretório sem escrita (saída: $out)"; exit 1; }
case "$out" in *"FAIL: escrita"*) : ;; *) echo "FAIL [10]: saída fora da convenção FAIL (saída: $out)"; exit 1 ;; esac
ls "$R10" | grep -q '\.tmp-' && { echo "FAIL [10]: temporário deixado para trás"; exit 1; }
echo "OK [10]"

echo "PASS w296-changelog-engine-explicito"
