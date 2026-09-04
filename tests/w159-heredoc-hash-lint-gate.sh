#!/usr/bin/env bash
# Gate W159 — lint de sustenido dentro de heredoc aninhado em $( ) (LDG-0052).
#
# Um heredoc que chama `node`/`python` — o idioma que todo script do harness usa — normalmente
# vive dentro de `$( … )`: `var="$(node - <<'EOF' … EOF)"`. Isso NÃO torna o corpo do heredoc
# imune ao próprio bash: uma linha do corpo com `(` sem aspas, depois `#` sem aspas, depois `)`
# sem aspas — tipicamente prosa "(issue #49, instância 1)" — faz o bash que escaneia o `$( )` por
# fora tratar o `#` como início de comentário e engolir o `)` que fecharia o `(` anterior. O
# `$( )` externo nunca fecha: "bad substitution: no closing `)`" em RUNTIME. `bash -n` não vê
# nada — a sintaxe crua é válida. Medido: a quotação do delimitador do heredoc (nenhuma, simples,
# dupla, \escape) NÃO protege nada — só protege quando o próprio `#` está dentro de uma string
# aspeada no corpo. Reproduzido ponta-a-ponta em check-liaison-acks.sh.
#
#   [1] a forma perigosa com delimitador SEM aspas é acusada, nomeando arquivo e as duas linhas
#       (onde o heredoc abre e onde o sustenido perigoso mora)
#   [2] a MESMA forma com delimitador de aspas simples (`<<'EOF'`) também é acusada — a quotação
#       do delimitador não protege
#   [3] sustenido sem parênteses ao redor NÃO é acusado (não há `)` a perder)
#   [4] sustenido dentro de string aspeada no corpo NÃO é acusado (o bash nunca o vê avulso)
#   [5] o MESMO padrão perigoso, mas o heredoc NÃO vive dentro de $( ) — não reproduz, não é
#       acusado
#   [6] alvo limpo passa E imprime o contador de arquivos varridos
#   [7] AUTO-IRONIA: universo vazio (diretório sem nenhum .sh) REPROVA
#   [8] o corpus real do harness (template/ + tests/ + bin/) passa no lint
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINT="$WS/template/.forge/scripts/check-heredoc-hash.sh"

T="$(mktemp -d /tmp/forge-w159.XXXXXX)"
trap 'rm -rf "$T"' EXIT

run_lint() { # run_lint <args...> — saída em $out, rc em $rc
  out="$(bash "$LINT" "$@" 2>&1)"; rc=$?
}

[ -f "$LINT" ] || { echo "FAIL [0]: $LINT não existe — o lint da LDG-0052 não foi entregue"; exit 1; }

# Cada fixture escreve um heredoc PRÓPRIO, não aninhado em $( ) — só o CONTEÚDO escrito imita a
# forma perigosa. Como o `cat > arquivo <<'FIX'` que grava a fixture não está, ele mesmo, dentro
# de $( ), este gate nunca reproduz o bug nele mesmo (nem se autoacusa no cenário [8]).

echo "[1] delimitador SEM aspas: '(' ... '#' ... ')' cru no corpo, dentro de \$( ) — acusado"
mkdir -p "$T/c1"
cat > "$T/c1/danger.sh" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
var="$(node - <<NODEEOF
// nota de bug (issue #49, instancia 1)
console.log(1)
NODEEOF
)"
echo "$var"
FIX
run_lint --path "$T/c1"
[ "$rc" -ne 0 ] || { echo "FAIL [1]: lint aprovou o padrão perigoso (saída: '$out')"; exit 1; }
case "$out" in
  *"danger.sh"*"aberto na linha 3"*"linha 4"*) : ;;
  *) echo "FAIL [1]: lint acusou sem nomear arquivo/linha de abertura/linha do sustenido (saída: '$out')"; exit 1 ;;
esac
echo "OK [1]"

