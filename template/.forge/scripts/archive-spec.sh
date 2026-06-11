#!/usr/bin/env bash
# forge archive (§13.2, W3.2) — incorporates a VERIFIED change into the baseline
# and moves the folder to history:
#   1. pre-flight §13.1 (validate-archive: §19.2 spec rules + archive conditions)
#   2. delta dry-run (in memory; resulting baseline validated; nothing written)
#   3. delta apply (write-temp + atomic rename per capability)
#   4. aggregated PRD/FRD/NFRD/TRD/DDD views: skipped in v1 (note printed)
#   5. archive metadata in the manifest (status archived, kind baseline_update)
#   6. move to .forge/specs/archived/YYYY-MM-DD-<id>/
#   7. archived/index.yaml + product/current/CHANGELOG.md entries
# Usage: archive-spec.sh <change-id>   (FORGE_ROOT overrides the repo root)
# Output: step lines + final "OK ..." / "FAIL (...)".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
ID="${1:-}"
[ -n "$ID" ] || { echo "FAIL (usage: archive-spec.sh <change-id>)"; exit 2; }
DIR="$ROOT/.forge/specs/active/$ID"
[ -d "$DIR" ] || { echo "FAIL (no active change: $ID)"; exit 1; }

echo "[1/6] pre-flight (§13.1)"
FORGE_ROOT="$ROOT" bash "$SCRIPT_DIR/validate-archive.sh" --path "$DIR" || exit 1

echo "[2/6] delta dry-run"
node "$SCRIPT_DIR/lib/delta-apply.mjs" "$DIR" "$ROOT" --dry-run || exit 1

echo "[3/6] delta apply"
node "$SCRIPT_DIR/lib/delta-apply.mjs" "$DIR" "$ROOT" || exit 1

echo "[4/6] aggregated views: skipped (v1 — capabilities are the primary merge; PRD/FRD/TRD/DDD aggregation arrives with real content)"

echo "[5/6] archive metadata + move"
TODAY="$(date +%F)"
MAN="$DIR/manifest.yaml"
perl -pi -e "s/^status: .*/status: archived/; s/^updated_at: .*/updated_at: \"$TODAY\"/" "$MAN"
grep -q '^  kind: ' "$MAN" || perl -pi -e "s/^archive:$/archive:\n  kind: baseline_update/" "$MAN"
perl -pi -e 's/^  eligible: .*/  eligible: true/' "$MAN"
perl -pi -e "s/^  reason: .*/  reason: \"deltas applied to baseline on $TODAY\"/" "$MAN"
DEST="$ROOT/.forge/specs/archived/$TODAY-$ID"
[ ! -e "$DEST" ] || { echo "FAIL (archive destination already exists: $DEST)"; exit 1; }
mkdir -p "$ROOT/.forge/specs/archived"
mv "$DIR" "$DEST"

echo "[6/6] index + CHANGELOG"
INDEX="$ROOT/.forge/specs/archived/index.yaml"
[ -f "$INDEX" ] || printf 'archived:\n' > "$INDEX"
{
  printf '  - change_id: %s\n' "$ID"
  printf '    archived_at: "%s"\n' "$TODAY"
  printf '    kind: baseline_update\n'
  printf '    path: %s\n' "$TODAY-$ID"
} >> "$INDEX"

CHG="$ROOT/.forge/product/current/CHANGELOG.md"
[ -f "$CHG" ] || printf '# Product Baseline — CHANGELOG\n\n> One entry per archived change (newest first). Maintained by `/forge:archive` — do not edit by hand.\n' > "$CHG"
CAPS_TOUCHED="$(awk -F': ' '$1~/^ *capability$/{print $2}' "$DEST/spec-delta.yaml" 2>/dev/null | sort -u | tr '\n' ' ' | sed 's/ $//')"
OPS_COUNT="$(grep -c '^  - op: ' "$DEST/spec-delta.yaml" 2>/dev/null || echo 0)"
TMP="$(mktemp)"
{
  head -3 "$CHG"
  printf '\n## %s — %s\n\n- **Capabilities:** %s\n- **Operações:** %s\n- **Pasta:** `.forge/specs/archived/%s-%s/`\n' \
    "$TODAY" "$ID" "${CAPS_TOUCHED:-—}" "$OPS_COUNT" "$TODAY" "$ID"
  tail -n +4 "$CHG"
} > "$TMP" && mv "$TMP" "$CHG"

echo "OK $ID archived -> .forge/specs/archived/$TODAY-$ID (baseline updated)"
