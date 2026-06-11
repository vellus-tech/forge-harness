#!/usr/bin/env bash
# Gate W3.3 — publish round-trip integrity (§8.2):
#   [1] publish mirrors product/current into docs/product + writes publish.lock
#   [2] validate-archive passes on an intact publication
#   [3] manual edit in docs/product → validate-archive FAILs (no baseline origin)
#   [4] re-publish after a baseline change refreshes docs + lock (round-trip heals)
#   [5] governance commands installed (/forge:adr, /forge:constitution,
#       /forge:backlog, /forge:publish-docs) and new-adr points to the baseline successor
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w33.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"
TODAY="$(date +%F)"

# seed: archive a change so the baseline has real content (reuses W3.2 machinery)
(cd "$T" && bash "$S/spec-new.sh" seed-cap --type feature --scale 0 >/dev/null
            bash "$S/spec-transition.sh" seed-cap tasks-ready >/dev/null
            bash "$S/spec-transition.sh" seed-cap implementing >/dev/null)
perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$T/.forge/specs/active/seed-cap/tasks.md"
(cd "$T" && bash "$S/spec-transition.sh" seed-cap implemented >/dev/null
            bash "$S/spec-verify.sh" seed-cap >/dev/null
            bash "$S/approval-log.sh" seed-cap --gate implementation_verified --decision approve >/dev/null
            bash "$S/spec-transition.sh" seed-cap verified >/dev/null
            bash "$S/approval-log.sh" seed-cap --gate human_archive_approval --decision approve >/dev/null)
cat > "$T/.forge/specs/active/seed-cap/spec-delta.yaml" <<'EOF'
operations:
  - op: add_requirement
    capability: billing
    requirement_id: REQ-BIL-001
    requirement:
      id: REQ-BIL-001
      title: Issue invoice on order completion
      normative: SHALL
      scenarios:
        - id: SCN-BIL-001-A
          given: "a completed order"
          when: "the billing cycle runs"
          then: "an invoice is issued exactly once"
EOF
FORGE_ROOT="$T" bash "$S/archive-spec.sh" seed-cap >/dev/null

echo "[1] publish espelha baseline + lock"
FORGE_ROOT="$T" bash "$S/publish-docs.sh" >/dev/null
[ -f "$T/docs/product/capabilities/billing/spec.yaml" ]
[ -f "$T/docs/product/CHANGELOG.md" ]
[ -f "$T/docs/product/README.md" ]
[ -f "$T/.forge/cache/publish.lock" ]
grep -q 'docs/product/capabilities/billing/spec.yaml' "$T/.forge/cache/publish.lock"
echo "OK [1]"

echo "[2] validate-archive passa com publicação íntegra"
# new verified change to run the validator against (validator needs a change dir)
(cd "$T" && bash "$S/spec-new.sh" probe --type feature --scale 0 >/dev/null
            bash "$S/spec-transition.sh" probe tasks-ready >/dev/null
            bash "$S/spec-transition.sh" probe implementing >/dev/null)
perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$T/.forge/specs/active/probe/tasks.md"
(cd "$T" && bash "$S/spec-transition.sh" probe implemented >/dev/null
            bash "$S/spec-verify.sh" probe >/dev/null
            bash "$S/approval-log.sh" probe --gate implementation_verified --decision approve >/dev/null
            bash "$S/spec-transition.sh" probe verified >/dev/null
            bash "$S/approval-log.sh" probe --gate human_archive_approval --decision approve >/dev/null)
cat > "$T/.forge/specs/active/probe/spec-delta.yaml" <<'EOF'
operations:
  - op: add_requirement
    capability: billing
    requirement_id: REQ-BIL-002
    requirement:
      id: REQ-BIL-002
      title: Retry failed invoice issuance
      normative: SHOULD
EOF
FORGE_ROOT="$T" bash "$S/validate-archive.sh" probe >/dev/null
echo "OK [2]"

echo "[3] edição manual em docs/product → FAIL"
echo "edicao manual indevida" >> "$T/docs/product/capabilities/billing/spec.yaml"
set +e
out="$(FORGE_ROOT="$T" bash "$S/validate-archive.sh" probe 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && echo "$out" | grep -q 'without baseline origin'
echo "OK [3]"

echo "[4] re-publish cura o round-trip"
FORGE_ROOT="$T" bash "$S/publish-docs.sh" >/dev/null
FORGE_ROOT="$T" bash "$S/validate-archive.sh" probe >/dev/null
echo "OK [4]"

echo "[5] comandos de governança instalados"
for c in docs/publish-docs.md docs/adr.md docs/constitution.md docs/backlog.md; do
  [ -f "$T/.forge/commands/$c" ]
  head -5 "$T/.forge/commands/$c" | grep -q '^description:'
done
grep -q '/forge:adr new' "$T/.forge/commands/docs/new-adr.md"
echo "OK [5]"

echo "OK"
