#!/usr/bin/env bash
# Forge SessionStart (opt-in via forge.yaml handoff.auto / ledger.auto) — surfaces the portable
# handoff and/or the durable ledger's top open items at the start of the session. Rule-based, no LLM.
set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

# Handoff (handoff.auto): inject the portable handoff verbatim if present.
[ -f "$ROOT/.forge/HANDOFF.md" ] && cat "$ROOT/.forge/HANDOFF.md"

# Read a top-level "<key>:\n ... auto: true|false" flag from forge.yaml (awk, portable — same
# idiom as fm_field in handoff-gen.sh; avoids grep -P/-z which BSD grep lacks).
_yaml_auto() {
  [ -f "$ROOT/.forge/forge.yaml" ] || { echo ""; return; }
  awk -v key="$1" '
    $0 ~ "^"key":" { inblk=1; next }
    inblk && /^[a-z_]+:/ { exit }
    inblk && /^[ ]+auto:[ ]*(true|false)/ { sub(/^[ ]+auto:[ ]*/, ""); print; exit }
  ' "$ROOT/.forge/forge.yaml"
}

# Ledger (ledger.auto): surface the top open items by priority (rule-based).
if [ "$(_yaml_auto ledger)" = "true" ] && [ -x "$ROOT/.forge/scripts/ledger-ops.sh" ]; then
  items="$(FORGE_ROOT="$ROOT" bash "$ROOT/.forge/scripts/ledger-ops.sh" list --status open --by-priority --top 5 2>/dev/null || true)"
  if [ -n "$items" ] && [ "$items" != "(nenhuma entrada)" ]; then
    printf '\n## LEDGER — top itens open (roadmap & dívida)\n\n%s\n\n(veja .forge/ledger/LEDGER.md · /forge:ledger)\n' "$items"
  fi
fi
exit 0
