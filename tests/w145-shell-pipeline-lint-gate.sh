#!/usr/bin/env bash
# Gate W145 — lint de pipeline sob `pipefail` (issue #49, instância 3).
#
# `cmd | grep -q ... || continue` é armadilha: `grep -q` sai no PRIMEIRO casamento, o produtor
# ainda está escrevendo, recebe SIGPIPE, o pipeline devolve 141, `pipefail` promove isso a falha
# do pipeline inteiro e o `|| continue` converte a falha em LINHA PULADA EM SILÊNCIO —
# indistinguível de "linha que não casava o critério". Com `&&` é pior ainda: a asserção do lado
# direito simplesmente não roda, e o teste passa sem ter medido nada. Medido no Axis.PadSimulator:
# 57 exit codes anômalos em 300 execuções com pipe, zero em 300 sem.
#
#   [1] a forma `<produtor> | grep -q ... || <ação>` é acusada, com arquivo:linha
#   [2] a forma com `&&` também é acusada — ali o silêncio come a asserção
#   [3] as variantes de flag (-q, -Eq, -qE, -Fq, -qi) são todas acusadas
#   [4] produtor builtin de saída curta (echo/printf) NÃO é acusado — sem produtor ainda
#       escrevendo não há SIGPIPE, e acusar isso viraria ruído que esvazia o lint
#   [5] `| grep -q` sem `||`/`&&` na sequência não é acusado (o rc é consumido por `if`)
#   [6] alvo limpo passa E imprime o contador de arquivos varridos
#   [7] AUTO-IRONIA (o caso mais provável): universo vazio — diretório sem nenhum .sh — REPROVA.
#       Um lint que aprova por não ter olhado é a própria instância 1 desta issue.
#   [8] o corpus real do harness (template/ + tests/) passa no lint
#
# Segunda classe (LDG-0141) — atribuição por substituição de comando cujo pipeline tem produtor
# falível silenciado com 2>/dev/null, em arquivo que declara `set -e` JUNTO com `pipefail`. Foi a
# forma que matou o w20-spec-gate no CI três execuções seguidas, sem uma linha de saída: o
# `2>/dev/null` é a assinatura do defeito, porque é o autor declarando que espera falha ali e, no
# mesmo gesto, escondendo a única pista que restaria quando pipefail + set -e transformarem essa
# falha em morte silenciosa.
#
#   [9]  `X="$(ls … 2>/dev/null | sort)"` em arquivo estrito REPROVA
#   [10] o mesmo com `|| true` no fim passa
#   [11] o mesmo com `|| <comando>` governando a própria substituição passa
#   [11b] `[ -n "$x" ] || X="$(ls … 2>/dev/null | sort)"` REPROVA — o `||` governa o TESTE
#        anterior, a atribuição é o último comando da lista OR, e sob set -e o script morre.
#        É literalmente impact.sh:21, e é o cenário que impede o escape de virar "qualquer ||"
#   [12] o mesmo idioma em arquivo SEM `set -e` passa — ali a classe não morde
#   [13] contrapositiva: pipeline sem `2>/dev/null` passa (impede o predicado de virar os 46)
#   [14] o corpus real (template/ + tests/ + bin/) passa, com contador de controle
#   [15] mutação: remover a exigência de `2>/dev/null` do reconhecedor faz [13] reprovar
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINT="$WS/template/.forge/scripts/check-shell-pipeline.sh"

T="$(mktemp -d /tmp/forge-w145.XXXXXX)"
trap 'rm -rf "$T"' EXIT

run_lint() { # run_lint <args...> — saída em $out, rc em $rc
  out="$(bash "$LINT" "$@" 2>&1)"; rc=$?
}

