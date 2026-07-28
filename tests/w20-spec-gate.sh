#!/usr/bin/env bash
# Gate W2.0 — spec lifecycle birth: spec-new creates schema-valid changes for the
# 5 types; invalid manifests are refused with a clear message; ajv parity holds.
#   [1] spec-new for the 5 types (varied scales) → validate-spec OK + expected artifacts
#   [2] overwrite guard: same id again → exit 3, tree untouched
#   [3] input validation: bad id / bad type / bad scale → exit 2 with message
#   [4] corrupted manifests → validate-spec FAIL naming the field
#   [5] ajv parity: workspace validate-forge.mjs (schema + dogfooding manifest)
#   [6] dogfooding change in this workspace validates
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w20.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
SPEC_NEW="$T/.forge/scripts/spec-new.sh"
VALIDATE="$T/.forge/scripts/validate-spec.sh"

echo "[1] spec-new para os 5 tipos"
(cd "$T" && bash "$SPEC_NEW" feat-x --type feature --scale 2 >/dev/null
            bash "$SPEC_NEW" fix-y --type bugfix --scale 1 >/dev/null
            bash "$SPEC_NEW" ref-z --type refactor --scale 2 >/dev/null
            bash "$SPEC_NEW" green-w --type greenfield --scale 3 >/dev/null
            bash "$SPEC_NEW" brown-v --type brownfield --scale 0 >/dev/null)
out="$(cd "$T" && bash "$VALIDATE" --all)"
[ "$(echo "$out" | grep -c '^OK ')" -eq 5 ]
# artifact shape by type/scale
[ -f "$T/.forge/specs/active/feat-x/design.md" ] && [ -f "$T/.forge/specs/active/feat-x/requirements.md" ]
[ -f "$T/.forge/specs/active/fix-y/bugfix.md" ] && [ ! -e "$T/.forge/specs/active/fix-y/design.md" ] && [ ! -e "$T/.forge/specs/active/fix-y/requirements.md" ]
[ -f "$T/.forge/specs/active/ref-z/refactor.md" ] && [ -f "$T/.forge/specs/active/ref-z/design.md" ]
[ ! -e "$T/.forge/specs/active/brown-v/requirements.md" ]   # scale 0: only proposal+tasks
grep -q '^status: proposed$' "$T/.forge/specs/active/feat-x/manifest.yaml"
grep -q 'feat-x' "$T/.forge/specs/active/feat-x/proposal.md"   # placeholders filled
! grep -rq '<CHANGE_' "$T/.forge/specs/active/feat-x/"
echo "OK [1]"

echo "[2] guarda contra sobrescrita"
set +e
(cd "$T" && bash "$SPEC_NEW" feat-x --type feature) >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 3 ]
[ -f "$T/.forge/specs/active/feat-x/design.md" ]
echo "OK [2] (exit 3, change intacto)"

echo "[3] validação de entrada"
set +e
(cd "$T" && bash "$SPEC_NEW" Bad_Id --type feature) >/dev/null 2>&1; [ $? -eq 2 ] || exit 1
(cd "$T" && bash "$SPEC_NEW" ok-id --type banana) >/dev/null 2>&1;  [ $? -eq 2 ] || exit 1
(cd "$T" && bash "$SPEC_NEW" ok-id --type feature --scale 9) >/dev/null 2>&1; [ $? -eq 2 ] || exit 1
set -e
[ ! -e "$T/.forge/specs/active/ok-id" ]
echo "OK [3]"

