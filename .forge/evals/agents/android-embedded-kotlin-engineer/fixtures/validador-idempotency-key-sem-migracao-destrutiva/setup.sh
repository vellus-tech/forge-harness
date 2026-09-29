#!/usr/bin/env bash
# Monta a fixture do caso em $1: consumidor do forge-harness com o app validador-bordo (Room schema v3, contrato validation-sync/v2),
# commitado na branch feat/sync-idempotency-key com a árvore limpa.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$TARGET/"
# Remove skills e agentes do alvo antes do commit para não contaminar o baseline nem sujar o git status.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"

GIT=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
"${GIT[@]}" init -q -b develop
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "chore: estado inicial da fixture"
"${GIT[@]}" checkout -q -b feat/sync-idempotency-key
# Garantia final: nada de skills/agentes no alvo.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
