#!/usr/bin/env bash
# Gate W298 — changelog-engine.mjs, modo --merge-range (TASK-03).
#
# Cenários:
#   [1] merge feat+fix gera 2 entradas com sufixo de hash
#   [2] rerodar nao duplica (idempotencia)
#   [3] feat(x)!: ... grava **[BREAKING]**
#   [4] sem CHANGELOG raiz nao cria nada e sai rc 0
#   [5] HEAD nao-merge nao altera o arquivo
#   [6] CHANGELOG sem [Unreleased] ganha a secao criada antes da primeira versao numerada
#   [7] subject com $' no hook fica literal (String.replace com função).
#   [8] comando (--subject) na branch + hook no merge não duplicam a mudança.
#   [9] commits distintos com o mesmo subject: uma entrada por hash.
#   [10] --merge-range fora de repositório git -> erro observável
#   [11] texto igual a entrada manual "lote (2024999)": o hook não duplica.
#   [12] CHANGELOG.md symlink para fora do repositório: FAIL, alvo intocado.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$WS/template/.forge/skills/readme-generator/scripts/changelog-engine.mjs"

T="$(mktemp -d /tmp/forge-w298.XXXXXX)"
trap 'rm -rf "$T"' EXIT

mkmerge() { # mkmerge <dir> — repo com merge de feature (feat+fix) em main
  local d="$1"
  mkdir -p "$d"
  git -C "$d" init -q -b main
  git -C "$d" config user.email t@t; git -C "$d" config user.name t; git -C "$d" config commit.gpgsign false
  printf '# Changelog\n\n## [Unreleased]\n' > "$d/CHANGELOG.md"
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" commit -qm 'chore: init' >/dev/null 2>&1
  git -C "$d" checkout -qb feature >/dev/null 2>&1
  printf 'a\n' > "$d/a.txt"
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" commit -qm 'feat(x): adicionar a' >/dev/null 2>&1
  printf 'b\n' > "$d/b.txt"
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" commit -qm 'fix(x): corrigir b' >/dev/null 2>&1
  git -C "$d" checkout -q main >/dev/null 2>&1
  git -C "$d" merge -q --no-ff feature -m 'merge feature' >/dev/null 2>&1
}

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] merge feat+fix gera 2 entradas com sufixo de hash"
R1="$T/r1"; mkmerge "$R1"
out="$(node "$ENGINE" --root "$R1" --merge-range 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [1]: rc=$rc saida: $out"; exit 1; }
n="$(grep -cE '^\- .*\([0-9a-f]+\)$' "$R1/CHANGELOG.md")"
[ "$n" -eq 2 ] || { echo "FAIL [1]: esperado 2 entradas com sufixo de hash, obtido $n"; cat "$R1/CHANGELOG.md"; exit 1; }
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] rerodar nao duplica (idempotencia)"
node "$ENGINE" --root "$R1" --merge-range >/dev/null 2>&1
n2="$(grep -cE '^\- .*\([0-9a-f]+\)$' "$R1/CHANGELOG.md")"
[ "$n2" -eq 2 ] || { echo "FAIL idempotencia: contagem mudou entre execucoes ($n -> $n2)"; exit 1; }
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] feat(x)!: ... grava **[BREAKING]**"
R3="$T/r3"; mkdir -p "$R3"
git -C "$R3" init -q -b main
git -C "$R3" config user.email t@t; git -C "$R3" config user.name t; git -C "$R3" config commit.gpgsign false
printf '# Changelog\n\n## [Unreleased]\n' > "$R3/CHANGELOG.md"
git -C "$R3" add -A >/dev/null 2>&1; git -C "$R3" commit -qm 'chore: init' >/dev/null 2>&1
git -C "$R3" checkout -qb feature >/dev/null 2>&1
printf 'a\n' > "$R3/a.txt"; git -C "$R3" add -A >/dev/null 2>&1
git -C "$R3" commit -qm 'feat(x)!: remover suporte antigo' >/dev/null 2>&1
git -C "$R3" checkout -q main >/dev/null 2>&1
git -C "$R3" merge -q --no-ff feature -m 'merge feature' >/dev/null 2>&1
out="$(node "$ENGINE" --root "$R3" --merge-range 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [3]: rc=$rc saida: $out"; exit 1; }
grep -q -- '\*\*\[BREAKING\]\*\*' "$R3/CHANGELOG.md" || { echo "FAIL [3]: marcador BREAKING ausente"; exit 1; }
echo "OK [3]"

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] sem CHANGELOG raiz, nao cria nada e sai rc 0"
R4="$T/r4"; mkdir -p "$R4"
git -C "$R4" init -q -b main
git -C "$R4" config user.email t@t; git -C "$R4" config user.name t; git -C "$R4" config commit.gpgsign false
printf 'x\n' > "$R4/a.txt"; git -C "$R4" add -A >/dev/null 2>&1
git -C "$R4" commit -qm 'chore: init' >/dev/null 2>&1
git -C "$R4" checkout -qb feature >/dev/null 2>&1
printf 'y\n' > "$R4/b.txt"; git -C "$R4" add -A >/dev/null 2>&1
git -C "$R4" commit -qm 'feat(x): adicionar b' >/dev/null 2>&1
git -C "$R4" checkout -q main >/dev/null 2>&1
git -C "$R4" merge -q --no-ff feature -m 'merge feature' >/dev/null 2>&1
out="$(node "$ENGINE" --root "$R4" --merge-range 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [4]: rc=$rc saida: $out"; exit 1; }
[ -f "$R4/CHANGELOG.md" ] && { echo "FAIL: CHANGELOG.md criado indevidamente em --merge-range"; exit 1; }
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] HEAD nao-merge nao altera o arquivo"
R5="$T/r5"; mkdir -p "$R5"
git -C "$R5" init -q -b main
git -C "$R5" config user.email t@t; git -C "$R5" config user.name t; git -C "$R5" config commit.gpgsign false
printf '# Changelog\n\n## [Unreleased]\n' > "$R5/CHANGELOG.md"
git -C "$R5" add -A >/dev/null 2>&1; git -C "$R5" commit -qm 'chore: init' >/dev/null 2>&1
before5="$(cat "$R5/CHANGELOG.md")"
out="$(node "$ENGINE" --root "$R5" --merge-range 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [5]: rc=$rc saida: $out"; exit 1; }
after5="$(cat "$R5/CHANGELOG.md")"
[ "$before5" = "$after5" ] || { echo "FAIL [5]: arquivo alterado sem HEAD ser merge"; exit 1; }
echo "OK [5]"

