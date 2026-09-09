#!/usr/bin/env bash
# Regressão do gate-assert-visibility (LDG-0012): w80-suite-gate.sh:25 deve reportar
# FAIL [2] explícito quando a fixture brownfield perde billing.ts — não morrer em silêncio.
#
# Conversão do LDG-0179: este gate mutava a fixture RASTREADA `tests/fixtures/brownfield/src/
# billing.ts` — apagava o arquivo real e restaurava de uma cópia no trap. Medido, sob `SIGKILL` o
# arquivo simplesmente sumia da árvore de trabalho (` D`), porque nenhum trap roda. Agora o gate
# copia `tests/` inteiro para a bancada em `$T`, confere a cópia da fixture byte a byte com o
# original e roda o w80 A PARTIR DA CÓPIA: o sistema sob teste resolve a fixture por caminho
# relativo ao seu próprio `BASH_SOURCE`, então mover o w80 para a bancada move a fixture junto.
# Sem mutação do rastreado não há janela, não há restauração e não há sinal que corrompa.
#
# O que se mede continua sendo a propriedade do CÓDIGO do w80, não a do inode: a cópia é conferida
# com `cmp -s` contra o original no instante anterior ao uso, e o gate aborta se divergir.
set -euo pipefail
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/arvore-rastreada.sh"

T="$(mktemp -d "${TMPDIR:-/tmp}/forge-gav.XXXXXX")"
trap 'rm -rf "$T"' EXIT
ANTES="$(arvore_retrato "$WS")"

FX_REAL="$WS/tests/fixtures/brownfield/src/billing.ts"
[ -f "$FX_REAL" ] || { echo "NÃO VERIFICADO: fixture original ausente em $FX_REAL"; exit 3; }
mkdir -p "$T/root"
cp -R "$WS/tests" "$T/root/tests"
FXC="$T/root/tests/fixtures/brownfield/src/billing.ts"
W80C="$T/root/tests/w80-suite-gate.sh"
cmp -s "$FX_REAL" "$FXC" \
  || { echo "NÃO VERIFICADO: a cópia da fixture em \$T não bate byte a byte com a original"; exit 3; }
[ -f "$W80C" ] || { echo "NÃO VERIFICADO: o w80 não veio na cópia de tests/"; exit 3; }

echo "[1] w80-suite-gate.sh reporta FAIL [2] explícito com billing.ts ausente"
set +e
out0="$(bash "$W80C" 2>&1)"; rc0=$?
set -e
[ "$rc0" -eq 0 ] \
  || { echo "FAIL [1] controle: o w80 deveria passar sobre a cópia íntegra — rc=$rc0 ($out0)"; exit 1; }

rm -f "$FXC"
set +e
out="$(bash "$W80C" 2>&1)"; rc=$?
set -e
printf '%s\n' "$out" | grep -qE '^FAIL \[2\]' \
  || { echo "FAIL [1]: w80-suite-gate.sh saiu rc=$rc sem emitir 'FAIL [2]: ...' ao remover billing.ts da fixture ($out)"; exit 1; }

cp "$FX_REAL" "$FXC"
set +e
out2="$(bash "$W80C" 2>&1)"; rc2=$?
set -e
[ "$rc2" -eq 0 ] \
  || { echo "FAIL [1] recontrole: restaurada a fixture na cópia, o w80 deveria voltar a passar — rc=$rc2 ($out2)"; exit 1; }
echo "OK [1] — controle, mutação e recontrole, sempre sobre a cópia em \$T"

# Fecho da sentinela pelos TRÊS estados: rc 0 limpo, rc 1 acusação, rc 3 NÃO VERIFICADO. O idioma
# anterior (`arvore_confere ... || { echo "a árvore mudou"; exit 1; }`) colapsava rc 1 e rc 3 no mesmo
# `||` e imprimia, em árvore sem `.git`, a acusação FALSA de que a árvore rastreada mudou.
arvore_sentinela_fim "$WS" "$ANTES" "gate-assert-visibility" || exit $?
