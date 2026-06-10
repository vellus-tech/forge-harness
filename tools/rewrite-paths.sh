#!/usr/bin/env bash
# W1.1 — deterministic path/namespace rewrite over the canonical source (template/.forge).
# Scope (docs/plans/01 v1.1):
#   - ONLY project-relative `.claude/*` refs are rewritten to `.forge/*` (290 in inventory).
#   - `docs/product/` refs are intentionally PRESERVED in MVP1 (compatibility contract §22.1;
#     baseline rule §8.1). Their semantic migration happens in MVP2 (W2.1) and MVP3 (W3.3).
#   - User-global `~/.claude/` refs: `~/.claude/CLAUDE.md` (AI co-authorship rule) maps to
#     `.forge/constitution.md` (rule #8 lives there now); any other user-global ref is preserved.
#   - Slash-command invocations move to the /forge:* namespace (#7): /coding-loop → /forge:coding-loop.
#     File names do NOT change; the Claude adapter materializes the namespace (W1.2).
# Idempotent: running twice produces no further changes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-$ROOT/template/.forge}"

[ -d "$TARGET" ] || { echo "FAIL (target not found: $TARGET)"; exit 1; }

count=0
while IFS= read -r -d '' f; do
  perl -0pi -e '
    # 1) semantic map: user-global co-authorship rule now lives in the constitution
    s{~/\.claude/CLAUDE\.md}{.forge/constitution.md}g;
    # 2) protect remaining user-global refs from the generic rewrite
    s{~/\.claude/}{\x00HOME_CLAUDE\x00}g;
    s{\$HOME/\.claude/}{\x00HOME_CLAUDE_VAR\x00}g;
    # 3) project-relative .claude → .forge
    s{\.claude/}{.forge/}g;
    # 4) restore protected user-global refs
    s{\x00HOME_CLAUDE\x00}{~/.claude/}g;
    s{\x00HOME_CLAUDE_VAR\x00}{\$HOME/.claude/}g;
    # 5) slash-command namespace: /cmd → /forge:cmd (invocations only — a path segment is
    #    preceded by an alnum char and does not match; already-namespaced text is stable)
    s{(^|[^/\w:-])/(run-spec-pipeline|specs-loop|coding-loop|coding-status|deploy-wave|new-adr|update-changelog|scaffold-tdd)\b}{$1/forge:$2}g;
  ' "$f"
  count=$((count + 1))
done < <(find "$TARGET" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' \) -print0)

echo "OK rewrite applied to $count files under $TARGET"
