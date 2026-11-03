#!/usr/bin/env bash
# Gate W297 — changelog-engine.mjs, modo derivado (TASK-02).
#
# Cenários:
#   [1] --subject "feat(x): ..." gera ### Adicionado
#   [2] --subject "perf(x): ..." gera ### Corrigido (DIV-01, nunca Changed/Alterado)
#   [3] --subject "refactor(x): ..." nao gera entrada (DIV-02)
#   [4] --path <componente-existente> varre os commits da branch desde a base e gera entrada
#   [5] --path <inexistente> sai com rc=2 (negativo)
#   [6] --path não traz commits que já estavam na base
#   [7] rodar --path de novo não duplica
#   [8] --path fora de repositório git -> rc 2, sem criar arquivo
#   [9] base padrão = a de merge-base mais próximo (develop defasada não arrasta histórico).
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$WS/template/.forge/skills/readme-generator/scripts/changelog-engine.mjs"

T="$(mktemp -d /tmp/forge-w297.XXXXXX)"
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
echo "[4] --path <componente-existente> varre os commits da branch desde a base e gera entrada"
R4="$T/r4"; mkdir -p "$R4/comp"
git -C "$R4" init -q -b main
git -C "$R4" config user.email t@t; git -C "$R4" config user.name t; git -C "$R4" config commit.gpgsign false
printf 'x\n' > "$R4/comp/a.txt"
git -C "$R4" add -A >/dev/null 2>&1
git -C "$R4" commit -qm 'feat(comp): criar o componente (já publicado)' >/dev/null 2>&1
git -C "$R4" checkout -qb feature >/dev/null 2>&1
printf 'y\n' > "$R4/comp/b.txt"
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

# ── [6] ──────────────────────────────────────────────────────────────────────────────────────
echo "[6] --path não traz commits que já estavam na base (histórico publicado)"
grep -q 'criar o componente' "$R4/CHANGELOG.md" && { echo "FAIL [6]: commit da base reinserido em [Unreleased]"; cat "$R4/CHANGELOG.md"; exit 1; }
echo "OK [6]"

# ── [7] ──────────────────────────────────────────────────────────────────────────────────────
echo "[7] rodar --path de novo não duplica"
node "$ENGINE" --root "$R4" --path comp >/dev/null 2>&1 || { echo "FAIL [7]: segunda rodada saiu com erro"; exit 1; }
[ "$(grep -c 'adicionar arquivo a' "$R4/CHANGELOG.md")" -eq 1 ] || { echo "FAIL [7]: entrada duplicada"; cat "$R4/CHANGELOG.md"; exit 1; }
echo "OK [7]"

# ── [8] ──────────────────────────────────────────────────────────────────────────────────────
echo "[8] --path fora de repositório git -> rc 2, sem criar CHANGELOG (falha do git não é 'nada a registrar')"
R8="$T/r8"; mkdir -p "$R8/comp"
out="$(node "$ENGINE" --root "$R8" --path comp 2>&1)"; rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL [8]: rc esperado 2, obtido $rc (saida: $out)"; exit 1; }
[ ! -e "$R8/CHANGELOG.md" ] || { echo "FAIL [8]: CHANGELOG criado mesmo com o git falhando"; exit 1; }
echo "OK [8]"

# ── [9] ──────────────────────────────────────────────────────────────────────────────────────
echo "[9] develop defasada não arrasta para [Unreleased] o que já saiu por main (base mais próxima)"
R9="$T/r9"; mkdir -p "$R9/comp"
git -C "$R9" init -q -b main
git -C "$R9" config user.email t@t; git -C "$R9" config user.name t; git -C "$R9" config commit.gpgsign false
printf '0\n' > "$R9/comp/z.txt"; git -C "$R9" add -A >/dev/null 2>&1; git -C "$R9" commit -qm 'chore: init' >/dev/null 2>&1
git -C "$R9" branch develop >/dev/null 2>&1
printf '1\n' > "$R9/comp/p.txt"; git -C "$R9" add -A >/dev/null 2>&1; git -C "$R9" commit -qm 'feat(comp): recurso publicado em 1.0.0' >/dev/null 2>&1
git -C "$R9" checkout -qb feat/y >/dev/null 2>&1
printf '2\n' > "$R9/comp/q.txt"; git -C "$R9" add -A >/dev/null 2>&1; git -C "$R9" commit -qm 'fix(comp): corrige o novo' >/dev/null 2>&1
out="$(node "$ENGINE" --root "$R9" --path comp 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [9]: rc=$rc saida: $out"; exit 1; }
grep -q 'corrige o novo' "$R9/CHANGELOG.md" || { echo "FAIL [9]: entrada da branch ausente (saida: $out)"; exit 1; }
grep -q 'recurso publicado' "$R9/CHANGELOG.md" && { echo "FAIL [9]: commit já publicado por main reinserido (saida: $out)"; exit 1; }
echo "OK [9]"

echo "PASS w297-changelog-engine-derivado"
