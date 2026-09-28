#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness recém-instalado + overlay com o código do projeto.
# O artefato sob avaliação (agente data-streaming e skill data-streaming-practices) e os adapters são removidos
# antes do commit, para que o baseline rode sem eles; a rodada com o artefato os instala por cima.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}"
FORGE_BIN="${FORGE_BIN:-$REPO/bin/forge.mjs}"
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$TARGET/"
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial"
