#!/usr/bin/env bash
# Gate — o checkout do próprio ci.yml deste repositório precisa de fetch-depth: 0.
# O job "Red-first replay (autoridade do CI)" roda `red-evidence.sh ci`, cuja estratégia de
# derivação de base (ancestry/revert-synthesis/test-graft, ver red-replay.mjs) precisa de
# histórico git completo — sob checkout raso (padrão do actions/checkout@v4), a derivação
# falha com `not-possible` mesmo quando não há defeito real (visto no PR #43, run 31036944513).
# template/github/workflows/red-first.yml (distribuído a projetos consumidores) já exige isso
# e tem gate próprio (tests/w109-red-ci-gate.sh); este gate cobre a mesma exigência para o
# ci.yml deste repositório, que não é gerado a partir do template.
#   [1] ci.yml declara fetch-depth: 0 no step actions/checkout que precede o Red-first replay
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CI="$WS/.github/workflows/ci.yml"

echo "[1] ci.yml declara fetch-depth: 0 no checkout do job que roda o Red-first replay"
[ -f "$CI" ] || { echo "FAIL [1]: $CI ausente"; exit 1; }
grep -q "red-evidence.sh ci" "$CI" || { echo "FAIL [1]: ci.yml não chama red-evidence.sh ci — gate desatualizado ou step removido"; exit 1; }
grep -A3 "actions/checkout@" "$CI" | grep -q "fetch-depth: 0" \
  || { echo "FAIL [1]: fetch-depth: 0 ausente no checkout — replay ancestry/revert-synthesis vira not-possible sob checkout raso"; exit 1; }
echo "OK [1]"

echo "PASS ci-fetch-depth-gate"
