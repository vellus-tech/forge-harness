#!/usr/bin/env bash
# HITL decision log (§12.1) — appends one entry to the active change's
# approvals.yaml and, on approve, flips the corresponding manifest gate to true.
# Usage:
#   approval-log.sh <change-id> --gate <gate> --decision <decision>
#                   [--reason "<text>"] [--iteration N] [--scope "<text>"]
#                   [--notes "<text>"] [--superseded-by <id>]
# gates:     requirements_reviewed | design_reviewed | tasks_reviewed |
#            implementation_verified | human_archive_approval | close
# decisions: approve | review | reject | supersede | abandon | block
# Rules (§12.1): every decision except approve REQUIRES --reason;
#                supersede also requires --superseded-by; iteration is 1..3.
# Output: "OK <id>: <gate> = <decision>" or "FAIL (...)".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ID="${1:-}"; shift || true
GATE=""; DECISION=""; REASON=""; ITERATION=""; SCOPE=""; NOTES=""; SUPERSEDED_BY=""
while [ $# -gt 0 ]; do case "$1" in
  --gate) GATE="${2:-}"; shift 2 ;;
  --decision) DECISION="${2:-}"; shift 2 ;;
  --reason) REASON="${2:-}"; shift 2 ;;
  --iteration) ITERATION="${2:-}"; shift 2 ;;
  --scope) SCOPE="${2:-}"; shift 2 ;;
  --notes) NOTES="${2:-}"; shift 2 ;;
  --superseded-by) SUPERSEDED_BY="${2:-}"; shift 2 ;;
  *) echo "FAIL (unknown argument: $1)"; exit 2 ;;
esac; done

[ -n "$ID" ] || { echo "FAIL (usage: approval-log.sh <change-id> --gate <g> --decision <d> ...)"; exit 2; }
DIR="$ROOT/.forge/specs/active/$ID"
MAN="$DIR/manifest.yaml"
[ -f "$MAN" ] || { echo "FAIL (no active change: $ID)"; exit 1; }

case "$GATE" in requirements_reviewed|design_reviewed|tasks_reviewed|implementation_verified|human_archive_approval|close) ;; *) echo "FAIL (--gate invalid: '$GATE')"; exit 2 ;; esac
case "$DECISION" in approve|review|reject|supersede|abandon|block) ;; *) echo "FAIL (--decision invalid: '$DECISION')"; exit 2 ;; esac
if [ "$DECISION" != "approve" ] && [ -z "$REASON" ]; then
  echo "FAIL (every decision except approve requires --reason — §12.1)"; exit 2
fi
if [ "$DECISION" = "supersede" ] && [ -z "$SUPERSEDED_BY" ]; then
  echo "FAIL (supersede requires --superseded-by <change-id>)"; exit 2
fi
if [ -n "$ITERATION" ]; then
  case "$ITERATION" in 1|2|3) ;; *) echo "FAIL (--iteration must be 1..3 — loop §14.6 escalates after 3)"; exit 2 ;; esac
fi

BY="$(git config user.name 2>/dev/null || true)"; [ -n "$BY" ] || BY="$(id -un)"
AT="$(date +%Y-%m-%dT%H:%M:%S%z | sed 's/\([0-9][0-9]\)$/:\1/')"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || true)"

FILE="$DIR/approvals.yaml"
[ -f "$FILE" ] || printf 'approvals:\n' > "$FILE"

{
  printf '  - gate: %s\n' "$GATE"
  printf '    decision: %s\n' "$DECISION"
  [ -n "$REASON" ] && printf '    reason: "%s"\n' "$(printf '%s' "$REASON" | sed 's/"/\\"/g')"
  printf '    decided_by: "%s"\n' "$BY"
  printf '    decided_at: "%s"\n' "$AT"
  [ -n "$ITERATION" ] && printf '    iteration: %s\n' "$ITERATION"
  [ -n "$COMMIT" ] && printf '    commit: "%s"\n' "$COMMIT"
  [ -n "$SCOPE" ] && printf '    scope: "%s"\n' "$(printf '%s' "$SCOPE" | sed 's/"/\\"/g')"
  [ -n "$NOTES" ] && printf '    notes: "%s"\n' "$(printf '%s' "$NOTES" | sed 's/"/\\"/g')"
  [ -n "$SUPERSEDED_BY" ] && printf '    superseded_by: %s\n' "$SUPERSEDED_BY"
} >> "$FILE"

if [ "$DECISION" = "approve" ] && [ "$GATE" != "close" ]; then
  GATE_RE="$GATE" perl -pi -e 's/^(  \Q$ENV{GATE_RE}\E): false$/$1: true/' "$MAN"
fi

echo "OK $ID: $GATE = $DECISION"
