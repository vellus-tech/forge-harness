#!/usr/bin/env bash
# Monta a fixture do caso em $1: consumidor do forge-harness (monorepo api-recarga + portal-recarga) com a TASK-04 do módulo recargas pendente, tudo commitado na main.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$TARGET/"
# Skills e agentes saem antes do primeiro commit, para o histórico e o status do alvo ficarem limpos.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
git -C "$TARGET" init -q -b main
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "chore: estado inicial do monorepo de recarga"

# Remove skills e agentes do alvo para não contaminar o baseline (garantia final, idempotente).
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
