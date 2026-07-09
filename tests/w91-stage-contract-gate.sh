#!/usr/bin/env bash
# Gate W9.1 — stage contracts:
#   [1] contratos declarativos existem e validam
#   [2] verify falha sem outputs obrigatórios e passa após evidência
#   [3] archive/eval contracts cobrem estágios críticos
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w91.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"

echo "[1] validate-contracts"
FORGE_ROOT="$T" bash "$S/validate-stage-contract.sh" validate-contracts >/dev/null
for c in verify archive eval skill-lifecycle-eval run-spec-pipeline; do
  [ -f "$T/.forge/contracts/stages/$c.yaml" ]
  grep -q '^stage:' "$T/.forge/contracts/stages/$c.yaml"
done
echo "OK [1]"

echo "[2] verify contract falha sem output e passa com evidência"
DIR="$T/.forge/specs/active/contract-demo"
mkdir -p "$DIR"
cat > "$DIR/manifest.yaml" <<'EOF'
id: contract-demo
type: feature
mode: feature-only
rigor: spec-anchored
scale: 0
status: implemented
created_at: "2026-07-09"
updated_at: "2026-07-09"
owner: Milton
gates:
  requirements_reviewed: false
  design_reviewed: false
  tasks_reviewed: false
  implementation_verified: false
  human_archive_approval: false
EOF
printf -- '- [X] TASK-01 — done\n' > "$DIR/tasks.md"
set +e
out="$(FORGE_ROOT="$T" bash "$S/validate-stage-contract.sh" check --stage verify --change contract-demo 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && echo "$out" | grep -q 'missing output'
printf 'verification:\n  checks: []\n' > "$DIR/verification.yaml"
FORGE_ROOT="$T" bash "$S/run-manifest.sh" write --stage verify --change contract-demo --status passed --outputs verification.yaml >/dev/null
FORGE_ROOT="$T" bash "$S/validate-stage-contract.sh" check --stage verify --change contract-demo >/dev/null
echo "OK [2]"

echo "[3] archive/eval contracts cobrem outputs de evidência"
grep -q 'evidence/runs' "$T/.forge/contracts/stages/archive.yaml"
grep -q 'evidence/runs' "$T/.forge/contracts/stages/eval.yaml"
grep -q 'budget_class: high' "$T/.forge/contracts/stages/eval.yaml"
echo "OK [3]"

echo "OK"
