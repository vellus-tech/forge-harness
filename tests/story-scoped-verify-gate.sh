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
printf '%s\n' '## Wave 1' '- [X] TASK-01 — feita' '## Wave 2' '- [ ] TASK-02 — pendente' > "$T/.forge/specs/active/demo/tasks.md"
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
