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

echo "PASS w145-shell-pipeline-lint"