# ── [6] ──────────────────────────────────────────────────────────────────────────────────────
echo "[6] CHANGELOG sem [Unreleased] ganha a secao criada antes da primeira versao numerada"
R6="$T/r6"; mkdir -p "$R6"
git -C "$R6" init -q -b main
git -C "$R6" config user.email t@t; git -C "$R6" config user.name t; git -C "$R6" config commit.gpgsign false
printf '# Changelog\n\n## [1.0.0] - 2026-01-01\n\n### Adicionado\n\n- base\n' > "$R6/CHANGELOG.md"
git -C "$R6" add -A >/dev/null 2>&1; git -C "$R6" commit -qm 'chore: init' >/dev/null 2>&1
git -C "$R6" checkout -qb feature >/dev/null 2>&1
printf 'z\n' > "$R6/z.txt"; git -C "$R6" add -A >/dev/null 2>&1
git -C "$R6" commit -qm 'feat(x): adicionar z' >/dev/null 2>&1
git -C "$R6" checkout -q main >/dev/null 2>&1
git -C "$R6" merge -q --no-ff feature -m 'merge feature' >/dev/null 2>&1
out="$(node "$ENGINE" --root "$R6" --merge-range 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [6]: rc=$rc saida: $out"; exit 1; }
grep -q '## \[Unreleased\]' "$R6/CHANGELOG.md" || { echo "FAIL [6]: secao Unreleased nao criada"; exit 1; }
unrel_line="$(grep -n '## \[Unreleased\]' "$R6/CHANGELOG.md" | head -1 | cut -d: -f1)"
v100_line="$(grep -n '## \[1.0.0\]' "$R6/CHANGELOG.md" | head -1 | cut -d: -f1)"
[ "$unrel_line" -lt "$v100_line" ] || { echo "FAIL [6]: Unreleased nao ficou antes da versao numerada"; exit 1; }
echo "OK [6]"

