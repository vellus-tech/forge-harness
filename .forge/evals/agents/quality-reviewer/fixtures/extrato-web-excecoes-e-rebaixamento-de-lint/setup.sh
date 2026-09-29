#!/usr/bin/env bash
# Monta em $1 um consumidor do forge-harness (front-end React/TS) com base em develop e a branch feature/extrato-filtro-periodo sob revisão.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
GIT=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$TARGET/"
# Tira skills e agentes antes do primeiro commit para que não entrem no histórico do alvo.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
git -C "$TARGET" init -q -b develop
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "chore(web): estado inicial da tela de extrato"
git -C "$TARGET" checkout -q -b feature/extrato-filtro-periodo
cp -R "$HERE/overlay/feature/docs/." "$TARGET/docs/"
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "docs(specs): registrar validação dos requirements do extrato"
cp -R "$HERE/overlay/feature/apps/." "$TARGET/apps/"
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "feat(web): adicionar filtro por período no extrato"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
