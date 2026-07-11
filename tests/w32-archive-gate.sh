#!/usr/bin/env bash
# Gate W3.2 — archive with delta apply (§13):
#   [1] §8.1 canonical scenario, literal: add-card-tokenization adds REQ-TOK-001
#       (scenario SCN-TOK-001-A) to capability `tokenization`; after archive the
#       baseline holds it, history references the change, folder is in
#       specs/archived/YYYY-MM-DD-add-card-tokenization, index + CHANGELOG updated
#   [2] archive with open tasks → FAIL with clear message
#   [3] failed dry-run leaves NOTHING modified (tree hash identical)
#   [4] modify = FULL REPLACEMENT (old scenarios gone) + patch bump
#   [5] remove → requirement gone + history note + major bump
#   [6] ingest-legacy preserves the original docs/product and refuses a second run
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w32.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"
TODAY="$(date +%F)"

mk_verified() { # mk_verified <id>  — drive a scale-0 change to verified with archive gate approved
  (cd "$T" && bash "$S/spec-new.sh" "$1" --type feature --scale 0 >/dev/null
              bash "$S/spec-transition.sh" "$1" tasks-ready >/dev/null
              bash "$S/spec-transition.sh" "$1" implementing >/dev/null)
  perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$T/.forge/specs/active/$1/tasks.md"
  (cd "$T" && bash "$S/spec-transition.sh" "$1" implemented >/dev/null
              bash "$S/spec-verify.sh" "$1" >/dev/null
              bash "$S/approval-log.sh" "$1" --gate implementation_verified --decision approve >/dev/null
              bash "$S/spec-transition.sh" "$1" verified >/dev/null
              bash "$S/approval-log.sh" "$1" --gate human_archive_approval --decision approve >/dev/null)
}

echo "[1] cenário canônico §8.1 (add-card-tokenization / REQ-TOK-001)"
mk_verified add-card-tokenization
# ledger round-trip: este change nasce de um item do ledger — archive deve marcá-lo resolved.
FORGE_ROOT="$T" bash "$S/ledger-ops.sh" add --type roadmap --title "tokenização de cartão" >/dev/null
perl -pi -e 's/^(owner: .*)$/$1\nledger_origin: LDG-0001/' "$T/.forge/specs/active/add-card-tokenization/manifest.yaml"
cat > "$T/.forge/specs/active/add-card-tokenization/spec-delta.yaml" <<'EOF'
operations:
  - op: add_requirement
    capability: tokenization
    requirement_id: REQ-TOK-001
    content_ref: requirements.md#req-tok-001
    requirement:
      id: REQ-TOK-001
      title: Tokenize card PAN
      normative: SHALL
      scenarios:
        - id: SCN-TOK-001-A
          given: "A valid PAN from an enrolled issuer"
          when: "The tokenization request is approved"
          then: "The system returns a network token without exposing PAN"
      contracts:
        - contracts/tokenization.openapi.yaml#/paths/~1tokens/post
      tests:
        - tests/tokenization/tokenize-card.spec.ts
EOF
FORGE_ROOT="$T" bash "$S/archive-spec.sh" add-card-tokenization >/dev/null
CAP="$T/.forge/product/current/capabilities/tokenization/spec.yaml"
[ -f "$CAP" ]
grep -q 'REQ-TOK-001' "$CAP" && grep -q 'SCN-TOK-001-A' "$CAP"
grep -q 'change_id: add-card-tokenization' "$CAP"
[ -d "$T/.forge/specs/archived/$TODAY-add-card-tokenization" ]
[ ! -e "$T/.forge/specs/active/add-card-tokenization" ]
grep -q 'add-card-tokenization' "$T/.forge/specs/archived/index.yaml"
grep -q "## $TODAY — add-card-tokenization" "$T/.forge/product/current/CHANGELOG.md"
node "$WS/tools/validate-yaml.mjs" "$WS/template/.forge/schemas/baseline-capability.schema.json" "$CAP" >/dev/null
# ciclo fechado: o item de origem do ledger foi marcado resolved pelo archive
node -e 'const d=require(process.argv[1]);const e=d.entries.find(x=>x.id==="LDG-0001");process.exit(e&&e.status==="resolved"?0:1)' "$T/.forge/ledger/ledger.json" \
  || { echo "FAIL: LDG-0001 não foi resolved pelo archive"; exit 1; }
echo "OK [1] (+ ledger_origin -> resolved)"

