#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness + módulo rotativo com tasks.md já aprovado (v1.0.0, TASK-01..06 em andamento) e requirements/design revisados para incluir o cancelamento.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
# Base comum (ADRs, glossário, módulo rotativo) do caso principal; depois o delta deste caso por cima.
cp -R "$HERE/../planeja-tasks-rotativo-aprovado/overlay/." "$TARGET/"
cp -R "$HERE/overlay/." "$TARGET/"
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
