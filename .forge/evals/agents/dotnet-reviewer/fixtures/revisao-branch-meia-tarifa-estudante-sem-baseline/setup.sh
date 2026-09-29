#!/usr/bin/env bash
# Monta a fixture em $1: consumidor do forge-harness com a solução TarifaApi em main (sem baseline de build) e a branch feature/meia-tarifa-estudante com o diff sob revisão.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
GIT=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$TARGET/"
git -C "$TARGET" init -q -b main
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "chore: estado inicial do TarifaApi"
"${GIT[@]}" checkout -q -b feature/meia-tarifa-estudante
cp -R "$HERE/overlay/branch/." "$TARGET/"
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "feat(tarifa): meia-tarifa para estudante com consulta ao SGE"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
