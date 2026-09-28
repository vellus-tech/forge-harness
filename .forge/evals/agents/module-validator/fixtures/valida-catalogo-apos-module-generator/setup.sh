#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness (projeto "Passe Urbano", bilhetagem com recarga) com DDD/TRD/Data Model/FRD/NFRD e catálogo de módulos da base comum, mais o overlay específico do caso.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/../_base-passe-urbano/overlay/." "$TARGET/"
if [ -d "$HERE/overlay" ]; then cp -R "$HERE/overlay/." "$TARGET/"; fi

git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
