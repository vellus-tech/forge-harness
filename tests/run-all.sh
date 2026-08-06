#!/usr/bin/env bash
# run-all.sh — suíte consolidada do harness Forge (Fase 8, W8.0).
# Roda, em ordem determinista, todos os gates *-gate.sh + as suítes bats
# (validators.bats e o contrato Claude em source mode). Saída agregada com contagem.
# Gate da W8.0: esta suíte 100% verde.
#
# Uso:
#   tests/run-all.sh            # roda tudo; exit 0 só se 100% verde
#   tests/run-all.sh --list     # apenas lista o que seria executado, em ordem
#   tests/run-all.sh -v         # ecoa a saída de cada gate (default: só PASS/FAIL + tail no erro)
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS"

VERBOSE=0
LIST=0
for a in "$@"; do
  case "$a" in
    -v|--verbose) VERBOSE=1 ;;
    --list) LIST=1 ;;
    *) echo "arg desconhecido: $a" >&2; exit 2 ;;
  esac
done

# Desliga a manutenção automática do git em TODO fixture da suíte.
#
# `git commit` dispara `git gc --auto` em BACKGROUND. Onze gates criam repositório git em /tmp, e
# quando o fixture é removido logo depois do último commit, o gc ainda está escrevendo em `.git` —
# o `rm -rf` então falha com "Directory not empty", e sob `set -e` o gate morre DEPOIS de ter
# passado nas suas asserções. Não reproduz no macOS (APFS + timing), reproduz no CI Linux
# (overlayfs). Foi o que reprovou o w106 no CI com todas as asserções verdes no log.
#
# Via GIT_CONFIG_COUNT em vez de `git config` por fixture: uma única declaração cobre os onze
# gates e qualquer gate futuro, sem depender de cada autor lembrar. É também a razão de estar
# AQUI e não em cada gate — o esquecimento é a falha que se quer eliminar.
export GIT_CONFIG_COUNT=3
export GIT_CONFIG_KEY_0=gc.auto           GIT_CONFIG_VALUE_0=0
export GIT_CONFIG_KEY_1=maintenance.auto  GIT_CONFIG_VALUE_1=0
export GIT_CONFIG_KEY_2=gc.autoDetach     GIT_CONFIG_VALUE_2=false

# Ordem: guardrails (gw*) primeiro, depois waves (w*) em ordem numérica natural.
# `run-all.sh` se exclui; o w80 (gate da própria suíte) NÃO chama run-all (sem recursão).
# Build do array sem mapfile (portável p/ bash 3.2 do macOS).
GATES=()
while IFS= read -r _g; do
  [ -n "$_g" ] && GATES+=("$_g")
done < <(ls tests/*-gate.sh 2>/dev/null | LC_ALL=C sort)

# Suítes bats: contrato em source mode + validadores. O contrato em generated mode é
# exercitado dentro de w14-adapters-gate.sh (precisa de um alvo instalado).
BATS_SUITES=()
[ -f tests/validators.bats ] && BATS_SUITES+=("tests/validators.bats")
[ -f tests/snapshot/claude-contract.bats ] && BATS_SUITES+=("tests/snapshot/claude-contract.bats")

if [ "$LIST" -eq 1 ]; then
  echo "# gates (${#GATES[@]}):"
  printf '  %s\n' "${GATES[@]}"
  echo "# bats (${#BATS_SUITES[@]}):"
  printf '  %s\n' "${BATS_SUITES[@]}"
  exit 0
fi

have_bats=1
command -v bats >/dev/null 2>&1 || have_bats=0

pass=0; fail=0; skip=0
failed_names=()
start_epoch="$(date +%s 2>/dev/null || echo 0)"

run_one() {
  local name="$1"; shift
  local log; log="$(mktemp)"
  if "$@" >"$log" 2>&1; then
    pass=$((pass + 1))
    printf '  \033[32m✓\033[0m %s\n' "$name"
    [ "$VERBOSE" -eq 1 ] && sed 's/^/      /' "$log"
  else
    fail=$((fail + 1)); failed_names+=("$name")
    printf '  \033[31m✗\033[0m %s\n' "$name"
    sed 's/^/      /' "$log" | tail -8
  fi
  rm -f "$log"
}

echo "== Forge — suíte consolidada (run-all) =="
echo "-- gates deterministas (${#GATES[@]}) --"
for g in "${GATES[@]}"; do
  run_one "$(basename "$g")" bash "$g"
done

echo "-- suítes bats (${#BATS_SUITES[@]}) --"
if [ "$have_bats" -eq 0 ]; then
  skip=$((skip + ${#BATS_SUITES[@]}))
  printf '  \033[33m○\033[0m bats indisponível — %d suíte(s) puladas\n' "${#BATS_SUITES[@]}"
else
  for b in "${BATS_SUITES[@]}"; do
    run_one "$(basename "$b")" bats "$b"
  done
fi

end_epoch="$(date +%s 2>/dev/null || echo 0)"
elapsed=$((end_epoch - start_epoch))

echo
echo "== Resultado =="
echo "PASS=$pass  FAIL=$fail  SKIP=$skip  (${elapsed}s)"
if [ "$fail" -ne 0 ]; then
  printf 'FALHARAM:\n'; printf '  - %s\n' "${failed_names[@]}"
  exit 1
fi
echo "OK — suíte 100% verde"
