#!/usr/bin/env bash
# Gate W2.1 — state machine + HITL approvals (deterministic layer):
#   [1] scale-2 chain: valid transitions advance; skipping is refused
#   [2] scale-0/1 chains: phases not required by scale are legally skipped
#   [3] blocked round-trip requires --reason both ways
#   [4] terminal states are refused by spec-transition (close/archive own them)
#   [5] approval-log: approve flips manifest gate; non-approve requires reason;
#       iteration capped at 3; supersede requires successor
#   [6] approvals.yaml: zero-dep validator AND ajv (schema parity) accept it
#   [7] corrupted approvals entry → validate-spec FAIL naming the field
# The semantic half of W2.1 (builder→validator loop quality) is validated in
# the manual pilot — this gate covers everything deterministic around it.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w21.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
SN="$T/.forge/scripts/spec-new.sh"; TR="$T/.forge/scripts/spec-transition.sh"
AL="$T/.forge/scripts/approval-log.sh"; VS="$T/.forge/scripts/validate-spec.sh"

echo "[1] cadeia scale 2"
(cd "$T" && bash "$SN" chg-a --type feature --scale 2 >/dev/null)
(cd "$T" && bash "$TR" chg-a requirements-ready >/dev/null)
(cd "$T" && bash "$TR" chg-a design-ready >/dev/null)
(cd "$T" && bash "$TR" chg-a tasks-ready >/dev/null)
set +e
(cd "$T" && bash "$TR" chg-a verified) >/dev/null 2>&1; [ $? -ne 0 ] || { echo "pulo aceito!"; exit 1; }
set -e
grep -q '^status: tasks-ready$' "$T/.forge/specs/active/chg-a/manifest.yaml"
echo "OK [1]"

echo "[2] pulos legais por scale"
(cd "$T" && bash "$SN" chg-z --type feature --scale 0 >/dev/null && bash "$TR" chg-z tasks-ready >/dev/null)
(cd "$T" && bash "$SN" chg-o --type feature --scale 1 >/dev/null && bash "$TR" chg-o requirements-ready >/dev/null && bash "$TR" chg-o tasks-ready >/dev/null)
set +e
(cd "$T" && bash "$SN" chg-w --type feature --scale 2 >/dev/null && bash "$TR" chg-w tasks-ready) >/dev/null 2>&1
[ $? -ne 0 ] || { echo "scale 2 pulou requirements!"; exit 1; }
set -e
echo "OK [2]"

echo "[3] blocked exige reason (ida e volta)"
set +e
(cd "$T" && bash "$TR" chg-a blocked) >/dev/null 2>&1; [ $? -ne 0 ] || exit 1
set -e
(cd "$T" && bash "$TR" chg-a blocked --reason "aguardando decisao de produto" >/dev/null)
set +e
(cd "$T" && bash "$TR" chg-a tasks-ready) >/dev/null 2>&1; [ $? -ne 0 ] || exit 1
set -e
(cd "$T" && bash "$TR" chg-a tasks-ready --reason "decisao tomada" >/dev/null)
echo "OK [3]"

echo "[4] estados terminais recusados pelo transition"
for s in abandoned rejected superseded archived; do
  set +e
  (cd "$T" && bash "$TR" chg-a "$s") >/dev/null 2>&1; rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "transition aceitou $s!"; exit 1; }
done
echo "OK [4]"

echo "[5] approval-log: regras §12.1"
set +e
(cd "$T" && bash "$AL" chg-a --gate requirements_reviewed --decision reject) >/dev/null 2>&1; [ $? -eq 2 ] || exit 1
(cd "$T" && bash "$AL" chg-a --gate requirements_reviewed --decision review --reason "ajustar REQ-02" --iteration 4) >/dev/null 2>&1; [ $? -eq 2 ] || exit 1
(cd "$T" && bash "$AL" chg-a --gate close --decision supersede --reason "substituida") >/dev/null 2>&1; [ $? -eq 2 ] || exit 1
set -e
(cd "$T" && bash "$AL" chg-a --gate requirements_reviewed --decision review --reason "ajustar REQ-02" --iteration 2 >/dev/null)
(cd "$T" && bash "$AL" chg-a --gate requirements_reviewed --decision approve --iteration 3 --scope "requirements.md" >/dev/null)
grep -q '^  requirements_reviewed: true$' "$T/.forge/specs/active/chg-a/manifest.yaml"
[ "$(grep -c '^  - gate: ' "$T/.forge/specs/active/chg-a/approvals.yaml")" -eq 2 ]
echo "OK [5]"

echo "[6] approvals: paridade zero-dep + ajv"
(cd "$T" && bash "$VS" chg-a >/dev/null)
node "$WS/tools/validate-yaml.mjs" "$WS/template/.forge/schemas/approvals.schema.json" "$T/.forge/specs/active/chg-a/approvals.yaml" >/dev/null
echo "OK [6]"

echo "[7] approvals corrompido → FAIL nomeando o campo"
cp "$T/.forge/specs/active/chg-a/approvals.yaml" "$T/ap.bak"
perl -pi -e 's/decision: review/decision: maybe/' "$T/.forge/specs/active/chg-a/approvals.yaml"
set +e
out="$(cd "$T" && bash "$VS" chg-a)"; rc=$?
set -e
[ "$rc" -eq 1 ] && echo "$out" | grep -q 'decision invalid'
mv "$T/ap.bak" "$T/.forge/specs/active/chg-a/approvals.yaml"
echo "OK [7]"

echo "OK"
