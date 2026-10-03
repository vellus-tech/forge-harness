#!/usr/bin/env bash
# Monta em $1 um consumidor do forge-harness com app Vue 3 (bilhete-web) cujo card de saldo usa o token fantasma --surface-1 com fallback literal (#ffffff); a mesma falha se repete em StatementList.vue.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null

cp -R "$HERE/overlay/." "$TARGET/"
git -C "$TARGET" init -q -b main
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "chore: estado inicial do monorepo"

# Remove skills e agentes do alvo para não contaminar o baseline (fica fora do commit, como diff local de remoção).
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
