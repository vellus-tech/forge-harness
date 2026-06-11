#!/usr/bin/env bash
# forge verify (deterministic half, W2.2) — verifies an active change:
#   1. status must be implementing|implemented (chain states with code done)
#   2. tasks.md must have zero open entries ([ ] / [-] / [!])
#   3. runs the checks declared in .forge/FORGE.md frontmatter (runtime: test/
#      typecheck/lint) with a 300s timeout each; raw output goes to /tmp, only
#      the tail is meant to be read (§17.6)
#   4. writes verification.yaml (§10.10) with commit + per-check status
# It does NOT transition status — /forge:verify runs the HITL gate and then
# spec-transition.sh <id> verified.
# Output: "OK <id> (...)" or "FAIL (...)". Exit 1 on any failed check/open task.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

ID="${1:-}"
[ -n "$ID" ] || { echo "FAIL (usage: spec-verify.sh <change-id>)"; exit 2; }
DIR="$ROOT/.forge/specs/active/$ID"
MAN="$DIR/manifest.yaml"
[ -f "$MAN" ] || { echo "FAIL (no active change: $ID)"; exit 1; }

STATUS="$(awk -F': ' '$1=="status"{print $2; exit}' "$MAN")"
case "$STATUS" in implementing|implemented) ;; *) echo "FAIL (status '$STATUS' — verify runs on implementing|implemented)"; exit 1 ;; esac

fail=0
notes=""

# ── tasks complete? ───────────────────────────────────────────────────────────
if [ -f "$DIR/tasks.md" ]; then
  open="$(grep -cE '^\s*- \[( |-|!)\] ' "$DIR/tasks.md" || true)"
  if [ "$open" -gt 0 ]; then
    notes="$open open task(s) in tasks.md"
    fail=1
  fi
else
  notes="tasks.md missing"
  fail=1
fi

# ── checks from FORGE.md runtime: block ──────────────────────────────────────
get_runtime() { # get_runtime <key> — value of "  <key>:" inside the runtime: block
  [ -f "$ROOT/.forge/FORGE.md" ] || return 0
  awk -v key="$1" '
    /^runtime:/ { inb=1; next }
    inb && /^[^ ]/ { inb=0 }
    inb { sub(/^  /, ""); if (index($0, key ":") == 1) { sub(key ":", ""); gsub(/^ +| +$/, ""); print; exit } }
  ' "$ROOT/.forge/FORGE.md"
}

CHECKS_YAML=""
run_check() { # run_check <name> <command>
  local name="$1" cmd="$2" log="/tmp/forge-verify-$ID-$1.log" status
  if perl -e 'alarm 300; exec @ARGV' -- bash -c "cd '$ROOT' && $cmd" >"$log" 2>&1; then
    status="passed"
  else
    status="failed"; fail=1
  fi
  echo "  $name: $status (log: $log)"
  CHECKS_YAML="$CHECKS_YAML    - name: $name\n      command: \"$cmd\"\n      status: $status\n"
}

for check in test typecheck lint; do
  cmd="$(get_runtime "$check" || true)"
  [ -n "$cmd" ] && run_check "$check" "$cmd"
done
[ -n "$CHECKS_YAML" ] || echo "  (no checks declared in FORGE.md runtime: — skipping check phase)"

# ── verification.yaml (§10.10) ───────────────────────────────────────────────
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo "unversioned")"
AT="$(date +%Y-%m-%dT%H:%M:%S%z | sed 's/\([0-9][0-9]\)$/:\1/')"
{
  printf 'verification:\n'
  printf '  commit: "%s"\n' "$COMMIT"
  printf '  verified_at: "%s"\n' "$AT"
  printf '  checks:\n'
  if [ -n "$CHECKS_YAML" ]; then
    printf '%b' "$CHECKS_YAML"
  else
    printf '%s\n' '    - name: none' '      command: "(no checks declared in FORGE.md runtime)"' '      status: skipped'
  fi
  printf '  evidence:\n'
  printf '    - verification.md\n'
} > "$DIR/verification.yaml"

if [ "$fail" -eq 0 ]; then
  echo "OK $ID (verification.yaml written)"
else
  echo "FAIL (${notes:-check(s) failed — see /tmp/forge-verify-$ID-*.log})"
  exit 1
fi