# As fixtures montam a forma proibida por CONCATENAÇÃO, nunca literal: o cenário [8] varre o
# corpus inteiro do harness, este arquivo incluído, e uma linha literal aqui faria o gate se
# auto-acusar. O caractere de pipe entra por variável.
P='|'
mkfix() { # mkfix <arquivo> <produtor> <flag-do-grep> <operador> <ação>
  mkdir -p "$(dirname "$1")"
  printf '#!/usr/bin/env bash\nset -euo pipefail\n%s %s grep %s %s %s\n' \
    "$2" "$P" "$3" "$4" "$5" > "$1"
}

[ -f "$LINT" ] || { echo "FAIL [0]: $LINT não existe — o lint da instância 3 não foi entregue"; exit 1; }

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] a forma '<produtor> | grep -q ... || <ação>' é acusada, com arquivo:linha"
mkfix "$T/c1/parser.sh" "sed -n 1,200p \"\$f\"" "-q" "||" "continue"
run_lint --path "$T/c1"
[ "$rc" -ne 0 ] || { echo "FAIL [1]: lint aprovou 'sed ... | grep -q ... || continue' (saída: '$out')"; exit 1; }
case "$out" in
  *"parser.sh:3"*) : ;;
  *) echo "FAIL [1]: lint acusou sem nomear arquivo:linha (saída: '$out')"; exit 1 ;;
esac
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] a forma com '&&' também é acusada"
mkfix "$T/c2/assert.sh" "buckets" "-qE" "&&" "{ echo \"FAIL: órfão duplicado\"; exit 1; }"
run_lint --path "$T/c2"
[ "$rc" -ne 0 ] || { echo "FAIL [2]: lint aprovou 'buckets | grep -qE ... && { ... }' (saída: '$out')"; exit 1; }
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] as variantes de flag (-q, -Eq, -qE, -Fq, -qi) são todas acusadas"
for flag in -q -Eq -qE -Fq -qi; do
  d="$T/c3$flag"
  mkfix "$d/x.sh" "cat f" "$flag" "||" "exit 1"
  run_lint --path "$d"
  [ "$rc" -ne 0 ] || { echo "FAIL [3]: variante '$flag' passou despercebida (saída: '$out')"; exit 1; }
done
echo "OK [3]"

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] produtor builtin de saída curta (echo/printf) NÃO é acusado"
mkfix "$T/c4/validate.sh" "echo \"\$ID\"" "-Eq" "||" "{ echo \"FAIL: id inválido\"; exit 2; }"
mkfix "$T/c4/validate2.sh" "printf %s \"\$files\"" "-qx" "&&" "has_readme=1"
run_lint --path "$T/c4"
[ "$rc" -eq 0 ] || { echo "FAIL [4]: lint acusou produtor builtin de linha única — falso positivo esvazia o lint (saída: '$out')"; exit 1; }
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] '| grep -q' sem '||'/'&&' na sequência não é acusado"
mkfix "$T/c5/ok.sh" "if git log --format=%s HEAD" "-q" ";" "then echo tem-fix; fi"
run_lint --path "$T/c5"
[ "$rc" -eq 0 ] || { echo "FAIL [5]: falso positivo em pipeline cujo rc é consumido por 'if' (saída: '$out')"; exit 1; }
echo "OK [5]"

# ── [6] ──────────────────────────────────────────────────────────────────────────────────────
echo "[6] alvo limpo passa E imprime o contador de arquivos varridos"
case "$out" in
  *"2 arquivo(s)"*|*"1 arquivo(s)"*) : ;;
  *) echo "FAIL [6]: alvo limpo passou sem contador de controle — 'não varri' e 'varri e estava limpo' colapsam (saída: '$out')"; exit 1 ;;
esac
echo "OK [6]"