# ── [7] ──────────────────────────────────────────────────────────────────────────────────────
echo "[7] subject com \$' no hook fica literal e não duplica a entrada antiga"
R7="$T/r7"; mkdir -p "$R7"
git -C "$R7" init -q -b main
git -C "$R7" config user.email t@t; git -C "$R7" config user.name t; git -C "$R7" config commit.gpgsign false
printf '# Changelog\n\n## [Unreleased]\n\n### Corrigido\n- antiga (0000000)\n' > "$R7/CHANGELOG.md"
git -C "$R7" add -A >/dev/null 2>&1; git -C "$R7" commit -qm 'chore: init' >/dev/null 2>&1
git -C "$R7" checkout -qb feature >/dev/null 2>&1
printf 'x\n' > "$R7/x.txt"; git -C "$R7" add -A >/dev/null 2>&1
git -C "$R7" commit -qm "fix: arredonda \$' antes do total" >/dev/null 2>&1
git -C "$R7" checkout -q main >/dev/null 2>&1
git -C "$R7" merge -q --no-ff feature -m 'merge feature' >/dev/null 2>&1
node "$ENGINE" --root "$R7" --merge-range >/dev/null 2>&1 || { echo "FAIL [7]: motor saiu com erro"; exit 1; }
grep -qE -- "^- arredonda \\\$' antes do total \([0-9a-f]+\)\$" "$R7/CHANGELOG.md" || { echo "FAIL [7]: entrada corrompida"; cat "$R7/CHANGELOG.md"; exit 1; }
[ "$(grep -c -- '- antiga' "$R7/CHANGELOG.md")" -eq 1 ] || { echo "FAIL [7]: entrada antiga duplicada"; cat "$R7/CHANGELOG.md"; exit 1; }
echo "OK [7]"

# ── [8] ──────────────────────────────────────────────────────────────────────────────────────
echo "[8] comando na branch (--subject, sem hash) + hook no merge não registram a mudança duas vezes"
R8="$T/r8"; mkdir -p "$R8"
git -C "$R8" init -q -b main
git -C "$R8" config user.email t@t; git -C "$R8" config user.name t; git -C "$R8" config commit.gpgsign false
printf '# Changelog\n\n## [Unreleased]\n' > "$R8/CHANGELOG.md"
git -C "$R8" add -A >/dev/null 2>&1; git -C "$R8" commit -qm 'chore: init' >/dev/null 2>&1
git -C "$R8" checkout -qb feature >/dev/null 2>&1
printf 'x\n' > "$R8/x.txt"; git -C "$R8" add -A >/dev/null 2>&1
git -C "$R8" commit -qm 'feat(api): adiciona exportação' >/dev/null 2>&1
node "$ENGINE" --root "$R8" --subject 'feat(api): adiciona exportação' >/dev/null 2>&1 || { echo "FAIL [8]: --subject saiu com erro"; exit 1; }
git -C "$R8" commit -qam 'docs: changelog' >/dev/null 2>&1
git -C "$R8" checkout -q main >/dev/null 2>&1
git -C "$R8" merge -q --no-ff feature -m 'merge feature' >/dev/null 2>&1
node "$ENGINE" --root "$R8" --merge-range >/dev/null 2>&1 || { echo "FAIL [8]: --merge-range saiu com erro"; exit 1; }
[ "$(grep -c 'adiciona exportação' "$R8/CHANGELOG.md")" -eq 1 ] || { echo "FAIL [8]: mudança registrada duas vezes"; cat "$R8/CHANGELOG.md"; exit 1; }
echo "OK [8]"

# ── [9] ──────────────────────────────────────────────────────────────────────────────────────
echo "[9] dois commits distintos com o mesmo subject geram duas entradas (hash é a chave por commit)"
R9="$T/r9"; mkdir -p "$R9"
git -C "$R9" init -q -b main
git -C "$R9" config user.email t@t; git -C "$R9" config user.name t; git -C "$R9" config commit.gpgsign false
printf '# Changelog\n\n## [Unreleased]\n\n### Corrigido\n- corrige teste instável (abc1234)\n' > "$R9/CHANGELOG.md"
git -C "$R9" add -A >/dev/null 2>&1; git -C "$R9" commit -qm 'chore: init' >/dev/null 2>&1
git -C "$R9" checkout -qb feature >/dev/null 2>&1
printf '1\n' > "$R9/a"; git -C "$R9" add -A >/dev/null 2>&1; git -C "$R9" commit -qm 'fix: corrige teste instável' >/dev/null 2>&1
printf '2\n' > "$R9/b"; git -C "$R9" add -A >/dev/null 2>&1; git -C "$R9" commit -qm 'feat: novo relatório' >/dev/null 2>&1
printf '3\n' > "$R9/c"; git -C "$R9" add -A >/dev/null 2>&1; git -C "$R9" commit -qm 'feat: novo relatório' >/dev/null 2>&1
git -C "$R9" checkout -q main >/dev/null 2>&1
git -C "$R9" merge -q --no-ff feature -m 'merge feature' >/dev/null 2>&1
node "$ENGINE" --root "$R9" --merge-range >/dev/null 2>&1 || { echo "FAIL [9]: motor saiu com erro"; exit 1; }
[ "$(grep -c 'novo relatório (' "$R9/CHANGELOG.md")" -eq 2 ] || { echo "FAIL [9]: commits distintos colapsados"; cat "$R9/CHANGELOG.md"; exit 1; }
[ "$(grep -c 'corrige teste instável (' "$R9/CHANGELOG.md")" -eq 2 ] || { echo "FAIL [9]: commit novo suprimido por entrada antiga com outro hash"; cat "$R9/CHANGELOG.md"; exit 1; }
echo "OK [9]"

