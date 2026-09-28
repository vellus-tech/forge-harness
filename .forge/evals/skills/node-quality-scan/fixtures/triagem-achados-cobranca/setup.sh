#!/usr/bin/env bash
# Monta o consumidor servico-cobranca (Fastify + pg), sem eslint.config.* (camada de lint ausente),
# com achados do scanner que são exceção legítima (pool no bootstrap, readFileSync no boot, porta
# hexagonal de implementação única, .then/.catch em linhas separadas) e um defeito real (SQL
# interpolado em PgCobrancaRepository.marcarPaga).
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../../../../.." && pwd)"
mkdir -p "$T"
node "$REPO_ROOT/bin/forge.mjs" init --target "$T" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$T/"
CLEAN=("$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin")
rm -rf "${CLEAN[@]}"
G=(git -C "$T" -c user.name=eval -c user.email=eval@example.invalid)
"${G[@]}" init -q -b main
"${G[@]}" add -A
"${G[@]}" commit -qm "feat: servico-cobranca 2.3.1"
rm -rf "${CLEAN[@]}"
