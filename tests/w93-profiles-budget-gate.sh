#!/usr/bin/env bash
# Gate W9.3 — execution profiles + budget preflight:
#   [1] default é standard
#   [2] forge.yaml define profile quando não há change
#   [3] manifest.yaml vence forge.yaml para change
#   [4] flag --profile vence manifest/forge
#   [5] --set aplica overrides pontuais
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w93.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"

echo "[1] default standard"
out="$(FORGE_ROOT="$T" bash "$S/budget-preflight.sh" --stage eval)"
grep -q 'profile=standard' <<<"$out"
echo "OK [1]"

echo "[2] forge.yaml profile"
printf 'execution_profile: quick\n' > "$T/.forge/forge.yaml"
out="$(FORGE_ROOT="$T" bash "$S/budget-preflight.sh" --stage eval)"
grep -q 'profile=quick' <<<"$out"
echo "OK [2]"

echo "[3] manifest profile vence forge.yaml"
DIR="$T/.forge/specs/active/profile-demo"
mkdir -p "$DIR"
cat > "$DIR/manifest.yaml" <<'EOF'
id: profile-demo
execution_profile: regulated
EOF
out="$(FORGE_ROOT="$T" bash "$S/budget-preflight.sh" --stage verify --change profile-demo)"
grep -q 'profile=regulated' <<<"$out"
grep -q 'runs=3' <<<"$out"
echo "OK [3]"

echo "[4] flag --profile vence manifest"
out="$(FORGE_ROOT="$T" bash "$S/budget-preflight.sh" --stage verify --change profile-demo --profile brownfield-heavy)"
grep -q 'profile=brownfield-heavy' <<<"$out"
echo "OK [4]"

echo "[5] --set aplica runs/runner"
out="$(FORGE_ROOT="$T" bash "$S/budget-preflight.sh" --stage eval --profile quick --set runs=4 --set runner=stub --outputs aggregate.json)"
grep -q 'runner=stub' <<<"$out"
grep -q 'runs=4' <<<"$out"
grep -q 'timeout_s=480' <<<"$out"
grep -q 'outputs=1' <<<"$out"
echo "OK [5]"

echo "OK"