# ── [7] AUTO-IRONIA ──────────────────────────────────────────────────────────────────────────
echo "[7] universo vazio (diretório sem .sh) REPROVA — o lint não pode aprovar por não ter olhado"
mkdir -p "$T/vazio"
printf 'nada aqui\n' > "$T/vazio/README.md"
run_lint --path "$T/vazio"
[ "$rc" -ne 0 ] || { echo "FAIL [7]: o próprio lint aprovou um universo vazio — é a instância 1 dentro da correção da instância 3 (saída: '$out')"; exit 1; }
case "$out" in
  *universo-vazio*) : ;;
  *) echo "FAIL [7]: reprovou sem nomear o estado de universo vazio (saída: '$out')"; exit 1 ;;
esac
echo "OK [7]"

# ── [8] ──────────────────────────────────────────────────────────────────────────────────────
echo "[8] o corpus real do harness (template/ + tests/) passa no lint"
run_lint --path "$WS/template" --path "$WS/tests"
[ "$rc" -eq 0 ] || { echo "FAIL [8]: o harness tem ocorrências da forma proibida:
$out"; exit 1; }
echo "OK [8]"

# ── segunda classe: substituição de comando sob set -e + pipefail (LDG-0141) ─────────────────
# Mesma disciplina de [1]-[8]: a forma proibida nunca aparece LITERAL neste arquivo, senão [14]
# (que varre tests/) acusaria o próprio gate. O pipe entra por @PIPE@, trocado em tempo de
# execução — e sem o pipe a linha do fonte não é da classe, porque a classe EXIGE pipeline.
mkcs() { # mkcs <arquivo> <strict|loose> <linha com @PIPE@>
  mkdir -p "$(dirname "$1")"
  local hdr='set -euo pipefail'
  [ "$2" = strict ] || hdr='set -uo pipefail'
  printf '#!/usr/bin/env bash\n%s\nD=/tmp\n%s\necho "$X"\n' "$hdr" "${3//@PIPE@/$P}" > "$1"
}

echo "[9] atribuição com produtor falível + 2>/dev/null sob set -e + pipefail REPROVA"
mkcs "$T/c9/impact.sh" strict 'X="$(ls -1 "$D" 2>/dev/null @PIPE@ sort)"'
run_lint --path "$T/c9"
[ "$rc" -ne 0 ] || { echo "FAIL [9]: lint aprovou a forma que matou o w20-spec-gate no CI (saída: '$out')"; exit 1; }
case "$out" in
  *"impact.sh:4"*) : ;;
  *) echo "FAIL [9]: acusou sem nomear arquivo:linha (saída: '$out')"; exit 1 ;;
esac
echo "OK [9]"

echo "[10] o mesmo com '|| true' no fim passa"
mkcs "$T/c10/ok.sh" strict 'X="$(ls -1 "$D" 2>/dev/null @PIPE@ sort)" || true'
run_lint --path "$T/c10"
[ "$rc" -eq 0 ] || { echo "FAIL [10]: '|| true' governando a substituição é escape legítimo (saída: '$out')"; exit 1; }
echo "OK [10]"

echo "[11] o mesmo com '|| <comando>' governando a própria substituição passa"
mkcs "$T/c11/ok.sh" strict 'X="$(ls -1 "$D" 2>/dev/null @PIPE@ sort)" || X="$(git rev-parse HEAD)"'
run_lint --path "$T/c11"
[ "$rc" -eq 0 ] || { echo "FAIL [11]: '||' que governa a substituição é escape legítimo (saída: '$out')"; exit 1; }
echo "OK [11]"

echo "[11b] '|| ' que governa o TESTE anterior NÃO é escape — é impact.sh:21, e mata o script"
mkcs "$T/c11b/impact.sh" strict '[ -n "${X:-}" ] || X="$(ls -1 "$D" 2>/dev/null @PIPE@ sort)"'
run_lint --path "$T/c11b"
[ "$rc" -ne 0 ] || { echo "FAIL [11b]: o reconhecedor aceitou QUALQUER '||' como escape — deixa passar impact.sh:21, que é da classe e é letal (saída: '$out')"; exit 1; }
echo "OK [11b]"

