#!/usr/bin/env bash
# Monta um consumidor do harness Node/TS + Postgres (pnpm) com o pack backend-node-postgres ativo.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
mkdir -p "$T"
node "$FORGE_BIN" init --target "$T" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$T/"
# Ativa somente o pack de Node/Postgres.
perl -0pi -e 's/(capabilities:\n(?:\s*#[^\n]*\n)*\s*active:) \[\]/$1 [backend-node-postgres]/' "$T/.forge/forge.yaml"
grep -q 'active: \[backend-node-postgres\]' "$T/.forge/forge.yaml"
git -C "$T" init -q
git -C "$T" add -A
git -C "$T" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: payments-api"
# Não contaminar o baseline: remove skills, agents e plugin do alvo.
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
