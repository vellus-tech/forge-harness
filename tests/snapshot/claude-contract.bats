#!/usr/bin/env bats
# Claude adapter compatibility contract — structural asserts (W0.3).
# Runs against the frozen snapshot by default; the W1.2 gate re-runs it with
# CLAUDE_CONTRACT_TARGET pointing at the generated adapter output.
# Contract clauses: contracts/claude-adapter-contract.md

setup() {
  TARGET="${CLAUDE_CONTRACT_TARGET:-$BATS_TEST_DIRNAME/../../snapshot/project-bootstrap}"
  CLAUDE_DIR="$TARGET/.claude"
}

# ── C1 — commands ────────────────────────────────────────────────────────────

@test "C1: exactly 8 command files (README excluded)" {
  count=$(find "$CLAUDE_DIR/commands" -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
  [ "$count" -eq 8 ]
}

@test "C1: the 8 contract command names all exist" {
  for cmd in run-spec-pipeline specs-loop coding-loop coding-status deploy-wave new-adr update-changelog scaffold-tdd; do
    found=$(find "$CLAUDE_DIR/commands" -name "${cmd}.md" | wc -l | tr -d ' ')
    [ "$found" -eq 1 ]
  done
}

# ── C2 — agents ──────────────────────────────────────────────────────────────

@test "C2: exactly 35 agent files (README excluded)" {
  count=$(find "$CLAUDE_DIR/agents" -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
  [ "$count" -eq 35 ]
}

@test "C2: agent counts per category (15/6/6/4/3/1)" {
  [ "$(find "$CLAUDE_DIR/agents/specifications" -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')" -eq 15 ]
  [ "$(find "$CLAUDE_DIR/agents/architecture"   -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')" -eq 6 ]
  [ "$(find "$CLAUDE_DIR/agents/review"         -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')" -eq 6 ]
  [ "$(find "$CLAUDE_DIR/agents/engineering"    -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')" -eq 4 ]
  [ "$(find "$CLAUDE_DIR/agents/coding"         -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')" -eq 3 ]
  [ "$(find "$CLAUDE_DIR/agents/code-review"    -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')" -eq 1 ]
}

# ── C3 — rules ───────────────────────────────────────────────────────────────

@test "C3: exactly 27 rule files (README excluded)" {
  count=$(find "$CLAUDE_DIR/rules" -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
  [ "$count" -eq 27 ]
}

# ── C4 — skills ──────────────────────────────────────────────────────────────

@test "C4: exactly 4 skills, expected names" {
  count=$(find "$CLAUDE_DIR/skills" -name 'SKILL.md' | wc -l | tr -d ' ')
  [ "$count" -eq 4 ]
  for skill in design-system-creator using-git-worktrees verify-build verify-diff-claims; do
    [ -f "$CLAUDE_DIR/skills/$skill/SKILL.md" ]
  done
}

# ── C5 — hooks ───────────────────────────────────────────────────────────────

@test "C5: the 5 hook scripts exist" {
  for hook in pre-tool-use/check-language-policy.sh \
              pre-tool-use/enforce-worktree-location.sh \
              pre-tool-use/prevent-secrets-leak.sh \
              pre-tool-use/validate-naming-conventions.sh \
              pre-commit/check-dockerfile-multiarch.sh; do
    [ -f "$CLAUDE_DIR/hooks/$hook" ]
  done
}

@test "C5: settings.json is valid JSON and wires enforce-worktree-location (PreToolUse/Bash)" {
  python3 -m json.tool "$CLAUDE_DIR/settings.json" >/dev/null
  grep -q 'enforce-worktree-location.sh' "$CLAUDE_DIR/settings.json"
  grep -q '"PreToolUse"' "$CLAUDE_DIR/settings.json"
  grep -q '"matcher": "Bash"' "$CLAUDE_DIR/settings.json"
}

# ── C6 — doctor.sh ───────────────────────────────────────────────────────────

@test "C6: doctor.sh --help exits 0" {
  run bash "$CLAUDE_DIR/scripts/doctor.sh" --help
  [ "$status" -eq 0 ]
}

@test "C6: doctor.sh rejects unknown argument with exit 2" {
  run bash "$CLAUDE_DIR/scripts/doctor.sh" --bogus-flag
  [ "$status" -eq 2 ]
}

@test "C6: doctor.sh --report exits 0 when no stack detected (snapshot has no stack markers)" {
  run bash "$CLAUDE_DIR/scripts/doctor.sh" --report
  [ "$status" -eq 0 ]
}

# ── C8 — identity YAML ───────────────────────────────────────────────────────

@test "C8: AGENTS.md has the 7 identity fields in YAML frontmatter" {
  agents_md="$TARGET/AGENTS.md"
  [ -f "$agents_md" ]
  for field in project_name project_display repo_slug default_branch jira_key jira_site issuer; do
    grep -Eq "^${field}:" "$agents_md"
  done
}

# ── C9 — .gitignore ──────────────────────────────────────────────────────────

@test "C9: .gitignore covers local settings, cache and worktrees" {
  gi="$TARGET/.gitignore"
  [ -f "$gi" ]
  grep -q 'settings.local.json' "$gi"
  grep -q 'cache' "$gi"
  grep -q 'worktrees' "$gi"
}
