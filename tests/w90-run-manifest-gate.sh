#!/usr/bin/env bash
# Gate W9.0 — run-manifest/v1:
#   [1] schema JSON válido e manifesto direto valida contra schema
#   [2] proveniência Git registra metadados seguros sem diff bruto
#   [3] spec-verify grava run-manifest no change ativo
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w90.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"

echo "[1] run-manifest direto valida contra schema"
git -C "$T" init >/dev/null
git -C "$T" config user.email forge@example.test
git -C "$T" config user.name Forge
printf 'initial\n' > "$T/secret.txt"
git -C "$T" add secret.txt .forge >/dev/null
git -C "$T" commit -m init >/dev/null
printf 'TOPSECRET-DO-NOT-PERSIST\n' >> "$T/secret.txt"
FORGE_ROOT="$T" bash "$S/run-manifest.sh" write \
  --stage smoke \
  --status passed \
  --inputs secret.txt \
  --outputs secret.txt \
  --command "smoke::true::passed" >/dev/null
RM="$(find "$T/.forge/runs" -name run-manifest.json | head -1)"
[ -f "$RM" ]
node "$WS/tools/validate-yaml.mjs" "$WS/template/.forge/schemas/run-manifest.schema.json" "$RM" >/dev/null
echo "OK [1]"

echo "[2] sem diff bruto nem segredo em run-manifest"
node -e "
  const fs = require('fs');
  const m = JSON.parse(fs.readFileSync('$RM','utf8'));
  if (!m.git.repo || !m.git.dirty) throw new Error('git provenance missing');
  if (!m.git.diff_sha256 || !/^[a-f0-9]{64}$/.test(m.git.diff_sha256)) throw new Error('diff hash missing');
  const raw = JSON.stringify(m);
  if (raw.includes('diff --git')) throw new Error('raw diff persisted');
  if (raw.includes('TOPSECRET-DO-NOT-PERSIST')) throw new Error('secret diff content persisted');
"
echo "OK [2]"

echo "[3] spec-verify grava evidence/runs no change"
(cd "$T" && bash "$S/spec-new.sh" rm-evidence --type feature --scale 0 >/dev/null
          bash "$S/spec-transition.sh" rm-evidence tasks-ready >/dev/null
          bash "$S/spec-transition.sh" rm-evidence implementing >/dev/null)
perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$T/.forge/specs/active/rm-evidence/tasks.md"
(cd "$T" && bash "$S/spec-transition.sh" rm-evidence implemented >/dev/null
          FORGE_ROOT="$T" bash "$S/spec-verify.sh" rm-evidence >/dev/null)
VRM="$(find "$T/.forge/specs/active/rm-evidence/evidence/runs" -name run-manifest.json | head -1)"
[ -f "$VRM" ]
node "$WS/tools/validate-yaml.mjs" "$WS/template/.forge/schemas/run-manifest.schema.json" "$VRM" >/dev/null
node -e "const m=require('$VRM'); if (m.stage !== 'verify' || m.status !== 'passed') throw new Error('verify manifest mismatch')"
echo "OK [3]"

echo "OK"