echo "[4] manifests corrompidos → FAIL com campo nomeado"
corrupt() { # corrupt <sed-expr> <expected-substring>
  local d="$T/.forge/specs/active/feat-x"
  cp "$d/manifest.yaml" "$d/manifest.yaml.bak"
  perl -pi -e "$1" "$d/manifest.yaml"
  set +e
  local out; out="$(cd "$T" && bash "$VALIDATE" feat-x)"; local rc=$?
  set -e
  mv "$d/manifest.yaml.bak" "$d/manifest.yaml"
  [ "$rc" -eq 1 ] || { echo "esperava FAIL: $2"; exit 1; }
  echo "$out" | grep -q "$2" || { echo "mensagem sem campo '$2': $out"; exit 1; }
}
corrupt 's/^scale: 2$/scale: 9/' 'scale'
corrupt 's/^type: feature$/type: banana/' 'type invalid'
corrupt 's/^status: proposed$/status: doing-stuff/' 'status invalid'
corrupt 's/^  enabled: false$/  enabled: true/' 'quick_plan'
corrupt 's/^id: feat-x$/id: outro-id/' 'folder name'
echo "OK [4]"

echo "[4b] affects_surfaces (REQ-13/NFR-03/§2.5): manifest com e sem o campo validam"
d="$T/.forge/specs/active/feat-x"
[ "$(cd "$T" && bash "$VALIDATE" feat-x)" = "OK feat-x" ] || { echo "esperava OK sem affects_surfaces"; exit 1; }
cp "$d/manifest.yaml" "$d/manifest.yaml.bak"
printf 'affects_surfaces:\n  - api\n  - data\n' >> "$d/manifest.yaml"
out="$(cd "$T" && bash "$VALIDATE" feat-x)"
mv "$d/manifest.yaml.bak" "$d/manifest.yaml"
[ "$out" = "OK feat-x" ] || { echo "esperava OK com affects_surfaces: [api, data] — obteve: $out"; exit 1; }
echo "OK [4b]"

echo "[5] paridade ajv (workspace)"
node "$WS/tools/validate-forge.mjs" >/dev/null
echo "OK [5]"

echo "[6] dogfooding valida"
bash "$WS/template/.forge/scripts/validate-spec.sh" --path "$WS/.forge/specs/active/create-forge-project-harness" >/dev/null
echo "OK [6]"

echo "[7] FORGE.md com blocos authz:/observability: + gates: em runtime: valida contra forgeFrontmatter (REQ-11/§2.3/§4)"
cat > "$T/fm-governance.yaml" <<'EOF'
forge_version: 1
project:
  name: acme
  display: Acme
sdd:
  default_mode: brownfield
  default_rigor: spec-anchored
  default_scale: 2
  archive_policy: after_verified_implementation
  human_gate_required: true
runtime:
  primary_stack:
  package_manager:
  run:
  test:
  typecheck:
  lint:
  gates: check-authz,check-observability,check-data-governance
authz:
  pep_paths:
    - services/*/internal/authz
    - packages/pep
  policy_dir: policy
  allowlist:
    - services/health
    - services/metrics
  mode: warn
  policy_coverage_threshold: 0.8
observability:
  wrapper_paths:
    - packages/otel
    - services/*/observability
  allowlist:
    - services/health
  mode: warn
integrations:
  jira:
  github:
  graph:
    enabled: true
    path: .forge/graph/graph.json
quality:
  evals_enabled: false
  runners_config: .forge/runners.yaml
EOF
(cd "$WS" && node -e '
const { readFileSync } = require("node:fs");
const { parse } = require("yaml");
const Ajv2020 = require("ajv/dist/2020.js");
const [schemaPath, dataPath] = process.argv.slice(1);
const core = JSON.parse(readFileSync(schemaPath, "utf8"));
const data = parse(readFileSync(dataPath, "utf8"));
const schema = { ...core.$defs.forgeFrontmatter, $defs: { nullableString: core.$defs.nullableString } };
const ajv = new Ajv2020.default({ allErrors: true, strict: true, allowUnionTypes: true });
const validate = ajv.compile(schema);
if (!validate(data)) {
  console.error(JSON.stringify(validate.errors, null, 2));
  process.exit(1);
}
console.log("OK forgeFrontmatter + authz/observability/gates");
' "$WS/template/.forge/schemas/forge.schema.json" "$T/fm-governance.yaml") >/dev/null
echo "OK [7]"

echo "OK"