echo "[2] MESMA forma, delimitador com aspas simples — quotação do delimitador não protege"
mkdir -p "$T/c2"
cat > "$T/c2/danger.sh" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
var="$(node - <<'NODEEOF'
// nota de bug (issue #49, instancia 1)
console.log(1)
NODEEOF
)"
echo "$var"
FIX
run_lint --path "$T/c2"
[ "$rc" -ne 0 ] || { echo "FAIL [2]: delimitador aspeado passou despercebido — quotação do delimitador NÃO protege este bug (saída: '$out')"; exit 1; }
echo "OK [2]"

echo "[3] sustenido SEM parênteses ao redor não é acusado (não há ')' a perder)"
mkdir -p "$T/c3"
cat > "$T/c3/safe.sh" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
var="$(node - <<'NODEEOF'
// nota de bug: issue #49, instancia 1
console.log(1)
NODEEOF
)"
echo "$var"
FIX
run_lint --path "$T/c3"
[ "$rc" -eq 0 ] || { echo "FAIL [3]: falso positivo em sustenido sem parênteses ao redor (saída: '$out')"; exit 1; }
echo "OK [3]"

echo "[4] sustenido dentro de string aspeada no corpo não é acusado"
mkdir -p "$T/c4"
cat > "$T/c4/safe.sh" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
var="$(node - <<'NODEEOF'
const s = "(issue #49)";
console.log(1)
NODEEOF
)"
echo "$var"
FIX
run_lint --path "$T/c4"
[ "$rc" -eq 0 ] || { echo "FAIL [4]: falso positivo em sustenido dentro de string aspeada (saída: '$out')"; exit 1; }
echo "OK [4]"

echo "[5] o MESMO padrão perigoso, mas o heredoc NÃO vive dentro de \$( ) — não reproduz"
mkdir -p "$T/c5"
cat > "$T/c5/safe.sh" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
node - <<NODEEOF
// nota de bug (issue #49, instancia 1)
console.log(1)
NODEEOF
echo done
FIX
run_lint --path "$T/c5"
[ "$rc" -eq 0 ] || { echo "FAIL [5]: falso positivo fora de \$( ) — o padrão só reproduz quando aninhado em \$( ) (saída: '$out')"; exit 1; }
echo "OK [5]"

echo "[6] alvo limpo passa E imprime o contador de arquivos varridos"
run_lint --path "$T/c3" --path "$T/c4" --path "$T/c5"
[ "$rc" -eq 0 ] || { echo "FAIL [6]: alvo limpo reprovou (saída: '$out')"; exit 1; }
case "$out" in
  *"3 arquivo(s)"*) : ;;
  *) echo "FAIL [6]: alvo limpo passou sem contador de controle — 'não varri' e 'varri e estava limpo' colapsam (saída: '$out')"; exit 1 ;;
esac
echo "OK [6]"

echo "[7] AUTO-IRONIA: universo vazio (diretório sem .sh) REPROVA"
mkdir -p "$T/vazio"
printf 'nada aqui\n' > "$T/vazio/README.md"
run_lint --path "$T/vazio"
[ "$rc" -ne 0 ] || { echo "FAIL [7]: o próprio lint aprovou um universo vazio — aprovar por não ter olhado é a mesma classe de falha que este lint persegue (saída: '$out')"; exit 1; }
case "$out" in
  *universo-vazio*) : ;;
  *) echo "FAIL [7]: reprovou sem nomear o estado de universo vazio (saída: '$out')"; exit 1 ;;
esac
echo "OK [7]"

echo "[8] o corpus real do harness (template/ + tests/ + bin/) passa no lint"
run_lint --path "$WS/template" --path "$WS/tests" --path "$WS/bin"
[ "$rc" -eq 0 ] || { echo "FAIL [8]: o harness tem ocorrências do padrão perigoso:
$out"; exit 1; }
case "$out" in
  *"arquivo(s) .sh examinado"*) : ;;
  *) echo "FAIL [8]: corpus real passou sem contador de controle (saída: '$out')"; exit 1 ;;
esac
echo "OK [8]"

echo "PASS w159-heredoc-hash-lint"
