#!/usr/bin/env bash
# Gate W10.4 — review roteia por stack, sem assumir .NET e sem especialista fantasma.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$WS/template/.forge"

for agent in dotnet-reviewer node-reviewer java-reviewer python-reviewer; do
  [ -f "$ROOT/agents/code-review/$agent.md" ]
  grep -q "name: $agent" "$ROOT/agents/code-review/$agent.md"
done

E="$ROOT/agents/review/code-evaluator.md"
for agent in dotnet-reviewer node-reviewer java-reviewer python-reviewer; do
  grep -q "\`$agent\`" "$E"
done
grep -q 'cinco reviewers transversais' "$E"
grep -q 'Não acione especialista só porque ele existe' "$E"
bash "$ROOT/scripts/validate-frontmatter.sh" "$ROOT/agents/code-review" | tail -1 | grep -q '^OK'
echo "PASS w104-stack-review-routing-gate"
