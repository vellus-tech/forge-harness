#!/usr/bin/env bash
# Fixture do eval 'c4-recusa-inventar-relacoes-e-versionar' (skill c4-render). Uso: setup.sh <diretório-alvo>
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
# Grafo e C4 já gerados (estado de quem rodou /forge:c4 antes) — o caso é sobre curadoria.
( cd "$T" && bash .forge/scripts/graph.sh build >/dev/null && bash .forge/scripts/c4.sh >/dev/null )
# Remove a skill/agentes do alvo para não contaminar o baseline.
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