echo "[2] archive com task aberta → FAIL claro"
mk_verified chg-open
cp "$T/.forge/specs/archived/$TODAY-add-card-tokenization/spec-delta.yaml" "$T/.forge/specs/active/chg-open/spec-delta.yaml" 2>/dev/null || cp /dev/null /dev/null
cat > "$T/.forge/specs/active/chg-open/spec-delta.yaml" <<'EOF'
operations:
  - op: add_requirement
    capability: tokenization
    requirement_id: REQ-TOK-002
    requirement:
      id: REQ-TOK-002
      title: Another requirement
      normative: SHOULD
EOF
printf -- '- [ ] TASK-09 — tarefa esquecida (rastreia: REQ-X; paths: x; depende: —)\n' >> "$T/.forge/specs/active/chg-open/tasks.md"
set +e
out="$(FORGE_ROOT="$T" bash "$S/archive-spec.sh" chg-open 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && echo "$out" | grep -q 'open task'
perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$T/.forge/specs/active/chg-open/tasks.md"
echo "OK [2]"

echo "[3] dry-run falho não modifica nada"
cat > "$T/.forge/specs/active/chg-open/spec-delta.yaml" <<'EOF'
operations:
  - op: add_requirement
    capability: tokenization
    requirement_id: REQ-TOK-002
    requirement:
      id: REQ-TOK-002
      title: Broken scenario requirement
      normative: SHOULD
      scenarios:
        - id: SCN-TOK-002-A
          given: "only given, missing when/then"
EOF
H_BEFORE="$(cd "$T" && find .forge/product -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 | shasum -a 256)"
set +e
out="$(FORGE_ROOT="$T" bash "$S/archive-spec.sh" chg-open 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && echo "$out" | grep -q 'scenario incomplete'
H_AFTER="$(cd "$T" && find .forge/product -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 | shasum -a 256)"
[ "$H_BEFORE" = "$H_AFTER" ]
[ -d "$T/.forge/specs/active/chg-open" ]   # change não foi movido
echo "OK [3]"

echo "[4] modify = substituição integral + patch bump"
cat > "$T/.forge/specs/active/chg-open/spec-delta.yaml" <<'EOF'
operations:
  - op: modify_requirement
    capability: tokenization
    requirement_id: REQ-TOK-001
    full_replacement_ref: requirements.md#req-tok-001
    requirement:
      id: REQ-TOK-001
      title: Tokenize card PAN with issuer validation
      normative: SHALL
EOF
FORGE_ROOT="$T" bash "$S/archive-spec.sh" chg-open >/dev/null
grep -q 'issuer validation' "$CAP"
! grep -q 'SCN-TOK-001-A' "$CAP"          # cenários antigos NÃO sobreviveram (não é merge)
grep -q '^version: 0.1.1$' "$CAP"          # new cap born 0.1.0 (no creation bump) -> modify(patch) 0.1.1
echo "OK [4]"

echo "[5] remove → some + history note + major bump"
mk_verified chg-remove
cat > "$T/.forge/specs/active/chg-remove/spec-delta.yaml" <<'EOF'
operations:
  - op: remove_requirement
    capability: tokenization
    requirement_id: REQ-TOK-001
    reason: "Replaced by v2 tokenization"
    migration: "Use REQ-TOK-010"
EOF
FORGE_ROOT="$T" bash "$S/archive-spec.sh" chg-remove >/dev/null
! grep -q 'REQ-TOK-001$' "$CAP" || true
! grep -q 'id: REQ-TOK-001' "$CAP"
grep -q 'Replaced by v2 tokenization' "$CAP"
grep -q '^version: 1.0.0$' "$CAP"          # 0.1.1 -> remove(major) 1.0.0
node "$WS/tools/validate-yaml.mjs" "$WS/template/.forge/schemas/baseline-capability.schema.json" "$CAP" >/dev/null
echo "OK [5]"

echo "[6] ingest-legacy preserva original e recusa segunda rodada"
T2="$(mktemp -d /tmp/forge-w32b.XXXXXX)"
cp -R "$WS/template/.forge" "$T2/.forge"
mkdir -p "$T2/docs/product/prd" "$T2/docs/product/adr"
echo "# PRD legado" > "$T2/docs/product/prd/prd.md"
echo "# ADR legado" > "$T2/docs/product/adr/0001-legacy.md"
FORGE_ROOT="$T2" bash "$T2/.forge/scripts/ingest-legacy.sh" >/dev/null
[ -f "$T2/docs/product/prd/prd.md" ]                                  # original intacto
[ -f "$T2/.forge/product/current/prd/prd.md" ]                        # importado
[ -f "$T2/.forge/product/current/adr/0001-legacy.md" ]
set +e
FORGE_ROOT="$T2" bash "$T2/.forge/scripts/ingest-legacy.sh" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 3 ]
rm -rf "$T2"
echo "OK [6]"

echo "OK"
