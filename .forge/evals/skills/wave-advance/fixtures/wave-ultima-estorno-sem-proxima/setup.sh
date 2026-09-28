#!/usr/bin/env bash
# Monta a fixture do caso em $1: consumidor do forge-harness + overlay do projeto + gate declarado.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$TARGET/"
# Declara o gate de wave (runtime.gates: CSV escalar, fase source) no FORGE.md gerado pelo init.
perl -0pi -e 's/\n  gates:[ \t]*\n/\n  gates: check-unit\n/' "$TARGET/.forge/FORGE.md"
grep -q '^  gates: check-unit$' "$TARGET/.forge/FORGE.md" || { echo "setup: falhou ao declarar runtime.gates" >&2; exit 1; }
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "chore: estado inicial da fixture"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
