#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness + overlay do caso.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}"
FORGE_BIN="$REPO/bin/forge.mjs"
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$TARGET/"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial"
