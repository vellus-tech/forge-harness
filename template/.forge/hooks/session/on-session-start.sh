#!/usr/bin/env bash
# Forge SessionStart (opt-in via forge.yaml handoff.auto) — surfaces the portable handoff.
set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -f "$ROOT/.forge/HANDOFF.md" ] && cat "$ROOT/.forge/HANDOFF.md"
exit 0
