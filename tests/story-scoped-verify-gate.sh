#!/usr/bin/env bash
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-story-verify.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
mkdir -p "$T/.forge/specs/active/demo/stories"
printf '%s\n' '---' 'runtime:' '  test: "true"' '---' > "$T/.forge/FORGE.md"
printf '%s\n' 'status: implementing' 'type: feature' > "$T/.forge/specs/active/demo/manifest.yaml"
printf '%s\n' '## Wave 1' '- [X] TASK-01 — feita (rastreia: REQ-01; paths: src/a; depende: —)' '## Wave 2' '- [ ] TASK-02 — pendente (rastreia: REQ-01; paths: src/b; depende: TASK-01)' > "$T/.forge/specs/active/demo/tasks.md"
cat > "$T/.forge/specs/active/demo/stories/STORY-01.md" <<'STORY'
---
story_id: STORY-01
status: in_progress
depends_on: []
---
- [X] TASK-01 — feita
STORY
cat > "$T/.forge/specs/active/demo/stories/STORY-02.md" <<'STORY'
---
story_id: STORY-02
status: todo
depends_on: [STORY-01]
---
- [ ] TASK-02 — pendente
STORY
printf 'global sentinel\n' > "$T/.forge/specs/active/demo/verification.yaml"
out="$(FORGE_ROOT="$T" bash "$WS/template/.forge/scripts/spec-verify.sh" demo --story STORY-01 2>&1)" || { echo "FAIL completed story must pass despite other open tasks: $out"; exit 1; }
[ "$(cat "$T/.forge/specs/active/demo/verification.yaml")" = 'global sentinel' ] || { echo 'FAIL story must not overwrite global verification'; exit 1; }
[ -f "$T/.forge/specs/active/demo/stories/STORY-01.verification.yaml" ] || { echo 'FAIL story evidence missing'; exit 1; }
echo 'PASS story checkpoint preserves global verification'
if global_out="$(FORGE_ROOT="$T" bash "$WS/template/.forge/scripts/spec-verify.sh" demo 2>&1)"; then echo 'FAIL global verify ignored open task'; exit 1; fi
grep -q '1 open task' <<<"$global_out" || { echo "FAIL wrong global rejection: $global_out"; exit 1; }
printf 'global sentinel\n' > "$T/.forge/specs/active/demo/verification.yaml"

expect_fail() { if out="$(FORGE_ROOT="$T" bash "$WS/template/.forge/scripts/spec-verify.sh" demo "$@" 2>&1)"; then echo "FAIL expected rejection: $*"; exit 1; fi; }
expect_fail --story STORY-02
expect_fail --story STORY-99
expect_fail --story ../STORY-01
expect_fail --bogus STORY-01
perl -pi -e 's/\[X\] TASK-01/[ ] TASK-01/' "$T/.forge/specs/active/demo/tasks.md"
expect_fail --story STORY-01
[ ! -f "$T/.forge/specs/active/demo/stories/STORY-01.verification.yaml" ] || { echo "FAIL stale receipt"; exit 1; }
perl -pi -e 's/\[ \] TASK-01/[X] TASK-01/' "$T/.forge/specs/active/demo/tasks.md"
perl -pi -e 's/status: todo/status: in_progress/' "$T/.forge/specs/active/demo/stories/STORY-02.md"
perl -pi -e 's/\[ \] TASK-02/[X] TASK-02/' "$T/.forge/specs/active/demo/tasks.md"
expect_fail --story STORY-02
perl -pi -e 's/status: in_progress/status: done/' "$T/.forge/specs/active/demo/stories/STORY-01.md"
FORGE_ROOT="$T" bash "$WS/template/.forge/scripts/spec-verify.sh" demo --story STORY-02 >/dev/null
perl -pi -e 's/depends_on: \[STORY-01\]/depends_on: []/' "$T/.forge/specs/active/demo/stories/STORY-02.md"
expect_fail --story STORY-02
perl -pi -e 's/depends_on: \[\]/depends_on: [STORY-01]/' "$T/.forge/specs/active/demo/stories/STORY-02.md"
perl -pi -e 's/test: "true"/test: "false"/' "$T/.forge/FORGE.md"
expect_fail --story STORY-02
grep -q 'status: "failed"' "$T/.forge/specs/active/demo/stories/STORY-02.verification.yaml"
[ "$(cat "$T/.forge/specs/active/demo/verification.yaml")" = 'global sentinel' ] || { echo 'FAIL global evidence modified'; exit 1; }
echo 'PASS story rejection and failed runtime checks'
