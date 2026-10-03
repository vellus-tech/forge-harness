#!/usr/bin/env bash
# Monta a fixture do caso em $1: consumidor do forge-harness com a base em develop e o diff em feature/cache-pagamentos.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
GIT=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$TARGET/"
git -C "$TARGET" init -q -b develop
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "chore: estado inicial do serviço de pagamentos"
git -C "$TARGET" checkout -q -b feature/cache-pagamentos
cp -R "$HERE/overlay/feature/." "$TARGET/"
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "feat(pagamentos): mudança sob revisão"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
