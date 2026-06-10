#!/usr/bin/env bash
# Gate W1.2 — installs the template into a throwaway fixture, runs sync-adapters twice
# (idempotency: byte-identical tree) and the compatibility contract in generated mode.
# Output: gate lines + final "OK" or "FAIL (...)".
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d /tmp/forge-w12.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# init-lite: install canonical tree + fill placeholders (full /forge:init arrives in W1.3)
cp -R "$WS/template/.forge" "$TMP/.forge"
perl -pi -e 's/<PROJECT_SLUG>/fixture-app/g; s/<PROJECT_NAME>/Fixture App/g; s/<PROJECT_DESCRIPTION>/Fixture for the W1.2 gate/g' \
  "$TMP/.forge/FORGE.md" "$TMP/.forge/constitution.md" "$TMP/.forge/context.md"

tree_hash() {
  (cd "$1" && find . -type f ! -name '.DS_Store' -print0 | LC_ALL=C sort -z \
    | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1)
}

bash "$TMP/.forge/scripts/sync-adapters.sh" --adapter claude >/dev/null
H1="$(tree_hash "$TMP")"
bash "$TMP/.forge/scripts/sync-adapters.sh" --adapter claude >/dev/null
H2="$(tree_hash "$TMP")"

if [ "$H1" != "$H2" ]; then
  echo "FAIL (sync-adapters is not idempotent: $H1 != $H2)"
  exit 1
fi
echo "OK idempotency (tree hash stable: ${H1:0:12})"

CLAUDE_CONTRACT_MODE=generated CLAUDE_CONTRACT_TARGET="$TMP" \
  bats "$WS/tests/snapshot/claude-contract.bats"

echo "OK"