echo "[12] o mesmo idioma em arquivo SEM 'set -e' passa — ali a classe não morde"
mkcs "$T/c12/loose.sh" loose 'X="$(ls -1 "$D" 2>/dev/null @PIPE@ sort)"'
run_lint --path "$T/c12"
[ "$rc" -eq 0 ] || { echo "FAIL [12]: falso positivo em arquivo sem 'set -e' — 40 dos 198 .sh do harness declaram pipefail sem -e (saída: '$out')"; exit 1; }
echo "OK [12]"

echo "[13] contrapositiva: pipeline SEM 2>/dev/null passa"
mkcs "$T/c13/a.sh" strict 'X="$(shasum "$D/f" @PIPE@ cut -d" " -f1)"'
mkcs "$T/c13/b.sh" strict 'X="$(grep -c . "$D/f" @PIPE@ wc -l)"'
run_lint --path "$T/c13"
[ "$rc" -eq 0 ] || { echo "FAIL [13]: o predicado virou 'qualquer pipeline em \$( )' — são 46 linhas do próprio harness (saída: '$out')"; exit 1; }
echo "OK [13]"

echo "[14] o corpus real (template/ + tests/ + bin/) passa, com contador de controle"
run_lint --path "$WS/template" --path "$WS/tests" --path "$WS/bin"
[ "$rc" -eq 0 ] || { echo "FAIL [14]: o harness tem ocorrências da segunda classe:
$out"; exit 1; }
case "$out" in
  *"arquivo(s) .sh"*) : ;;
  *) echo "FAIL [14]: corpus real passou sem contador de controle (saída: '$out')"; exit 1 ;;
esac
echo "OK [14] — $out"

echo "[15] mutação: remover a exigência de 2>/dev/null do reconhecedor faz [13] reprovar"
MUT="$T/mut"
mkdir -p "$MUT/lib"
cp "$WS/template/.forge/scripts/check-shell-pipeline.sh" "$MUT/check-shell-pipeline.sh"
cp "$WS/template/.forge/scripts/lib/gate-universe.sh" "$MUT/lib/gate-universe.sh"
cp "$WS/template/.forge/scripts/lib/shell-pipeline-lint.mjs" "$MUT/lib/shell-pipeline-lint.mjs"
cp "$MUT/lib/shell-pipeline-lint.mjs" "$T/lint.orig"
mut_lint() { out="$(bash "$MUT/check-shell-pipeline.sh" "$@" 2>&1)"; rc=$?; }
mut_lint --path "$T/c13"
[ "$rc" -eq 0 ] || { echo "FAIL [15]: pré-condição — a cópia do lint já reprova [13] antes da mutação (saída: '$out')"; exit 1; }
perl -0pi -e 's/const REQUIRE_SILENCED_STDERR = true;/const REQUIRE_SILENCED_STDERR = false;/' "$MUT/lib/shell-pipeline-lint.mjs"
cmp -s "$MUT/lib/shell-pipeline-lint.mjs" "$T/lint.orig" && { echo "FAIL [15]: a mutação não alterou o arquivo — o ponto de mutação mudou de nome"; exit 1; }
mut_lint --path "$T/c13"
[ "$rc" -ne 0 ] || { echo "FAIL [15]: sem a exigência de 2>/dev/null, [13] continuou passando — a restrição não é o que decide (saída: '$out')"; exit 1; }
cp "$T/lint.orig" "$MUT/lib/shell-pipeline-lint.mjs"
cmp -s "$MUT/lib/shell-pipeline-lint.mjs" "$T/lint.orig" || { echo "FAIL [15]: restauração não bateu byte a byte (cmp)"; exit 1; }
mut_lint --path "$T/c13"
[ "$rc" -eq 0 ] || { echo "FAIL [15]: recontrole — depois da restauração [13] não voltou a passar (saída: '$out')"; exit 1; }
echo "OK [15] — mutou, reprovou, restaurou (cmp ok), voltou a passar"

echo "PASS w145-shell-pipeline-lint"