# ── [10] ─────────────────────────────────────────────────────────────────────────────────────
echo "[10] --merge-range fora de repositório git -> erro observável (não no-op silencioso)"
R10="$T/r10"; mkdir -p "$R10"
printf '# Changelog\n\n## [Unreleased]\n' > "$R10/CHANGELOG.md"
out="$(GIT_CEILING_DIRECTORIES="$T" node "$ENGINE" --root "$R10" --merge-range 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [10]: rc 0 fora de repositório (saída: $out)"; exit 1; }
case "$out" in *FAIL*) : ;; *) echo "FAIL [10]: saída sem FAIL (saída: $out)"; exit 1 ;; esac
echo "OK [10]"

# ── [11] ─────────────────────────────────────────────────────────────────────────────────────
echo "[11] commit com texto igual a entrada manual terminada em número entre parênteses é pulado"
R11="$T/r11"; mkdir -p "$R11"
git -C "$R11" init -q -b main
git -C "$R11" config user.email t@t; git -C "$R11" config user.name t; git -C "$R11" config commit.gpgsign false
printf '# Changelog\n\n## [Unreleased]\n' > "$R11/CHANGELOG.md"
git -C "$R11" add -A >/dev/null 2>&1; git -C "$R11" commit -qm 'chore: init' >/dev/null 2>&1
git -C "$R11" checkout -qb feature >/dev/null 2>&1
printf '1\n' > "$R11/a"; git -C "$R11" add -A >/dev/null 2>&1; git -C "$R11" commit -qm 'fix: lote (2024999)' >/dev/null 2>&1
node "$ENGINE" --root "$R11" --subject 'fix: lote (2024999)' >/dev/null 2>&1 || { echo "FAIL [11]: --subject saiu com erro"; exit 1; }
git -C "$R11" commit -qam 'docs: changelog' >/dev/null 2>&1
git -C "$R11" checkout -q main >/dev/null 2>&1
git -C "$R11" merge -q --no-ff feature -m 'merge feature' >/dev/null 2>&1
node "$ENGINE" --root "$R11" --merge-range >/dev/null 2>&1 || { echo "FAIL [11]: --merge-range saiu com erro"; exit 1; }
[ "$(grep -c 'lote (2024999)' "$R11/CHANGELOG.md")" -eq 1 ] || { echo "FAIL [11]: mudança registrada duas vezes"; cat "$R11/CHANGELOG.md"; exit 1; }
echo "OK [11]"

# ── [12] ─────────────────────────────────────────────────────────────────────────────────────
echo "[12] hook com CHANGELOG.md symlink para fora do repositório -> FAIL, alvo externo intocado"
R12="$T/r12"; mkdir -p "$R12" "$T/fora12"
printf '# externo\n\n## [Unreleased]\n' > "$T/fora12/rc"
git -C "$R12" init -q -b main
git -C "$R12" config user.email t@t; git -C "$R12" config user.name t; git -C "$R12" config commit.gpgsign false
ln -s ../fora12/rc "$R12/CHANGELOG.md"
git -C "$R12" add -A >/dev/null 2>&1; git -C "$R12" commit -qm 'chore: init' >/dev/null 2>&1
git -C "$R12" checkout -qb feature >/dev/null 2>&1
printf '1\n' > "$R12/a"; git -C "$R12" add -A >/dev/null 2>&1; git -C "$R12" commit -qm 'feat: $(touch marcador)' >/dev/null 2>&1
git -C "$R12" checkout -q main >/dev/null 2>&1
git -C "$R12" merge -q --no-ff feature -m 'merge feature' >/dev/null 2>&1
before="$(cat "$T/fora12/rc")"
out="$(node "$ENGINE" --root "$R12" --merge-range 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [12]: rc 0 gravando fora do repositório (saída: $out)"; exit 1; }
[ "$(cat "$T/fora12/rc")" = "$before" ] || { echo "FAIL [12]: arquivo fora do repositório alterado"; exit 1; }
echo "OK [12]"

echo "PASS w298-changelog-engine-merge-range"
