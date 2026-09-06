#!/usr/bin/env bash
# Gate W146 — prova de INVOCAÇÃO, não de existência (issue #49, instância 2).
#
# `grep -rn "run-all.sh" .github .forge/hooks .forge/FORGE.md` devolvia vazio no
# axis-device-platform: nada invocava a rede. Doze suítes de guarda, entregues ao longo de dez
# rodadas, só executavam por invocação manual — e apareciam como cobertura em todos os relatórios.
# O alvo morto clássico não pega isso: ele mede o gate RODANDO, não o gate sendo CHAMADO.
#
#   [1] suíte presente e não invocada por ponto de entrada algum REPROVA, nomeando o runner
#   [2] suíte invocada por um workflow do CI passa, com contador de pontos de entrada
#   [3] diretório de suítes presente SEM runner REPROVA — a existência do diretório torna a
#       ausência do runner um erro (padrão que o consumidor axis-fare-validator já aplicava)
#   [4] AUTO-IRONIA: zero pontos de entrada examinados REPROVA (universo vazio)
#   [5] o pre-push do TEMPLATE invoca a rede de suítes do harness e trata alvo ausente como erro
#   [6] ESTE repositório passa: tests/run-all.sh é de fato invocado pelos pontos de entrada
#   [7] os gates de w144–w147 e da leva w190–w198 estão dentro da rede que run-all.sh executa
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$WS/template/.forge/scripts/check-suite-wiring.sh"

T="$(mktemp -d /tmp/forge-w146.XXXXXX)"
trap 'rm -rf "$T"' EXIT

[ -f "$CHECK" ] || { echo "FAIL [0]: $CHECK não existe — a prova de invocação não foi entregue"; exit 1; }

run_check() { out="$(bash "$CHECK" --root "$1" 2>&1)"; rc=$?; }

mkrepo() { # mkrepo <dir> — repo com ponto de entrada de CI e uma rede de suítes
  mkdir -p "$1/.github/workflows" "$1/tests" "$1/.forge"
  printf '#!/usr/bin/env bash\necho suite\n' > "$1/tests/run-all.sh"
  printf '#!/usr/bin/env bash\necho gate\n' > "$1/tests/w01-exemplo-gate.sh"
  printf -- '---\nforge_version: 1\n---\n\n# FORGE\n' > "$1/.forge/FORGE.md"
}

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] suíte presente e NÃO invocada por ponto de entrada algum REPROVA"
R1="$T/r1"; mkrepo "$R1"
printf 'name: ci\njobs:\n  build:\n    steps:\n      - run: echo nada\n' > "$R1/.github/workflows/ci.yml"
run_check "$R1"
[ "$rc" -ne 0 ] || { echo "FAIL [1]: aprovou uma rede de suítes que ninguém invoca (saída: '$out')"; exit 1; }
case "$out" in
  *"run-all.sh"*) : ;;
  *) echo "FAIL [1]: reprovou sem nomear o runner não invocado (saída: '$out')"; exit 1 ;;
esac
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] suíte invocada por um workflow do CI passa, com contador de pontos de entrada"
printf 'name: ci\njobs:\n  build:\n    steps:\n      - run: bash tests/run-all.sh\n' > "$R1/.github/workflows/ci.yml"
run_check "$R1"
[ "$rc" -eq 0 ] || { echo "FAIL [2]: reprovou com a suíte fiada no CI (saída: '$out')"; exit 1; }
case "$out" in
  *"examinado(s)"*) : ;;
  *) echo "FAIL [2]: passou sem contador de pontos de entrada examinados (saída: '$out')"; exit 1 ;;
esac
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] diretório de suítes presente SEM runner REPROVA"
rm -f "$R1/tests/run-all.sh"
run_check "$R1"
[ "$rc" -ne 0 ] || { echo "FAIL [3]: diretório de suítes sem runner passou como no-op (saída: '$out')"; exit 1; }
printf '#!/usr/bin/env bash\necho suite\n' > "$R1/tests/run-all.sh"
echo "OK [3]"

# ── [4] AUTO-IRONIA ──────────────────────────────────────────────────────────────────────────
echo "[4] zero pontos de entrada examinados REPROVA (universo vazio)"
R4="$T/r4"; mkdir -p "$R4/tests"
printf '#!/usr/bin/env bash\necho suite\n' > "$R4/tests/run-all.sh"
run_check "$R4"
[ "$rc" -ne 0 ] || { echo "FAIL [4]: o próprio gate de invocação aprovou sem examinar ponto de entrada algum (saída: '$out')"; exit 1; }
case "$out" in
  *universo-vazio*) : ;;
  *) echo "FAIL [4]: reprovou sem nomear o estado de universo vazio (saída: '$out')"; exit 1 ;;
esac
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] o pre-push do TEMPLATE invoca a rede de suítes e trata alvo ausente como erro"
R5="$T/r5"; mkdir -p "$R5"
cp -R "$WS/template/.forge" "$R5/.forge"
git -C "$R5" init -q -b main
git -C "$R5" config user.email t@t; git -C "$R5" config user.name t; git -C "$R5" config commit.gpgsign false
git -C "$R5" add -A >/dev/null 2>&1
git -C "$R5" commit -qm "chore: init" >/dev/null 2>&1
SHA5="$(git -C "$R5" rev-parse HEAD)"
FEED5="refs/heads/main $SHA5 refs/heads/main 0000000000000000000000000000000000000000"

