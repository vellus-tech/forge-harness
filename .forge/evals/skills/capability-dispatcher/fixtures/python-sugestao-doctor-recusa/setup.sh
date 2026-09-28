#!/usr/bin/env bash
# Monta um consumidor do harness Python (Flask + psycopg + yoyo) SEM pack ativo, com a saída do doctor sugerindo backend-python-relational.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
mkdir -p "$T"
node "$FORGE_BIN" init --target "$T" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$T/"
grep -q 'active: \[\]' "$T/.forge/forge.yaml"
git -C "$T" init -q
git -C "$T" add -A
git -C "$T" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: fleet-api"
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
