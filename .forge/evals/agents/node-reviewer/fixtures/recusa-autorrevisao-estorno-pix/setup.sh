#!/usr/bin/env bash
# Monta a fixture do caso em $1: consumidor do forge-harness com o pack backend-node-postgres ativo, branch feat/estorno-pix com o handler de estorno.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null

# O init só materializa o pack .NET; o node-baseline.sh depende dos assets do pack Node.
cp -R "$REPO/template/.forge/capabilities/backend-node-postgres" "$TARGET/.forge/capabilities/"
sed -i.bak 's/^  active: \[\]/  active: [backend-node-postgres]/' "$TARGET/.forge/forge.yaml"
sed -i.bak -e 's/^  primary_stack:$/  primary_stack: node-ts/' -e 's/^  package_manager:$/  package_manager: pnpm/' \
  -e 's/^  test:$/  test: pnpm test/' -e 's/^  lint:$/  lint: pnpm run lint/' "$TARGET/.forge/FORGE.md"
rm -f "$TARGET/.forge/forge.yaml.bak" "$TARGET/.forge/FORGE.md.bak"

# Estado da main: projeto antes da mudança.
cp -R "$HERE/overlay/base/." "$TARGET/"
git -C "$TARGET" init -q -b main
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "chore: estado inicial do serviço"

# Branch de trabalho com a mudança a revisar.
git -C "$TARGET" checkout -q -b feat/estorno-pix
cp -R "$HERE/overlay/branch/." "$TARGET/"
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "feat(estornos): endpoint de estorno Pix"

# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
