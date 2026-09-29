#!/usr/bin/env bash
# Monta a fixture do caso em $1: consumidor do forge-harness + overlay do projeto.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
GITC=(-c user.name=eval -c user.email=eval@example.invalid -c core.hooksPath=/dev/null)
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$TARGET/"
# Remove skills e agentes ANTES do commit: senão qualquer worktree criada a partir do HEAD os traria de volta.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
git -C "$TARGET" init -q -b main
git -C "$TARGET" add -A
git -C "$TARGET" "${GITC[@]}" commit -q -m "chore: estado inicial da fixture"
git -C "$TARGET" rev-parse HEAD > "$TARGET/.git/eval-main-sha"
# Garantia final: nada de skills/agentes no alvo (não contaminar o baseline).
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
