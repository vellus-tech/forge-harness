#!/usr/bin/env bash
# Spec state machine (minimal subset of §10.7/§12, W2.2 full schema in W3.0).
# Applies ONE transition to an active change manifest, enforcing the chain
# adapted to the change's scale (§10.3):
#   scale 0:  idea -> proposed -> tasks-ready -> implementing -> implemented -> verified
#   scale 1:  + requirements-ready (before tasks-ready)
#   scale >=2: + design-ready (after requirements-ready)
# Lateral states:
#   any -> blocked (requires --reason)
#   blocked -> any chain state (requires --reason; human decision)
# NOT handled here (use the dedicated commands):
#   abandoned/rejected/superseded -> spec-close.sh ; archived -> /forge:archive (MVP3)
# Usage: spec-transition.sh <change-id> <new-status> [--reason "<text>"]
# Output: "OK <id>: <old> -> <new>" or "FAIL (...)". Updates status + updated_at.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

ID="${1:-}"; TARGET="${2:-}"; REASON=""
[ $# -ge 2 ] || { echo "FAIL (usage: spec-transition.sh <change-id> <new-status> [--reason ...])"; exit 2; }
shift 2
while [ $# -gt 0 ]; do case "$1" in
  --reason) REASON="${2:-}"; shift 2 ;;
  *) echo "FAIL (unknown argument: $1)"; exit 2 ;;
esac; done

DIR="$ROOT/.forge/specs/active/$ID"
MAN="$DIR/manifest.yaml"
[ -f "$MAN" ] || { echo "FAIL (no active change: $ID)"; exit 1; }

CURRENT="$(awk -F': ' '$1=="status"{print $2; exit}' "$MAN")"
SCALE="$(awk -F': ' '$1=="scale"{print $2; exit}' "$MAN")"

case "$TARGET" in
  abandoned|rejected|superseded) echo "FAIL (use spec-close.sh / /forge:close for $TARGET)"; exit 2 ;;
  archived) echo "FAIL (archive arrives in MVP3 — /forge:archive)"; exit 2 ;;
esac

# chain for this scale
chain="idea proposed"
[ "$SCALE" -ge 1 ] 2>/dev/null && chain="$chain requirements-ready"
[ "$SCALE" -ge 2 ] 2>/dev/null && chain="$chain design-ready"
chain="$chain tasks-ready implementing implemented verified"

in_chain() { printf ' %s ' $chain | grep -q " $1 "; }

if [ "$TARGET" = "blocked" ]; then
  [ -n "$REASON" ] || { echo "FAIL (blocked requires --reason)"; exit 2; }
elif [ "$CURRENT" = "blocked" ]; then
  in_chain "$TARGET" || { echo "FAIL (cannot unblock to '$TARGET' — not a chain state for scale $SCALE)"; exit 1; }
  [ -n "$REASON" ] || { echo "FAIL (unblocking requires --reason)"; exit 2; }
else
  in_chain "$TARGET" || { echo "FAIL ('$TARGET' is not a chain state for scale $SCALE)"; exit 1; }
  in_chain "$CURRENT" || { echo "FAIL (current status '$CURRENT' is outside the chain — resolve manually)"; exit 1; }
  next="$(printf '%s\n' $chain | awk -v cur="$CURRENT" '$0==cur{getline; print; exit}')"
  [ "$TARGET" = "$next" ] || { echo "FAIL (invalid transition $CURRENT -> $TARGET; next allowed for scale $SCALE: $next)"; exit 1; }
fi

# G1 guardrail (conflict-handling): a relevant conflict blocks implementation.
# If analysis.md exists and is not clear, refuse the transition to implementing.
# "Clear" = Status line is PASS AND there is no BLOCKER row. Re-run /forge:analyze
# after resolving the conflict to regenerate a clean analysis.md.
if [ "$TARGET" = "implementing" ] && [ -f "$DIR/analysis.md" ]; then
  blockers="$(grep -cE '\| *BLOCKER *\|' "$DIR/analysis.md" || true)"
  status_fail="$(grep -cE '^## *Status:.*FAIL' "$DIR/analysis.md" || true)"
  if [ "$blockers" -gt 0 ] || [ "$status_fail" -gt 0 ]; then
    echo "FAIL (analysis.md has $blockers BLOCKER finding(s) / status FAIL — resolve the conflict and re-run /forge:analyze before implementing; conflict-handling.md G1)"
    exit 1
  fi
fi

TODAY="$(date +%F)"
cp "$MAN" "$MAN.bak"
perl -pi -e "s/^status: .*/status: $TARGET/; s/^updated_at: .*/updated_at: \"$TODAY\"/" "$MAN"

if out="$(bash "$SCRIPT_DIR/validate-spec.sh" --path "$DIR" 2>&1)"; then
  rm -f "$MAN.bak"
  echo "OK $ID: $CURRENT -> $TARGET"
else
  mv "$MAN.bak" "$MAN"
  echo "FAIL (transition would leave change invalid: $out)"
  exit 1
fi
