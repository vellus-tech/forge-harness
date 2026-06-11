#!/usr/bin/env bash
# forge spec new (W2.0) — deterministically creates an active change folder:
#   .forge/specs/active/<change-id>/ with manifest.yaml + type/scale templates.
# Usage:
#   spec-new.sh <change-id> --type feature|bugfix|refactor|greenfield|brownfield
#               [--scale 0..4] [--rigor spec-anchored|spec-first|spec-as-source]
#               [--mode greenfield|brownfield|feature-only] [--owner <name>]
# Behavior:
#   - refuses to overwrite an existing change (exit 3, tree untouched)
#   - installs templates for the phases the scale requires (stubs to be filled
#     by /forge:requirements, /forge:design, /forge:tasks)
#   - validates the result with validate-spec.sh; on failure rolls back (exit 1)
# Output: "OK .forge/specs/active/<id>" or "FAIL (...)".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TPL="$(cd "$SCRIPT_DIR/.." && pwd)/templates"   # templates ship with the installation, not the data root
ACTIVE="$ROOT/.forge/specs/active"

ID="${1:-}"; shift || true
TYPE=""; SCALE="2"; RIGOR="spec-anchored"; MODE=""; OWNER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --type)  TYPE="${2:-}"; shift 2 ;;
    --scale) SCALE="${2:-}"; shift 2 ;;
    --rigor) RIGOR="${2:-}"; shift 2 ;;
    --mode)  MODE="${2:-}"; shift 2 ;;
    --owner) OWNER="${2:-}"; shift 2 ;;
    *) echo "FAIL (unknown argument: $1)"; exit 2 ;;
  esac
done

# ── validation of inputs ──────────────────────────────────────────────────────
[ -n "$ID" ] || { echo "FAIL (usage: spec-new.sh <change-id> --type <type> [--scale N])"; exit 2; }
echo "$ID" | grep -Eq '^[a-z0-9][a-z0-9-]*[a-z0-9]$' || { echo "FAIL (change-id must be kebab-case: $ID)"; exit 2; }
case "$TYPE" in feature|bugfix|refactor|greenfield|brownfield) ;; *) echo "FAIL (--type must be feature|bugfix|refactor|greenfield|brownfield, got: '$TYPE')"; exit 2 ;; esac
case "$SCALE" in 0|1|2|3|4) ;; *) echo "FAIL (--scale must be 0..4, got: '$SCALE')"; exit 2 ;; esac
case "$RIGOR" in spec-anchored|spec-first|spec-as-source) ;; *) echo "FAIL (--rigor invalid: $RIGOR)"; exit 2 ;; esac

# mode default: explicit > derived from type > repo heuristic
if [ -z "$MODE" ]; then
  case "$TYPE" in
    greenfield) MODE="greenfield" ;;
    brownfield) MODE="brownfield" ;;
    *) if [ -d "$ROOT/.forge/product/current" ] || [ -d "$ROOT/docs/product" ]; then MODE="brownfield"; else MODE="greenfield"; fi ;;
  esac
fi
case "$MODE" in greenfield|brownfield|feature-only) ;; *) echo "FAIL (--mode invalid: $MODE)"; exit 2 ;; esac

[ -n "$OWNER" ] || OWNER="$(git config user.name 2>/dev/null || true)"
[ -n "$OWNER" ] || OWNER="$(id -un)"

DEST="$ACTIVE/$ID"
[ ! -e "$DEST" ] || { echo "FAIL (change already exists: $DEST — choose another id)"; exit 3; }

TODAY="$(date +%F)"
mkdir -p "$DEST"
trap 'rm -rf "$DEST"' ERR

# ── templates by type/scale ───────────────────────────────────────────────────
fill() { # fill <template> <dest-file>
  SRC_FILE="$1" DEST_FILE="$2" CH_ID="$ID" CH_TYPE="$TYPE" CH_SCALE="$SCALE" CH_DATE="$TODAY" CH_OWNER="$OWNER" \
  perl -pe 's/<CHANGE_ID>/$ENV{CH_ID}/g; s/<CHANGE_TYPE>/$ENV{CH_TYPE}/g; s/<CHANGE_SCALE>/$ENV{CH_SCALE}/g; s/<CHANGE_DATE>/$ENV{CH_DATE}/g; s/<CHANGE_OWNER>/$ENV{CH_OWNER}/g' \
    "$1" > "$2"
}

fill "$TPL/spec/proposal.md" "$DEST/proposal.md"
case "$TYPE" in
  bugfix)   [ "$SCALE" -ge 1 ] && fill "$TPL/bugfix/bugfix.md" "$DEST/bugfix.md" ;;
  refactor) [ "$SCALE" -ge 1 ] && fill "$TPL/refactor/refactor.md" "$DEST/refactor.md" ;;
  *)        [ "$SCALE" -ge 1 ] && fill "$TPL/spec/requirements.md" "$DEST/requirements.md" ;;
esac
if [ "$SCALE" -ge 2 ] && [ "$TYPE" != "bugfix" ]; then fill "$TPL/spec/design.md" "$DEST/design.md"; fi
fill "$TPL/spec/tasks.md" "$DEST/tasks.md"

# ── manifest (doc §10.2) ──────────────────────────────────────────────────────
cat > "$DEST/manifest.yaml" <<EOF
id: $ID
type: $TYPE
mode: $MODE
rigor: $RIGOR
scale: $SCALE
status: proposed
created_at: "$TODAY"
updated_at: "$TODAY"
owner: "$OWNER"
parent:
  baseline: .forge/product/current
affected_capabilities: []
affected_paths: []
dependencies:
  specs: []
  code: []
gates:
  requirements_reviewed: false
  design_reviewed: false
  tasks_reviewed: false
  implementation_verified: false
  human_archive_approval: false
dev_loop:
  sharded: false
  stories_path: stories/
  epic_context_compiled: false
quick_plan:
  enabled: false
  skipped_phases: []
  justification:
archive:
  eligible: false
  reason: "tasks not implemented"
EOF

# ── self-validate; roll back on failure ──────────────────────────────────────
out="$(bash "$SCRIPT_DIR/validate-spec.sh" --path "$DEST")" || { rm -rf "$DEST"; echo "FAIL (generated change failed validation: $out)"; exit 1; }

echo "OK .forge/specs/active/$ID"
