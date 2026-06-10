#!/usr/bin/env bats
# Claude adapter compatibility contract — structural asserts.
# Contract clauses: contracts/claude-adapter-contract.md
#
# Two modes (CLAUDE_CONTRACT_MODE):
#   source    (default) — runs against the frozen snapshot (reference state, W0.3 gate)
#   generated           — runs against a project where sync-adapters generated the Claude
#                         adapter (W1.2 gate). Functional equivalence, not identical layout:
#                         commands live in .claude/commands/forge/ + deprecated wrappers;
#                         rules/hooks/doctor live in .forge/** (referenced by path).
# CLAUDE_CONTRACT_TARGET overrides the target root.

setup() {
  MODE="${CLAUDE_CONTRACT_MODE:-source}"
  if [ "$MODE" = "generated" ]; then
    TARGET="${CLAUDE_CONTRACT_TARGET:?generated mode requires CLAUDE_CONTRACT_TARGET}"
    CMDS_DIR="$TARGET/.claude/commands/forge"
    WRAPPERS_DIR="$TARGET/.claude/commands"
    RULES_DIR="$TARGET/.forge/rules"
    HOOKS_DIR="$TARGET/.forge/hooks"
    SCRIPTS_DIR="$TARGET/.forge/scripts"
    HOOK_PATH_FRAGMENT='.forge/hooks/pre-tool-use/enforce-worktree-location.sh'
  else
    TARGET="${CLAUDE_CONTRACT_TARGET:-$BATS_TEST_DIRNAME/../../snapshot/project-bootstrap}"
    CMDS_DIR="$TARGET/.claude/commands"
    WRAPPERS_DIR=""
    RULES_DIR="$TARGET/.claude/rules"
    HOOKS_DIR="$TARGET/.claude/hooks"
    SCRIPTS_DIR="$TARGET/.claude/scripts"
    HOOK_PATH_FRAGMENT='.claude/hooks/pre-tool-use/enforce-worktree-location.sh'
  fi
  CLAUDE_DIR="$TARGET/.claude"
}

# ── C1 — commands ────────────────────────────────────────────────────────────

@test "C1: exactly 8 command files (README excluded)" {
  count=$(find "$CMDS_DIR" -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
  [ "$count" -eq 8 ]
}

@test "C1: the 8 contract command names all exist" {
  for cmd in run-spec-pipeline specs-loop coding-loop coding-status deploy-wave new-adr update-changelog scaffold-tdd; do
    found=$(find "$CMDS_DIR" -name "${cmd}.md" | wc -l | tr -d ' ')
    [ "$found" -eq 1 ]
  done
}

@test "C1: deprecated alias wrappers exist for all 8 commands (generated mode only)" {
  [ "$MODE" = "generated" ] || skip "source mode has no wrappers"
  for cmd in run-spec-pipeline specs-loop coding-loop coding-status deploy-wave new-adr update-changelog scaffold-tdd; do
    [ -f "$WRAPPERS_DIR/${cmd}.md" ]
    grep -q "DEPRECATED" "$WRAPPERS_DIR/${cmd}.md"
    grep -q "/forge:${cmd}" "$WRAPPERS_DIR/${cmd}.md"
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
  count=$(find "$RULES_DIR" -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
  [ "$count" -eq 27 ]
}

@test "C3: no stale .claude/ refs in canonical rules (generated mode only)" {
  [ "$MODE" = "generated" ] || skip "source mode keeps .claude refs by definition"
  count=$(grep -r '\.claude/' "$RULES_DIR" | wc -l | tr -d ' ')
  [ "$count" -eq 0 ]
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
    [ -f "$HOOKS_DIR/$hook" ]
  done
}

@test "C5: settings.json is valid JSON and wires ONLY the worktree-guard (PreToolUse/Bash)" {
  python3 -m json.tool "$CLAUDE_DIR/settings.json" >/dev/null
  grep -q "$HOOK_PATH_FRAGMENT" "$CLAUDE_DIR/settings.json"
  grep -q '"PreToolUse"' "$CLAUDE_DIR/settings.json"
  grep -q '"matcher": "Bash"' "$CLAUDE_DIR/settings.json"
  wired=$(grep -c '"command":' "$CLAUDE_DIR/settings.json")
  [ "$wired" -eq 1 ]
}

@test "C5: worktree-guard blocks outside the canonical worktree path (generated mode only)" {
  [ "$MODE" = "generated" ] || skip "behavioral check runs against generated tree"
  run bash -c "printf '%s' '{\"tool_input\":{\"command\":\"git worktree add /tmp/foo -b feat/x\"}}' | bash '$HOOKS_DIR/pre-tool-use/enforce-worktree-location.sh'"
  [ "$status" -eq 2 ]
  run bash -c "printf '%s' '{\"tool_input\":{\"command\":\"git worktree add .forge/worktrees/x -b feat/x\"}}' | bash '$HOOKS_DIR/pre-tool-use/enforce-worktree-location.sh'"
  [ "$status" -eq 0 ]
}

# ── C6 — doctor.sh ───────────────────────────────────────────────────────────

@test "C6: doctor.sh --help exits 0" {
  run bash "$SCRIPTS_DIR/doctor.sh" --help
  [ "$status" -eq 0 ]
}

@test "C6: doctor.sh rejects unknown argument with exit 2" {
  run bash "$SCRIPTS_DIR/doctor.sh" --bogus-flag
  [ "$status" -eq 2 ]
}

@test "C6: doctor.sh --report exits 0 when no stack detected" {
  run bash "$SCRIPTS_DIR/doctor.sh" --report
  [ "$status" -eq 0 ]
}

# ── C7/C8 — AGENTS.md projection + identity YAML ─────────────────────────────

@test "C7: CLAUDE.md resolves to AGENTS.md (generated mode only)" {
  [ "$MODE" = "generated" ] || skip "snapshot has no symlink chain (created by init)"
  for link in CLAUDE.md QWEN.md GEMINI.md; do
    [ -L "$TARGET/$link" ] || [ -f "$TARGET/$link" ]
    if [ -L "$TARGET/$link" ]; then
      [ "$(readlink "$TARGET/$link")" = "AGENTS.md" ]
    else
      head -1 "$TARGET/$link" | grep -q 'Generated from .forge/FORGE.md'
    fi
  done
}

@test "C8: AGENTS.md has the 7 identity fields in YAML frontmatter" {
  agents_md="$TARGET/AGENTS.md"
  [ -f "$agents_md" ]
  for field in project_name project_display repo_slug default_branch jira_key jira_site issuer; do
    grep -Eq "^${field}:" "$agents_md"
  done
}

@test "C8: generated AGENTS.md carries the generated-file header (§7.4) (generated mode only)" {
  [ "$MODE" = "generated" ] || skip "snapshot AGENTS.md is hand-maintained"
  head -1 "$TARGET/AGENTS.md" | grep -q 'Generated from .forge/FORGE.md'
}

# ── C9 — .gitignore ──────────────────────────────────────────────────────────

@test "C9: .gitignore covers local settings, cache and worktrees" {
  [ "$MODE" = "source" ] || skip "installed by /forge:init (W1.3) — validated there"
  gi="$TARGET/.gitignore"
  [ -f "$gi" ]
  grep -q 'settings.local.json' "$gi"
  grep -q 'cache' "$gi"
  grep -q 'worktrees' "$gi"
}
