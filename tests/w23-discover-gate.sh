#!/usr/bin/env bash
# Gate W2.3 — discover lite (§16.1):
#   [1] brownfield fixture (node-ts + git + dirty file) → manifest.json valid by
#       schema (ajv) with stack/commands/changed_files/fingerprints populated
#   [2] greenfield fixture (no stack, no git) → manifest still valid by schema
#   [3] re-run is idempotent (fresh manifest, exit 0)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T1="$(mktemp -d /tmp/forge-w23a.XXXXXX)"
T2="$(mktemp -d /tmp/forge-w23b.XXXXXX)"
trap 'rm -rf "$T1" "$T2"' EXIT
SCHEMA="$WS/template/.forge/schemas/graph-manifest.schema.json"

echo "[1] brownfield node-ts"
git -C "$T1" init -q -b main
cat > "$T1/package.json" <<'EOF'
{ "name": "fixture-crm", "scripts": { "test": "vitest run", "build": "tsc -p .", "typecheck": "tsc --noEmit" } }
EOF
mkdir -p "$T1/src" && echo 'export const x = 1;' > "$T1/src/index.ts"
git -C "$T1" add -A && git -C "$T1" -c user.name=fx -c user.email=f@x commit -qm "init"
echo 'export const y = 2;' > "$T1/src/new.ts"
cp -R "$WS/template/.forge" "$T1/.forge"
(cd "$T1" && bash .forge/scripts/discover.sh >/dev/null)
[ -f "$T1/.forge/graph/manifest.json" ]
node "$WS/tools/validate-yaml.mjs" "$SCHEMA" "$T1/.forge/graph/manifest.json" >/dev/null
node -e '
const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const ok = m.stack.includes("node-ts")
  && m.commands.test === "npm test"
  && m.commands.typecheck === "npm run typecheck"
  && m.git.repo === true && m.git.dirty === true
  && m.git.changed_files.some((f) => f.includes("src/new.ts"))
  && typeof m.fingerprints["package.json"] === "string"
  && m.boundaries.includes("src");
process.exit(ok ? 0 : 1);
' "$T1/.forge/graph/manifest.json"
echo "OK [1]"

echo "[2] greenfield sem stack/git"
cp -R "$WS/template/.forge" "$T2/.forge"
(cd "$T2" && bash .forge/scripts/discover.sh >/dev/null)
node "$WS/tools/validate-yaml.mjs" "$SCHEMA" "$T2/.forge/graph/manifest.json" >/dev/null
node -e '
const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
process.exit(m.stack.length === 0 && m.git.repo === false ? 0 : 1);
' "$T2/.forge/graph/manifest.json"
echo "OK [2]"

echo "[3] idempotência"
(cd "$T1" && bash .forge/scripts/discover.sh >/dev/null)
node "$WS/tools/validate-yaml.mjs" "$SCHEMA" "$T1/.forge/graph/manifest.json" >/dev/null
echo "OK [3]"

echo "OK"
