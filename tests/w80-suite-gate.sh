#!/usr/bin/env bash
# Gate W8.0 — fixtures finais e suíte consolidada:
#   [1] fixtures greenfield/feature-only/brownfield existem com a forma esperada
#   [2] brownfield é um mini-repo TS real (package.json + src + docs/product legado + contrato)
#   [3] run-all.sh existe, é executável e --list enumera todos os *-gate.sh + bats
#   [4] run-all.sh NÃO se inclui na execução nem chama a si mesmo (sem recursão)
#   [5] este gate (w80) está na lista do run-all mas não invoca run-all (sem recursão)
#   [6] casos obrigatórios da §22.9/#20 têm gate cobrindo (mapa explícito)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1] fixtures com a forma esperada"
for fx in greenfield feature-only brownfield; do
  [ -d "$WS/tests/fixtures/$fx" ]
  [ -f "$WS/tests/fixtures/$fx/README.md" ]
done
echo "OK [1]"

echo "[2] brownfield mini-repo TS real"
B="$WS/tests/fixtures/brownfield"
[ -f "$B/package.json" ]
grep -q '"name"' "$B/package.json"
[ -f "$B/tsconfig.json" ]
[ -f "$B/src/money.ts" ] && [ -f "$B/src/billing.ts" ]
[ -f "$B/docs/product/modules/billing/requirements.md" ]
grep -qi 'LEGADO' "$B/docs/product/modules/billing/requirements.md"
[ -f "$B/contracts/billing.contract.md" ]
# o bug proposital está marcado (caso do piloto W8.2)
grep -qi 'BUG PROPOSITAL' "$B/src/billing.ts"
echo "OK [2]"

echo "[3] run-all.sh existe, executável, --list completo"
RA="$WS/tests/run-all.sh"
[ -f "$RA" ] && [ -x "$RA" ]
listing="$(bash "$RA" --list)"
# todo *-gate.sh aparece na listagem
for g in "$WS"/tests/*-gate.sh; do
  base="$(basename "$g")"
  grep -q "$base" <<<"$listing" || { echo "FAIL [3]: gate $base não aparece no --list do run-all"; exit 1; }
done
# bats suites listadas
grep -q 'validators.bats' <<<"$listing" || { echo "FAIL [3]: validators.bats não aparece no --list"; exit 1; }
grep -q 'claude-contract.bats' <<<"$listing" || { echo "FAIL [3]: claude-contract.bats não aparece no --list"; exit 1; }
echo "OK [3]"

echo "[4] run-all não chama a si mesmo (sem recursão)"
! grep -E 'run-all\.sh|run-all ' "$RA" | grep -vE '^\s*#|run-all\.sh —|run-all\)|name=|Uso:|tests/run-all\.sh ' >/dev/null
# garantia direta: não há invocação bash/exec de run-all dentro de run-all
! grep -E '(bash|sh|exec).*run-all' "$RA" >/dev/null
echo "OK [4]"

echo "[5] w80 não invoca run-all (sem recursão pelo próprio gate)"
! grep -E '(bash|sh|exec).*run-all' "$WS/tests/w80-suite-gate.sh" >/dev/null
echo "OK [5]"

echo "[6] casos obrigatórios §22.9/#20 cobertos por gate"
# mapa caso -> gate que o exercita
declare -a MAP=(
  "init sem repo git:w13-init-gate.sh"
  "init repo existente:w13-init-gate.sh"
  "symlink/fallback copy:w14-adapters-gate.sh"
  "archive tasks incompletas:w32-archive-gate.sh"
  "archive aplica deltas:w32-archive-gate.sh"
  "sync-adapters + drift:w14-adapters-gate.sh"
  "close abandoned/rejected/superseded:w22-close-gate.sh"
  "shard:w50-story-shard-gate.sh"
  "eval smoke estrutural:w52-eval-harness-gate.sh"
  "smoke de todos adapters:w14-adapters-gate.sh"
  "run manifest:w90-run-manifest-gate.sh"
  "stage contracts:w91-stage-contract-gate.sh"
  "benchmark registry:w92-benchmark-registry-gate.sh"
  "profiles budget:w93-profiles-budget-gate.sh"
)
for entry in "${MAP[@]}"; do
  gate="${entry##*:}"
  [ -f "$WS/tests/$gate" ] || { echo "FALTA gate para '${entry%%:*}': $gate"; exit 1; }
done
echo "OK [6]"

echo "[7] a suíte desliga a manutenção automática do git em todo fixture"
# `git commit` dispara `git gc --auto` em BACKGROUND. Onze gates criam repositório git em /tmp; se
# o fixture é removido logo após o último commit, o gc ainda escreve em `.git` e o `rm -rf` falha
# com "Directory not empty" — sob `set -e`, o gate morre DEPOIS de passar em todas as asserções.
# Não reproduz no macOS, reproduz no CI Linux: foi assim que o w106 reprovou no CI com o log
# inteiro verde. A asserção mora aqui, e não em cada gate, porque o modo de falha é justamente o
# esquecimento — um gate novo herda a proteção sem o autor precisar saber que ela existe.
for k in gc.auto maintenance.auto; do
  grep -qE "GIT_CONFIG_KEY_[0-9]+=$k\b" "$WS/tests/run-all.sh" \
    || { echo "FAIL [7]: run-all.sh não desliga $k — fixture git pode ser removido sob gc em background"; exit 1; }
done
grep -qE '^export GIT_CONFIG_COUNT=[0-9]+' "$WS/tests/run-all.sh" \
  || { echo "FAIL [7]: GIT_CONFIG_COUNT ausente — as chaves GIT_CONFIG_KEY_* são ignoradas pelo git sem ele"; exit 1; }
# o contador tem de cobrir todas as chaves declaradas, senão o git ignora as excedentes EM SILÊNCIO
declared="$(grep -cE 'GIT_CONFIG_KEY_[0-9]+=' "$WS/tests/run-all.sh")"
count="$(grep -oE '^export GIT_CONFIG_COUNT=[0-9]+' "$WS/tests/run-all.sh" | grep -oE '[0-9]+')"
[ "$count" = "$declared" ] \
  || { echo "FAIL [7]: GIT_CONFIG_COUNT=$count mas há $declared chave(s) declarada(s) — o git ignora as excedentes sem avisar"; exit 1; }
# e a config precisa CHEGAR ao git de verdade, não só estar escrita no arquivo
probe="$(cd "$WS" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=gc.auto GIT_CONFIG_VALUE_0=0 git config --get gc.auto)"
[ "$probe" = "0" ] || { echo "FAIL [7]: git não respeita GIT_CONFIG_COUNT neste ambiente (leu '$probe')"; exit 1; }
echo "OK [7]"

echo "OK"
