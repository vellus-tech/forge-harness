#!/usr/bin/env bash
# Forge installer — mechanical part of /forge:init (W1.3). Deterministic; the interactive
# part (metadata elicitation, stack scan, runtime: fill) is the agent command forge-init.md.
#
# Usage: install.sh --target <dir> [--source <template/.forge dir>]
#                   [--slug <kebab>] [--name <display>] [--desc <one-line>]
#                   [--adapters <a,b,...>] [--force] [--no-symlink]
#   --adapters: comma list of agents to install (default: claude). Only these are materialized
#     and recorded as the active set in forge.yaml; others stay available for later via
#     /forge:sync-adapters --set. This is what keeps the workspace from being polluted with
#     adapters the project does not use (the agent command forge-init.md elicits this list).
# Behavior:
#   - Overwrite guard: if <target>/.forge exists and no --force → exit 3, nothing touched.
#     With --force → previous tree moved to .forge.bak-N (no data loss).
#   - Placeholders: only UPPERCASE <PROJECT_SLUG>/<PROJECT_NAME>/<PROJECT_DESCRIPTION> are
#     replaced (same policy as init-project); lowercase <project_name> placeholders are
#     runtime-resolved by agents via the identity block.
#   - Applies gitignore.patch (idempotent, marker-delimited), configures git hooksPath when
#     the target is a git repo, then runs sync-adapters (claude).
# Output: progress lines + final "OK ..." or "FAIL (...)".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$(cd "$SCRIPT_DIR/../template/.forge" 2>/dev/null && pwd || true)"
TARGET="" SLUG="" NAME="" DESC="" ADAPTERS="claude" FORCE=0 NO_SYMLINK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --source) SOURCE="$(cd "$2" && pwd)"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --desc) DESC="$2"; shift 2 ;;
    --adapters) ADAPTERS="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --no-symlink) NO_SYMLINK=1; shift ;;
    *) echo "FAIL (unknown argument: $1)"; exit 2 ;;
  esac
done

[ -n "$TARGET" ] || { echo "FAIL (--target is required)"; exit 2; }
[ -n "$SOURCE" ] && [ -f "$SOURCE/FORGE.md" ] || { echo "FAIL (template source not found: $SOURCE)"; exit 1; }
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

# defaults derived from the target directory (init-project policy)
[ -n "$SLUG" ] || SLUG="$(basename "$TARGET" | tr '[:upper:] ' '[:lower:]-')"
[ -n "$NAME" ] || NAME="$SLUG"
[ -n "$DESC" ] || DESC="Projeto $NAME"

# 1. overwrite guard
if [ -d "$TARGET/.forge" ]; then
  if [ "$FORCE" -eq 0 ]; then
    echo "FAIL (.forge already exists in $TARGET — re-run with --force to back up and overwrite)"
    exit 3
  fi
  n=1; while [ -e "$TARGET/.forge.bak-$n" ]; do n=$((n + 1)); done
  mv "$TARGET/.forge" "$TARGET/.forge.bak-$n"
  echo "backup: previous .forge moved to .forge.bak-$n"
fi

# 2. install canonical tree
cp -R "$SOURCE" "$TARGET/.forge"
find "$TARGET/.forge" -name '.DS_Store' -delete 2>/dev/null || true

# 3. placeholders (UPPERCASE only) across the installed tree — EXCEPT .forge/templates/,
# whose files are templates for future artifacts and must keep their placeholders
SLUG="$SLUG" NAME="$NAME" DESC="$DESC" find "$TARGET/.forge" -type f \( -name '*.md' -o -name '*.yaml' -o -name '*.yml' \) ! -path '*/templates/*' -exec \
  perl -pi -e 's/<PROJECT_SLUG>/$ENV{SLUG}/g; s/<PROJECT_NAME>/$ENV{NAME}/g; s/<PROJECT_DESCRIPTION>/$ENV{DESC}/g; s/<INSTALLED_AT>/installed/g' {} +

# grep exits 1 on no-match; with pipefail that would kill the assignment — tolerate it
orphans=$(grep -rl '<PROJECT_[A-Z_]*>' "$TARGET/.forge" 2>/dev/null | grep -v '/templates/' | wc -l | tr -d ' ' || true)
[ "$orphans" -eq 0 ] || { echo "FAIL ($orphans files still carry <PROJECT_*> placeholders)"; exit 1; }

# 4. gitignore patch (idempotent via markers)
GI="$TARGET/.gitignore"
if ! grep -q '# >>> forge (managed) >>>' "$GI" 2>/dev/null; then
  cat "$SCRIPT_DIR/gitignore.patch" >> "$GI"
  echo "gitignore: forge block appended"
fi

# 5. git hooks path (only when target is a git repo)
if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$TARGET" config core.hooksPath .forge/hooks/git
  echo "git: core.hooksPath -> .forge/hooks/git"
else
  echo "git: not a repository — hooks not configured (run 'git init' + re-run doctor)"
fi

# 6. CI workflow (§20.2) — only when the repo uses GitHub Actions layout or asks for it
if [ -d "$TARGET/.github" ] || [ -d "$TARGET/.git" ]; then
  mkdir -p "$TARGET/.github/workflows"
  if [ ! -f "$TARGET/.github/workflows/staging.yml" ]; then
    cp "$SCRIPT_DIR/../template/github/workflows/staging.yml" "$TARGET/.github/workflows/staging.yml"
    echo "ci: staging.yml installed (runs only on push to staging)"
  fi
fi

# 7. adapters — install ONLY the chosen set (default: claude); records them in forge.yaml
SYNC_ARGS=(--set "$ADAPTERS")
[ "$NO_SYMLINK" -eq 1 ] && SYNC_ARGS+=(--copy-links)
(cd "$TARGET" && bash .forge/scripts/sync-adapters.sh "${SYNC_ARGS[@]}")

echo "OK forge installed in $TARGET (slug: $SLUG, adapters: $ADAPTERS)"
