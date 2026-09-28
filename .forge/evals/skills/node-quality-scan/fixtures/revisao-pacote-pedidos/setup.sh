#!/usr/bin/env bash
# Monta um monorepo consumidor do harness (loja-monorepo) com dois pacotes: packages/notificacoes
# (fora do escopo, com violações próprias já em main) e packages/pedidos, alterado na branch
# feat/listagem-pedidos. A camada de lint (node-baseline --apply) já está materializada e commitada.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../../../../.." && pwd)"
mkdir -p "$T"
node "$REPO_ROOT/bin/forge.mjs" init --target "$T" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$T/"
bash "$T/.forge/scripts/node-baseline.sh" --root "$T" --apply >/dev/null
CLEAN=("$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin")
rm -rf "${CLEAN[@]}"
G=(git -C "$T" -c user.name=eval -c user.email=eval@example.invalid)
"${G[@]}" init -q -b main
"${G[@]}" add -A
"${G[@]}" commit -qm "chore: monorepo loja com pedidos e notificacoes"
"${G[@]}" checkout -q -b feat/listagem-pedidos
cp -R "$HERE/overlay/change/." "$T/"
"${G[@]}" add -A
"${G[@]}" commit -qm "feat(pedidos): listagem por status e nota fiscal"
rm -rf "${CLEAN[@]}"
