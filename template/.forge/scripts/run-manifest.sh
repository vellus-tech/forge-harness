#!/usr/bin/env bash
# Thin wrapper for run-manifest/v1 evidence. See lib/run-manifest.mjs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
node "$SCRIPT_DIR/lib/run-manifest.mjs" "$@" --root "$ROOT"
