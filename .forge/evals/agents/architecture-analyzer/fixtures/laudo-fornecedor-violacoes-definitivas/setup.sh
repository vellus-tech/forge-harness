#!/usr/bin/env bash
# Monta a fixture do caso em $1: consumidor do forge-harness + overlay do projeto TypeScript + graph.json construído.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$TARGET/"
# O projeto do fornecedor não tem regra de camadas: sem .forge/rules/architecture/ não há como confirmar violação.
rm -rf "$TARGET/.forge/rules/architecture"

git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "chore: estado inicial da fixture"
# O agente opera sobre um graph.json já construído (contrato do artefato): constrói aqui, de forma determinista.
bash "$TARGET/.forge/scripts/graph.sh" build >/dev/null
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
