#!/usr/bin/env bash
# forge check data-governance (G4 — GW.3): flagra divergencia vs a matriz de
# governanca de dados (rules/data/data-governance.md). CONFLICT bloqueia.
# Usage: check-data-governance.sh <change-id> | --path <dir|file> [...]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
command -v node >/dev/null 2>&1 || { echo "FAIL (node >= 20 required)"; exit 1; }
case "${1:-}" in
  --path) shift; node "$SCRIPT_DIR/lib/check-data-governance.mjs" "$@" ;;
  "") echo "FAIL (usage: check-data-governance.sh <change-id> | --path <dir|file>)"; exit 1 ;;
  *) node "$SCRIPT_DIR/lib/check-data-governance.mjs" "$ROOT/.forge/specs/active/$1" ;;
esac
