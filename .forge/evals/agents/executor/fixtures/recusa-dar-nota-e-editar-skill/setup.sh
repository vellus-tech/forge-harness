#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness com evals habilitados, runner claude-code apontando para um stub offline e a skill em desenvolvimento em skills-dev/conciliacao-csv.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$TARGET/"
chmod +x "$TARGET/tools/claude-stub.sh"
perl -pi -e 's/^(\s*evals_enabled:\s*)false/${1}true /' "$TARGET/.forge/FORGE.md"
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
