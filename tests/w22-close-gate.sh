#!/usr/bin/env bash
# Gate W2.2 — implement/verify/close (deterministic layer):
#   [1] verified flow end-to-end: transitions + verify FAIL on open tasks +
#       verify OK after completion + verification.yaml (zero-dep AND ajv valid)
#   [2] verify refuses to run before implementing
#   [3] close abandoned from tasks-ready → archived/YYYY-MM-DD-<id>, audited
#   [4] close abandoned/rejected from implementing → refused (§10.7 + L3)
#   [5] close superseded from verified → allowed (any-state close)
#   [5b] close delivered-externally from implementing → allowed (positive terminal,
#        any-state, honest status; not 'abandoned'); baseline untouched
#   [6] close touches nothing outside .forge/specs/**
#   [7] compatibility contract (source mode) still green after C2/C4 v1.1
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w22.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
SN="$T/.forge/scripts/spec-new.sh"; TR="$T/.forge/scripts/spec-transition.sh"
AL="$T/.forge/scripts/approval-log.sh"; VS="$T/.forge/scripts/validate-spec.sh"
VF="$T/.forge/scripts/spec-verify.sh"; CL="$T/.forge/scripts/spec-close.sh"

# close touches nothing outside .forge/specs/** EXCEPT the durable ledger (.forge/ledger/**),
# where it harvests open/wont-fix deferrals + findings before moving the change folder
# (non-blocking, by design — see ledger-consultation.md). The ledger is the one sanctioned target.
hash_outside_specs() {
  (cd "$T" && find . -type f ! -path './.forge/specs/*' ! -path './.forge/ledger/*' ! -name '.DS_Store' -print0 | LC_ALL=C sort -z \
    | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1)
}

echo "[1] fluxo até verified"
(cd "$T" && bash "$SN" chg-f --type feature --scale 2 >/dev/null
            bash "$TR" chg-f requirements-ready >/dev/null
            bash "$TR" chg-f design-ready >/dev/null
            bash "$TR" chg-f tasks-ready >/dev/null
            bash "$TR" chg-f implementing >/dev/null)
set +e
(cd "$T" && bash "$VF" chg-f) >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 1 ]   # template tasks.md still has open [ ] entries
perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$T/.forge/specs/active/chg-f/tasks.md"
(cd "$T" && bash "$TR" chg-f implemented >/dev/null)
(cd "$T" && bash "$VF" chg-f >/dev/null)
[ -f "$T/.forge/specs/active/chg-f/verification.yaml" ]
node "$WS/tools/validate-yaml.mjs" "$WS/template/.forge/schemas/verification.schema.json" "$T/.forge/specs/active/chg-f/verification.yaml" >/dev/null
(cd "$T" && bash "$AL" chg-f --gate implementation_verified --decision approve --scope "verification.md" >/dev/null)
# fixture sintético sem delta real: o esqueleto em placeholder bloqueia verified (W100);
# o fluxo documentado para change que não altera o baseline é remover o arquivo (§2.5).
rm -f "$T/.forge/specs/active/chg-f/spec-delta.yaml"
(cd "$T" && bash "$TR" chg-f verified >/dev/null)
(cd "$T" && bash "$VS" chg-f >/dev/null)
echo "OK [1]"

echo "[2] verify recusa estados pré-implementing"
(cd "$T" && bash "$SN" chg-g --type feature --scale 1 >/dev/null && bash "$TR" chg-g requirements-ready >/dev/null && bash "$TR" chg-g tasks-ready >/dev/null)
set +e
(cd "$T" && bash "$VF" chg-g) >/dev/null 2>&1; [ $? -ne 0 ] || { echo "verify aceitou tasks-ready!"; exit 1; }
set -e
echo "OK [2]"

echo "[3] close abandoned de tasks-ready"
H_BEFORE="$(hash_outside_specs)"
(cd "$T" && bash "$CL" chg-g --reason abandoned --note "prioridade mudou no quarter" >/dev/null)
ARCH="$T/.forge/specs/archived/$(date +%F)-chg-g"
[ -d "$ARCH" ] && [ ! -e "$T/.forge/specs/active/chg-g" ]
grep -q '^status: abandoned$' "$ARCH/manifest.yaml"
grep -q '^  kind: closed_without_baseline_update$' "$ARCH/manifest.yaml"
grep -q 'decision: abandon' "$ARCH/approvals.yaml"
grep -q 'prioridade mudou' "$ARCH/approvals.yaml"
echo "OK [3]"

echo "[4] close abandoned/rejected de implementing → recusado"
(cd "$T" && bash "$SN" chg-h --type feature --scale 0 >/dev/null && bash "$TR" chg-h tasks-ready >/dev/null && bash "$TR" chg-h implementing >/dev/null)
for r in abandoned rejected; do
  set +e
  (cd "$T" && bash "$CL" chg-h --reason "$r" --note "tentativa invalida") >/dev/null 2>&1; rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "close aceitou $r de implementing!"; exit 1; }
done
[ -d "$T/.forge/specs/active/chg-h" ]
echo "OK [4]"

echo "[5] close superseded de verified"
(cd "$T" && bash "$CL" chg-f --reason superseded --superseded-by chg-novo --note "redesenho da abordagem" >/dev/null)
[ -d "$T/.forge/specs/archived/$(date +%F)-chg-f" ]
grep -q 'superseded_by: chg-novo' "$T/.forge/specs/archived/$(date +%F)-chg-f/approvals.yaml"
echo "OK [5]"

echo "[5b] close delivered-externally de implementing → permitido (terminal positivo, qualquer estado)"
# chg-h está em implementing (o [4] recusou abandoned/rejected e o deixou ativo).
(cd "$T" && bash "$CL" chg-h --reason delivered-externally --note "entregue e verificado via PR #72; obra feita fora do pipeline" >/dev/null)
ARCH_DE="$T/.forge/specs/archived/$(date +%F)-chg-h"
[ -d "$ARCH_DE" ] && [ ! -e "$T/.forge/specs/active/chg-h" ] || { echo "delivered-externally não arquivou chg-h!"; exit 1; }
grep -q '^status: delivered-externally$' "$ARCH_DE/manifest.yaml" || { echo "status não é delivered-externally!"; exit 1; }
grep -q '^  kind: closed_without_baseline_update$' "$ARCH_DE/manifest.yaml" || { echo "kind errado!"; exit 1; }
grep -q 'decision: deliver-external' "$ARCH_DE/approvals.yaml" || { echo "decisão não registrada!"; exit 1; }
grep -q 'PR #72' "$ARCH_DE/approvals.yaml" || { echo "evidência (nota) não registrada!"; exit 1; }
echo "OK [5b]"

echo "[6] close não tocou nada fora de .forge/specs (exceto o harvest do ledger, .forge/ledger/**)"
[ "$(hash_outside_specs)" = "$H_BEFORE" ]
echo "OK [6]"

echo "[7] contrato source mode"
bats "$WS/tests/snapshot/claude-contract.bats" >/dev/null
echo "OK [7]"

echo "OK"
