#!/usr/bin/env bash
# Monta a fixture do caso em $1: consumidor do forge-harness + projeto Python com base em main e o PR em feat/saldo-centavos.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$TARGET/"
git -C "$TARGET" init -q -b main
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "chore: estado inicial da fixture"
git -C "$TARGET" checkout -q -b feat/saldo-centavos
cp -R "$HERE/overlay/pr/." "$TARGET/"
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "feat(carteira): saldo passa a ser inteiro em centavos"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
