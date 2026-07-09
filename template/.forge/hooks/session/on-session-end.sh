#!/usr/bin/env bash
# Forge SessionEnd (opt-in) — regenerates the deterministic handoff scaffold (rule-based, no LLM).
set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -x "$ROOT/.forge/scripts/handoff-gen.sh" ] || exit 0
FORGE_ROOT="$ROOT" bash "$ROOT/.forge/scripts/handoff-gen.sh" >/dev/null 2>&1 || true
exit 0
