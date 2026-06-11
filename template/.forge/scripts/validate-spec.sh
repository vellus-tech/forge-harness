#!/usr/bin/env bash
# forge validate spec (minimal, W2.0) — wrapper over lib/validate-spec.mjs.
# Usage:
#   validate-spec.sh <change-id>      validates .forge/specs/active/<change-id>/
#   validate-spec.sh --path <dir>     validates an explicit change directory
#   validate-spec.sh --all            validates every change under specs/active/
# Output: one "OK <id>" / "FAIL (...)" line per change; exit 1 if any failed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
ACTIVE="$ROOT/.forge/specs/active"

command -v node >/dev/null 2>&1 || { echo "FAIL (node >= 20 required)"; exit 1; }

run_one() { node "$SCRIPT_DIR/lib/validate-spec.mjs" "$1"; }

case "${1:-}" in
  --path)
    [ -n "${2:-}" ] || { echo "FAIL (--path requires a directory)"; exit 1; }
    run_one "$2"
    ;;
  --all)
    fail=0; found=0
    for d in "$ACTIVE"/*/; do
      [ -d "$d" ] || continue
      found=1
      run_one "$d" || fail=1
    done
    [ "$found" -eq 1 ] || { echo "OK (no active changes)"; exit 0; }
    exit "$fail"
    ;;
  "")
    echo "FAIL (usage: validate-spec.sh <change-id> | --path <dir> | --all)"; exit 1
    ;;
  *)
    run_one "$ACTIVE/$1"
    ;;
esac
