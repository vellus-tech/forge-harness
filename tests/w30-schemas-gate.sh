#!/usr/bin/env bash
# Gate W3.0 — baseline schemas: the canonical examples from the project doc
# (§10.4 spec-delta, §10.5 baseline-capability, §10.10 approvals legacy form +
# verification) validate against their schemas (ajv); the canonical state
# machine definition validates against its schema; templates and the
# product/current tree are installed; negative cases are rejected.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$WS/template/.forge/schemas"
F="$WS/tests/fixtures/canonical"
V() { node "$WS/tools/validate-yaml.mjs" "$1" "$2" >/dev/null; }

echo "[1] exemplos canônicos do doc validam"
V "$S/spec-delta.schema.json" "$F/spec-delta.yaml"
V "$S/baseline-capability.schema.json" "$F/baseline-capability.yaml"
V "$S/approvals.schema.json" "$F/approvals-legacy.yaml"
V "$S/verification.schema.json" "$F/verification.yaml"
echo "OK [1]"

echo "[2] state machine canônica valida contra o schema"
V "$S/archive-state-machine.schema.json" "$S/archive-state-machine.yaml"
grep -q 'to: rejected' "$S/archive-state-machine.yaml"   # lacuna L3 fechada
echo "OK [2]"

echo "[3] casos negativos rejeitados"
T="$(mktemp -d /tmp/forge-w30.XXXXXX)"; trap 'rm -rf "$T"' EXIT
# remove_requirement sem reason
cat > "$T/bad-delta.yaml" <<'EOF'
operations:
  - op: remove_requirement
    capability: legacy-export
    requirement_id: REQ-LEG-003
EOF
# capability sem version
cat > "$T/bad-cap.yaml" <<'EOF'
capability_id: tokenization
status: current
requirements: []
EOF
# scenario sem then
cat > "$T/bad-scn.yaml" <<'EOF'
capability_id: tokenization
version: 1.0.0
status: current
requirements:
  - id: REQ-TOK-001
    title: Tokenize card PAN
    normative: SHALL
    scenarios:
      - id: SCN-TOK-001-A
        given: "x"
        when: "y"
EOF
for f in bad-delta bad-cap bad-scn; do
  set +e
  case "$f" in
    bad-delta) V "$S/spec-delta.schema.json" "$T/$f.yaml" 2>/dev/null ;;
    *) V "$S/baseline-capability.schema.json" "$T/$f.yaml" 2>/dev/null ;;
  esac
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "negativo aceito: $f"; exit 1; }
done
echo "OK [3]"

echo "[4] templates e estrutura instalados"
for t in spec/spec-delta.yaml spec/traceability.yaml spec/approvals.yaml spec/verification.yaml \
         product/capability-spec.yaml product/changelog-entry.md product/adr.md; do
  [ -f "$WS/template/.forge/templates/$t" ]
done
for d in capabilities prd frd-nfrd ddd trd adr glossary; do
  [ -d "$WS/template/.forge/product/current/$d" ]
done
[ -f "$WS/template/.forge/product/current/CHANGELOG.md" ] && [ -d "$WS/template/.forge/product/published" ]
echo "OK [4]"

echo "[5] templates de delta/traceability validam contra os schemas"
V "$S/traceability.schema.json" "$WS/template/.forge/templates/spec/traceability.yaml"
V "$S/verification.schema.json" "$WS/template/.forge/templates/spec/verification.yaml"
V "$S/approvals.schema.json" "$WS/template/.forge/templates/spec/approvals.yaml"
echo "OK [5]"

echo "OK"
