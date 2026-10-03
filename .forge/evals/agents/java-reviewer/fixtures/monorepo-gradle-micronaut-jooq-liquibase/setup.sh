#!/usr/bin/env bash
# Monta a fixture do caso em $1: consumidor do forge-harness com o projeto Java commitado em develop
# (overlay/base) e o diff do PR commitado na branch feat/tarifa-integracao (overlay/change).
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$TARGET/"
# Ativa o capability pack Java no forge.yaml gerado pelo init.
sed -i.bak 's/^  active: \[\]$/  active: [backend-java-relational]/' "$TARGET/.forge/forge.yaml" && rm -f "$TARGET/.forge/forge.yaml.bak"
grep -q "active: \[backend-java-relational\]" "$TARGET/.forge/forge.yaml"

GIT=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
"${GIT[@]}" init -q -b develop
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "chore: estado inicial da fixture"
"${GIT[@]}" checkout -q -b feat/tarifa-integracao
cp -R "$HERE/overlay/change/." "$TARGET/"
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "feat: diff do PR em revisão"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
