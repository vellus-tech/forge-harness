#!/usr/bin/env bash
# Gate GW.2 — rules ancoradas em ADR + detecção de drift (G3):
#   [1] template fresco (rules based_on: [] ou ausente) → validate-rules OK
#   [2] rule based_on ADR existente e ACCEPTED → OK (anchored contado)
#   [3] rule based_on ADR INEXISTENTE no baseline → FAIL nomeando a rule
#   [4] rule based_on ADR com status != accepted (proposed) → FAIL (drift)
#   [5] validate-harness integra o check (drift de rule derruba o harness)
#   [6] convenção documentada (rules/README G3) e conflict-handling com based_on
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-gw2.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
VR="$T/.forge/scripts/validate-rules.sh"
ADR="$T/.forge/product/current/adr"
mkdir -p "$ADR"

echo "[1] template fresco → OK (sem rules ancoradas a ADR)"
FORGE_ROOT="$T" bash "$VR" >/dev/null
echo "OK [1]"

echo "[2] rule based_on ADR accepted → OK"
cat > "$ADR/0007-data-isolation.md" <<'EOF'
# 0007. Data isolation strategy
- **Status:** accepted
- **Data:** 2026-06-11
EOF
cat > "$T/.forge/rules/architecture/data-isolation.md" <<'EOF'
---
name: data-isolation
description: Estrategia de isolamento multi-tenant derivada do ADR-0007.
based_on: [ADR-0007]
---
# Data isolation
tenant_id obrigatorio + RLS.
EOF
out="$(FORGE_ROOT="$T" bash "$VR")"
echo "$out" | grep -q '1 anchored'
echo "OK [2]"

echo "[3] based_on ADR inexistente → FAIL nomeando a rule"
cat > "$T/.forge/rules/architecture/ghost.md" <<'EOF'
---
name: ghost
description: Rule ancorada num ADR que nao existe.
based_on: [ADR-0099]
---
# Ghost
EOF
set +e
out="$(FORGE_ROOT="$T" bash "$VR")"; rc=$?
set -e
[ "$rc" -ne 0 ] && echo "$out" | grep -q 'ghost.md' && echo "$out" | grep -q 'ADR-0099'
rm "$T/.forge/rules/architecture/ghost.md"
echo "OK [3]"

echo "[4] based_on ADR proposed (nao accepted) → FAIL drift"
cat > "$ADR/0008-pending.md" <<'EOF'
# 0008. Pending decision
- **Status:** proposed
EOF
cat > "$T/.forge/rules/architecture/premature.md" <<'EOF'
---
name: premature
description: Rule ancorada num ADR ainda proposed.
based_on: [ADR-0008]
---
# Premature
EOF
set +e
out="$(FORGE_ROOT="$T" bash "$VR")"; rc=$?
set -e
[ "$rc" -ne 0 ] && echo "$out" | grep -q 'premature.md' && echo "$out" | grep -qi 'proposed'
rm "$T/.forge/rules/architecture/premature.md"
echo "OK [4]"

echo "[5] validate-harness integra o check"
# instala num repo real p/ ter harness valido, depois planta drift
H="$(mktemp -d /tmp/forge-gw2h.XXXXXX)"
"$WS/installer/install.sh" --target "$H" --slug gw2 --name "GW2" --desc "gate gw2" >/dev/null
FORGE_ROOT="$H" bash "$H/.forge/scripts/validate-harness.sh" >/dev/null
cat > "$H/.forge/rules/conventions/bad-anchor.md" <<'EOF'
---
name: bad-anchor
description: Rule com based_on quebrado para testar o harness.
based_on: [ADR-1234]
---
# Bad
EOF
set +e
FORGE_ROOT="$H" bash "$H/.forge/scripts/validate-harness.sh" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -ne 0 ]
rm -rf "$H"
echo "OK [5]"

echo "[6] convenção documentada"
grep -q 'based_on' "$T/.forge/rules/README.md"
grep -q 'guardrail G3\|G3' "$T/.forge/rules/README.md"
grep -q '^based_on:' "$T/.forge/rules/conventions/conflict-handling.md"
echo "OK [6]"

echo "OK"
