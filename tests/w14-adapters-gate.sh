#!/usr/bin/env bash
# Gate W1.4 — multi-adapter generation on a fresh install:
#   [1] install (sync --adapter all) → every adapter's targets present, 8 lockfiles
#   [2] smoke-adapters.sh → every declared smoke OK + no foreign paths
#   [3] idempotency: sync all twice → byte-identical tree
#   [4] compatibility contract (generated mode) stays green
#   [5] doctor exits 0 with all adapter locks checked
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w14.XXXXXX)"
trap 'rm -rf "$T"' EXIT

tree_hash() {
  (cd "$1" && find . -type f ! -name '.DS_Store' -print0 | LC_ALL=C sort -z \
    | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1)
}

echo "[1] install com todos os adapters"
"$WS/installer/install.sh" --target "$T" --slug fixture-app --name "Fixture App" --desc "Fixture do gate W1.4" >/dev/null
[ -d "$T/.agents/commands/forge" ] && ls "$T"/.agents/commands/forge/*.md >/dev/null
[ "$(find "$T/.agents/skills" -name SKILL.md | wc -l | tr -d ' ')" -eq 4 ]
[ -f "$T/.kiro/steering/forge.md" ] && [ ! -d "$T/.kiro/specs" ]
[ -f "$T/.cursor/rules/forge.mdc" ] && grep -q 'alwaysApply: true' "$T/.cursor/rules/forge.mdc"
[ -L "$T/QWEN.md" ] && [ -L "$T/GEMINI.md" ]
locks="$(find "$T/.forge/adapters" -name '*.lock.yaml' | wc -l | tr -d ' ')"
[ "$locks" -eq 8 ]
echo "OK [1] (8 lockfiles, alvos presentes)"

echo "[2] smokes declarados + foreign paths"
(cd "$T" && bash .forge/scripts/smoke-adapters.sh) | tail -1 | grep -q '^OK$'
echo "OK [2]"

echo "[3] idempotencia (sync all 2x)"
H1="$(tree_hash "$T")"
(cd "$T" && bash .forge/scripts/sync-adapters.sh --adapter all >/dev/null)
H2="$(tree_hash "$T")"
[ "$H1" = "$H2" ]
echo "OK [3] (tree hash estavel: ${H1:0:12})"

echo "[4] contrato (generated mode)"
CLAUDE_CONTRACT_MODE=generated CLAUDE_CONTRACT_TARGET="$T" \
  bats "$WS/tests/snapshot/claude-contract.bats" >/dev/null
echo "OK [4]"

echo "[5] doctor com todos os locks"
(cd "$T" && bash .forge/scripts/doctor.sh --report >/dev/null)
echo "OK [5]"

echo "OK"
