#!/usr/bin/env bash
# forge close (W2.2) — ends an active change WITHOUT touching the baseline (§13):
# moves the folder to .forge/specs/archived/YYYY-MM-DD-<id>/ with
# archive.kind: closed_without_baseline_update.
# Rules (§10.7 + plan L3):
#   --reason abandoned|rejected : only from idea|proposed|requirements-ready|
#                                 design-ready|tasks-ready (pre-implementing)
#   --reason superseded         : from any state; requires --superseded-by <id>
# A close decision is always logged in approvals.yaml (gate: close) with the
# mandatory --note as its reason (§12.1).
# The script touches NOTHING outside the change folder.
# Usage: spec-close.sh <change-id> --reason <r> --note "<text>" [--superseded-by <id>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

ID="${1:-}"; shift || true
REASON=""; NOTE=""; SUPERSEDED_BY=""
while [ $# -gt 0 ]; do case "$1" in
  --reason) REASON="${2:-}"; shift 2 ;;
  --note) NOTE="${2:-}"; shift 2 ;;
  --superseded-by) SUPERSEDED_BY="${2:-}"; shift 2 ;;
  *) echo "FAIL (unknown argument: $1)"; exit 2 ;;
esac; done

[ -n "$ID" ] || { echo "FAIL (usage: spec-close.sh <change-id> --reason <r> --note ...)"; exit 2; }
DIR="$ROOT/.forge/specs/active/$ID"
MAN="$DIR/manifest.yaml"
[ -f "$MAN" ] || { echo "FAIL (no active change: $ID)"; exit 1; }
case "$REASON" in abandoned|rejected|superseded) ;; *) echo "FAIL (--reason must be abandoned|rejected|superseded, got: '$REASON')"; exit 2 ;; esac
[ -n "$NOTE" ] || { echo "FAIL (--note is mandatory — every close records a reason, §12.1)"; exit 2; }
if [ "$REASON" = "superseded" ] && [ -z "$SUPERSEDED_BY" ]; then
  echo "FAIL (superseded requires --superseded-by <change-id>)"; exit 2
fi

STATUS="$(awk -F': ' '$1=="status"{print $2; exit}' "$MAN")"
if [ "$REASON" != "superseded" ]; then
  case "$STATUS" in
    idea|proposed|requirements-ready|design-ready|tasks-ready) ;;
    *) echo "FAIL ($REASON only applies before implementing — status is '$STATUS'; from implementing onward use superseded or finish the cycle)"; exit 1 ;;
  esac
fi

# decision log (gate: close)
case "$REASON" in abandoned) DEC="abandon" ;; rejected) DEC="reject" ;; superseded) DEC="supersede" ;; esac
# ${arr[@]+...} guard: empty array + set -u explodes on macOS bash 3.2
extra=()
[ -n "$SUPERSEDED_BY" ] && extra=(--superseded-by "$SUPERSEDED_BY")
bash "$SCRIPT_DIR/approval-log.sh" "$ID" --gate close --decision "$DEC" --reason "$NOTE" ${extra[@]+"${extra[@]}"} >/dev/null

# manifest: status + archive block (kind/reason), inside the change folder only
TODAY="$(date +%F)"
NOTE_ESC="$(printf '%s' "$NOTE" | sed 's/"/\\"/g')"
perl -pi -e "s/^status: .*/status: $REASON/; s/^updated_at: .*/updated_at: \"$TODAY\"/" "$MAN"
grep -q '^  kind: ' "$MAN" || perl -pi -e "s/^archive:$/archive:\n  kind: closed_without_baseline_update/" "$MAN"
REASON_ESC="$NOTE_ESC" perl -pi -e 's/^  reason: .*/  reason: "$ENV{REASON_ESC}"/' "$MAN"

DEST="$ROOT/.forge/specs/archived/$TODAY-$ID"
[ ! -e "$DEST" ] || { echo "FAIL (archive destination already exists: $DEST)"; exit 1; }
mkdir -p "$ROOT/.forge/specs/archived"
mv "$DIR" "$DEST"

echo "OK $ID closed ($REASON) -> .forge/specs/archived/$TODAY-$ID (baseline untouched)"
