#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness com evals habilitado + entrada anonimizada do comparator no workspace da iteração.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$TARGET/"
# Liga a camada opt-in de evals no FORGE.md do consumidor, se a chave existir.
if [ -f "$TARGET/.forge/FORGE.md" ]; then
  sed -i.bak 's/evals_enabled: false/evals_enabled: true/' "$TARGET/.forge/FORGE.md" && rm -f "$TARGET/.forge/FORGE.md.bak"
fi
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
