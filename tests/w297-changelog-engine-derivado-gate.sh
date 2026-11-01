#!/usr/bin/env bash
# Gate W285 — changelog-engine.mjs, modo derivado (TASK-02).
#
# Cenários:
#   [1] --subject "feat(x): ..." gera ### Adicionado
#   [2] --subject "perf(x): ..." gera ### Corrigido (DIV-01, nunca Changed/Alterado)
#   [3] --subject "refactor(x): ..." nao gera entrada (DIV-02)
#   [4] --path <componente-existente> varre o intervalo de commits e gera entrada (positivo)
#   [5] --path <inexistente> sai com rc=2 (negativo)
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$WS/template/.forge/skills/readme-generator/scripts/changelog-engine.mjs"

T="$(mktemp -d /tmp/forge-w285.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] --subject feat(x): ... gera ### Adicionado"
R1="$T/r1"; mkdir -p "$R1"
out="$(node "$ENGINE" --root "$R1" --subject 'feat(x): adicionar coisa' 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [1]: rc=$rc saida: $out"; exit 1; }
grep -q '### Adicionado' "$R1/CHANGELOG.md" 2>/dev/null || { echo "FAIL [1]: secao Adicionado ausente"; exit 1; }
grep -q -- '- adicionar coisa' "$R1/CHANGELOG.md" || { echo "FAIL [1]: entrada ausente"; exit 1; }
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] --subject perf(x): ... gera ### Corrigido, nunca Changed/Alterado"
R2="$T/r2"; mkdir -p "$R2"
out="$(node "$ENGINE" --root "$R2" --subject 'perf(x): acelerar query' 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [2]: rc=$rc saida: $out"; exit 1; }
grep -q '### Corrigido' "$R2/CHANGELOG.md" 2>/dev/null || { echo "FAIL [2]: secao Corrigido ausente"; exit 1; }
grep -qE '### (Changed|Alterado)' "$R2/CHANGELOG.md" 2>/dev/null && { echo "FAIL [2]: perf foi mapeado para Changed/Alterado"; exit 1; }
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] --subject refactor(x): ... nao gera entrada"
R3="$T/r3"; mkdir -p "$R3"
out="$(node "$ENGINE" --root "$R3" --subject 'refactor(x): reorganizar modulo' 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [3]: rc=$rc saida: $out"; exit 1; }
if [ -f "$R3/CHANGELOG.md" ] && grep -q 'reorganizar modulo' "$R3/CHANGELOG.md"; then
  echo "FAIL [3]: refactor gerou entrada indevidamente"; exit 1
fi
echo "OK [3]"

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] --path <componente-existente> varre commits e gera entrada"
R4="$T/r4"; mkdir -p "$R4/comp"
git -C "$R4" init -q -b main
git -C "$R4" config user.email t@t; git -C "$R4" config user.name t; git -C "$R4" config commit.gpgsign false
printf 'x\n' > "$R4/comp/a.txt"
git -C "$R4" add -A >/dev/null 2>&1
git -C "$R4" commit -qm 'feat(comp): adicionar arquivo a' >/dev/null 2>&1
out="$(node "$ENGINE" --root "$R4" --path comp 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [4]: rc=$rc saida: $out"; exit 1; }
grep -q 'adicionar arquivo a' "$R4/CHANGELOG.md" 2>/dev/null || { echo "FAIL [4]: entrada do componente nao encontrada (saida: $out)"; exit 1; }
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] --path <inexistente> sai com rc=2"
out="$(node "$ENGINE" --root "$R4" --path comp-inexistente 2>&1)"; rc=$?
if [ "$rc" -ne 2 ]; then
  echo "FAIL [5]: rc esperado 2, obtido $rc — --path inexistente aceito indevidamente (saida: $out)"
  exit 1
fi
echo "OK [5]"

echo "PASS w285-changelog-engine-derivado"
