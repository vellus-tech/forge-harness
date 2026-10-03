#!/usr/bin/env bash
# Fixture do eval 'c4-geracao-overview-projeto-ts' (skill c4-render). Uso: setup.sh <diretório-alvo>
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
mkdir -p "$T"
cp -R "$HERE/overlay/." "$T/"
node "$FORGE_BIN" init --target "$T" -y --no-plugin --name "Pagamentos Core" >/dev/null
# Remove já antes do commit para a árvore do alvo ficar limpa.
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
git -C "$T" init -q
git -C "$T" add -A
git -C "$T" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "chore: projeto pagamentos-core com harness Forge"
# Caminho principal: grafo AINDA não construído — o agente precisa garanti-lo antes do C4.
# Remove a skill/agentes do alvo para não contaminar o baseline.
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