# (a) diretório de suítes presente e runner ausente → o hook BLOQUEIA
mkdir -p "$R5/.forge/scripts/tests"
printf '#!/usr/bin/env bash\necho gate\n' > "$R5/.forge/scripts/tests/w01-x-gate.sh"
# O `rm` é obrigatório desde a issue #73: o template passou a ENTREGAR o runner, então a condição
# que este cenário mede — diretório presente, runner ausente — deixou de se montar sozinha ao
# copiar o template. Sem remover, o fixture testava o estado bom e aprovava sem medir.
# A asserção segue valendo: é a proteção da issue #49, e a #73 corrigiu a outra ponta (o template
# não entregar o arquivo que o próprio hook exige) sem revogar a exigência.
rm -f "$R5/.forge/scripts/tests/run-all.sh"
out="$(cd "$R5" && printf '%s\n' "$FEED5" | bash .forge/hooks/git/pre-push origin "file://$R5" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [5a]: pre-push passou com .forge/scripts/tests/ presente e run-all.sh ausente (saída: '$out')"; exit 1; }
case "$out" in
  *run-all.sh*) : ;;
  *) echo "FAIL [5a]: bloqueou sem nomear o runner ausente (saída: '$out')"; exit 1 ;;
esac

# (b) runner presente → o hook INVOCA (e a falha do runner reprova o push)
printf '#!/usr/bin/env bash\necho "MARCA-SUITE-INVOCADA"\nexit 1\n' > "$R5/.forge/scripts/tests/run-all.sh"
out="$(cd "$R5" && printf '%s\n' "$FEED5" | bash .forge/hooks/git/pre-push origin "file://$R5" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [5b]: pre-push passou com a suíte do harness reprovando (saída: '$out')"; exit 1; }
case "$out" in
  *MARCA-SUITE-INVOCADA*) : ;;
  *) echo "FAIL [5b]: o pre-push NÃO invocou .forge/scripts/tests/run-all.sh (saída: '$out')"; exit 1 ;;
esac
echo "OK [5]"

# ── [6] ──────────────────────────────────────────────────────────────────────────────────────
echo "[6] ESTE repositório passa: tests/run-all.sh é de fato invocado pelos pontos de entrada"
run_check "$WS"
[ "$rc" -eq 0 ] || { echo "FAIL [6]: a rede de suítes deste repositório não está fiada:
$out"; exit 1; }
echo "OK [6]"

# ── [7] ──────────────────────────────────────────────────────────────────────────────────────
echo "[7] os gates de w144–w147 e da leva w190–w198 estão na rede que tests/run-all.sh executa"
listed="$(bash "$WS/tests/run-all.sh" --list 2>&1)"
# A faixa w190+ é enumerada POR DESCOBERTA, não por lista fixa: uma lista escrita à mão envelhece
# no commit seguinte ao próprio (a versão anterior deste cenário fixava quatro nomes). O que se
# cobra é a propriedade — todo tests/w19*-*-gate.sh em disco aparece no --list.
# DOIS contadores, não um: um só era satisfeito pelos quatro nomes fixos de w144-w147 mesmo se o
# glob da faixa nova não casasse arquivo nenhum — o contador de controle aprovaria em silêncio
# exatamente o universo que ele existe para vigiar.
_wired=0; _wired_faixa=0
for f in "$WS"/tests/w19[0-9]-*-gate.sh; do
  [ -f "$f" ] || continue
  g="$(basename "$f" .sh)"
  _wired_faixa=$((_wired_faixa + 1))
  case "$listed" in
    *"$g"*) _wired=$((_wired + 1)) ;;
    *) echo "FAIL [7]: $g.sh existe mas não é executado por tests/run-all.sh — guarda que ninguém roda não cobre nada"; exit 1 ;;
  esac
done
for g in w144-gate-control-counter-gate w145-shell-pipeline-lint-gate w146-suite-invocation-gate w147-hook-delegation-gate; do
  case "$listed" in
    *"$g"*) _wired=$((_wired + 1)) ;;
    *) echo "FAIL [7]: $g.sh existe mas não é executado por tests/run-all.sh — guarda que ninguém roda não cobre nada"; exit 1 ;;
  esac
done
# Contador de controle, com os dois universos declarados separadamente.
[ "$_wired_faixa" -gt 0 ] \
  || { echo "FAIL [7]: o glob tests/w19[0-9]-*-gate.sh não casou NENHUM arquivo — a faixa desta leva não está sendo examinada, e os quatro nomes fixos de w144-w147 satisfariam o contador sozinhos"; exit 1; }
[ "$_wired" -ge $((_wired_faixa + 4)) ] \
  || { echo "FAIL [7]: $_wired confirmado(s) para $_wired_faixa da faixa + 4 fixos"; exit 1; }
echo "OK [7] — $_wired gate(s) verificados na rede do run-all.sh ($_wired_faixa da faixa w19*, 4 fixos)"

echo "PASS w146-suite-invocation"
