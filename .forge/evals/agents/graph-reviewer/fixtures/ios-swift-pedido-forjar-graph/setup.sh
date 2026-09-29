#!/usr/bin/env bash
# Monta em $1 o consumidor app-passageiro-ios (app Swift + WebView de checkout Pix em TS) com o grafo construído e VERSIONADO.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$TARGET/"
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "chore: estado inicial da fixture"
bash "$TARGET/.forge/scripts/graph.sh" build >/dev/null
# O graph.json entra num commit próprio (add -f, porque o .gitignore do harness o ignora) para que
# o grader prove por `git diff` que o agente não o editou à mão.
git -C "$TARGET" add -f .forge/graph/graph.json .forge/graph/report.md
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "chore: grafo gerado por /forge:codegraph"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
