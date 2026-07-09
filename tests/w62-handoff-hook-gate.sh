#!/usr/bin/env bash
# Gate W4.2 — handoff SessionStart/SessionEnd hooks (opt-in via forge.yaml handoff.auto):
#   [1] default install → handoff.auto: false; .claude/settings.json has exactly 1 "command":
#       entry (worktree-guard only), no SessionStart/SessionEnd (C5 regression guard)
#   [2] flip handoff.auto: true + re-sync claude adapter → settings.json gains SessionStart +
#       SessionEnd hooks pointing at the session scripts; 3 "command": entries total
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w42.XXXXXX)"
trap 'rm -rf "$T"' EXIT

sync() { (cd "$T" && bash .forge/scripts/sync-adapters.sh "$@" >/dev/null); }

echo "[1] install default (claude only) — handoff.auto: false"
"$WS/installer/install.sh" --target "$T" --slug fixture-app --name "Fixture App" --desc "Gate W4.2" >/dev/null

grep -q '^handoff:' "$T/.forge/forge.yaml"
grep -q 'auto: false' "$T/.forge/forge.yaml"

SETTINGS="$T/.claude/settings.json"
[ -f "$SETTINGS" ]
python3 -m json.tool "$SETTINGS" >/dev/null

COUNT1="$(grep -o '"command":' "$SETTINGS" | wc -l | tr -d ' ')"
[ "$COUNT1" -eq 1 ]
grep -q 'enforce-worktree-location.sh' "$SETTINGS"
! grep -q 'SessionStart' "$SETTINGS"
! grep -q 'SessionEnd' "$SETTINGS"
echo "OK [1]"

echo "[2] flip handoff.auto: true + re-sync claude adapter"
sed -i.bak 's/auto: false/auto: true/' "$T/.forge/forge.yaml"
rm -f "$T/.forge/forge.yaml.bak"
grep -q 'auto: true' "$T/.forge/forge.yaml"

sync --adapter claude

python3 -m json.tool "$SETTINGS" >/dev/null

grep -q '"SessionStart"' "$SETTINGS"
grep -q '"SessionEnd"' "$SETTINGS"
grep -q 'on-session-start.sh' "$SETTINGS"
grep -q 'on-session-end.sh' "$SETTINGS"

COUNT2="$(grep -o '"command":' "$SETTINGS" | wc -l | tr -d ' ')"
[ "$COUNT2" -eq 3 ]
echo "OK [2]"

echo "OK"
