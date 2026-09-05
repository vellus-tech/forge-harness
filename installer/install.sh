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

# 4. managed-block patch (idempotent via markers + dedup por padrão) — .gitignore E .gitattributes
# compartilham o MESMO mecanismo: só acrescenta linhas ainda AUSENTES no alvo (um repo brownfield
# que já lista `.DS_Store`, ou já tem `merge=union` num path equivalente, não ganha entrada
# duplicada). Comentários, marcadores e linhas em branco do bloco são preservados; linhas de
# padrão já presentes verbatim são omitidas.
#
# O bloco RECONCILIA em vez de só ser acrescido. Append-once (o comportamento anterior do
# .gitignore) faz o bloco congelar na primeira escrita: quem já o tem nunca recebe padrão novo, e
# o harness passou a depender disso para entregar correções — o backup do update, o cache local e
# as negações do store do liaison ficavam presos no template. Bloco "managed" que congela não é
# gerenciado. O que está FORA dos marcadores é do usuário e não é tocado, inclusive para dedup.
_reconcile_managed_block() {  # _reconcile_managed_block <arquivo-alvo> <patch> <rótulo>
  local alvo="$1" patch="$2" rotulo="$3"
  local ini='# >>> forge (managed) >>>'
  local fim='# <<< forge (managed) <<<'
  touch "$alvo"
  local antes depois existing block
  antes="$(mktemp)"; depois="$(mktemp)"; existing="$(mktemp)"; block="$(mktemp)"
  local reconciliou
  if grep -qF "$ini" "$alvo" 2>/dev/null; then
    awk -v ini="$ini" 'index($0,ini){exit} {print}' "$alvo" > "$antes"
    awk -v fim="$fim" 'vis{print} index($0,fim){vis=1}' "$alvo" > "$depois"
    reconciliou=1
  else
    cat "$alvo" > "$antes"
    : > "$depois"
    reconciliou=0
  fi

  cat "$antes" "$depois" | grep -v '^[[:space:]]*#' | sed 's/[[:space:]]*$//' | grep -v '^[[:space:]]*$' | sort -u > "$existing" || true
  local in_block=0 line trimmed
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "$ini"*) in_block=1 ;;
    esac
    [ "$in_block" -eq 1 ] || continue
    trimmed="${line%"${line##*[![:space:]]}"}"   # rstrip
    if printf '%s' "$trimmed" | grep -qE '^[[:space:]]*(#|$)'; then
      printf '%s\n' "$line" >> "$block"           # comentário/marcador/branco: preserva
    elif grep -qxF "$trimmed" "$existing"; then
      :                                            # padrão já existe fora do bloco: pula (dedup)
    else
      printf '%s\n' "$line" >> "$block"
    fi
    case "$line" in
      "$fim"*) in_block=0 ;;
    esac
  done < "$patch"

  if [ "$reconciliou" -eq 1 ]; then
    cat "$antes" "$block" "$depois" > "$alvo"
    echo "$rotulo: forge block reconciled (dedup)"
  else
    { [ -s "$antes" ] && printf '\n'; cat "$block"; } >> "$alvo"
    echo "$rotulo: forge block appended (dedup)"
  fi
  rm -f "$antes" "$depois" "$existing" "$block"
}

_reconcile_managed_block "$TARGET/.gitignore" "$SCRIPT_DIR/gitignore.patch" "gitignore"
# .gitattributes (issue #80) — merge=union no log append-only do liaison, POR REMETENTE. O gate
# que detecta (post-merge) e bloqueia (pre-push) a duplicação — o único modo de falha do union —
# mora em .forge/scripts/check-liaison-log-integrity.sh; ver installer/gitattributes.patch.
_reconcile_managed_block "$TARGET/.gitattributes" "$SCRIPT_DIR/gitattributes.patch" "gitattributes"

# 5. git hooks path (only when target is a git repo) — ABSOLUTO, apontando para os hooks do
# CHECKOUT PRINCIPAL. core.hooksPath vive no .git/config, compartilhado por todos os worktrees, e
# um valor RELATIVO é resolvido por cada worktree contra a PRÓPRIA árvore — que carrega a cópia
# antiga dos hooks daquela branch. Um hook novo, versionado e mergeado, então não bloqueia nada em
# nenhum worktree ativo, e a única evidência disso é o commit proibido passando em silêncio.
# Paridade obrigatória com wireHooksPath() em bin/forge.mjs — projeto instalado por `curl | bash`
# não passa pelo outro caminho.
# Nunca sobrescreve um hooksPath customizado de verdade; o valor legado relativo
# `.forge/hooks/git` não conta como customizado (é nosso, e é o defeito) e é migrado.
if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  # dirname do .git COMUM = tronco. --path-format=absolute (git >= 2.31) porque, no próprio
  # checkout principal, --git-common-dir devolveria `.git` relativo. Degrada para --show-toplevel.
  MAIN_ROOT="$(git -C "$TARGET" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  case "$MAIN_ROOT" in
    /*) MAIN_ROOT="$(dirname "$MAIN_ROOT")" ;;
    *)  MAIN_ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || echo "$TARGET")" ;;
  esac
  WANT_HOOKS_PATH="$MAIN_ROOT/.forge/hooks/git"
  CUR_HOOKS_PATH="$(git -C "$TARGET" config --get core.hooksPath || true)"
  if [ "$CUR_HOOKS_PATH" = "$WANT_HOOKS_PATH" ]; then
    : # already correct, no-op
  elif [ -n "$CUR_HOOKS_PATH" ] && [ "$CUR_HOOKS_PATH" != ".forge/hooks/git" ]; then
    echo "git: core.hooksPath já customizado para '$CUR_HOOKS_PATH' — preservado (não sobrescrito)."
    echo "  Os hooks do Forge (.forge/hooks/git/*) não estão ativos; encadeie-os no seu hook"
    echo "  customizado se quiser o gate de pre-push de docs e o guard de pre-commit de worktree."
  elif [ "$CUR_HOOKS_PATH" = ".forge/hooks/git" ]; then
    git -C "$TARGET" config core.hooksPath "$WANT_HOOKS_PATH"
    echo "git: core.hooksPath '.forge/hooks/git' -> '$WANT_HOOKS_PATH' (absoluto — worktrees passam a rodar os hooks do tronco)"
  else
    git -C "$TARGET" config core.hooksPath "$WANT_HOOKS_PATH"
    echo "git: core.hooksPath -> $WANT_HOOKS_PATH"
  fi
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
  # red-first.yml — a execução de referência do replay roda num runner que o autor do PR não
  # controla (LDG-0004). Nunca sobrescreve: workflow existente é do projeto.
  if [ ! -f "$TARGET/.github/workflows/red-first.yml" ]; then
    cp "$SCRIPT_DIR/../template/github/workflows/red-first.yml" "$TARGET/.github/workflows/red-first.yml"
    echo "ci: red-first.yml installed (replays Red evidence on pull requests)"
  fi
fi

# 7. adapters — install ONLY the chosen set (default: claude); records them in forge.yaml
SYNC_ARGS=(--set "$ADAPTERS")
[ "$NO_SYMLINK" -eq 1 ] && SYNC_ARGS+=(--copy-links)
(cd "$TARGET" && bash .forge/scripts/sync-adapters.sh "${SYNC_ARGS[@]}")

echo "OK forge installed in $TARGET (slug: $SLUG, adapters: $ADAPTERS)"
