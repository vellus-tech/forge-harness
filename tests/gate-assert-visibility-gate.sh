#!/usr/bin/env bash
# Regressão do gate-assert-visibility (LDG-0012): w80-suite-gate.sh:25 deve reportar
# FAIL [2] explícito quando a fixture brownfield perde billing.ts — não morrer em silêncio.
set -euo pipefail
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FX="$WS/tests/fixtures/brownfield/src/billing.ts"
BAK="$(mktemp)"; cp "$FX" "$BAK"
trap 'cp "$BAK" "$FX"; rm -f "$BAK"' EXIT
echo "[1] w80-suite-gate.sh reporta FAIL [2] explícito com billing.ts ausente"
rm -f "$FX"
set +e
out="$(bash "$WS/tests/w80-suite-gate.sh" 2>&1)"; rc=$?
set -e
cp "$BAK" "$FX"
echo "$out" | grep -qE '^FAIL \[2\]' \
  || { echo "FAIL [1]: w80-suite-gate.sh saiu rc=$rc sem emitir 'FAIL [2]: ...' ao remover billing.ts da fixture ($out)"; exit 1; }
echo "OK [1]"
