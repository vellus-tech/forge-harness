#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness (projeto "Tarifa Viva", bilhetagem de ônibus) com PRD/FRD/NFRD/TRD da base comum e o overlay específico do caso.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
# Identidade conhecida para a asserção do título do index.html (bootstrap de identidade via bloco YAML do AGENTS.md).
perl -pi -e 's/^project_name: .*/project_name: tarifa-viva/; s/^project_display: .*/project_display: Tarifa Viva/' "$TARGET/AGENTS.md"
cp -R "$HERE/../_base-tarifa-viva/overlay/." "$TARGET/"
if [ -d "$HERE/overlay" ]; then cp -R "$HERE/overlay/." "$TARGET/"; fi
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
