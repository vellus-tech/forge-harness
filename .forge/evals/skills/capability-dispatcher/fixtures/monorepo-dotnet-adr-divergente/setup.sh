#!/usr/bin/env bash
# Monta um monorepo consumidor do harness: billing-api (.NET + Dapper + DbUp) e web/checkout (Node/TS),
# com os packs backend-dotnet-relational e backend-node-postgres ativos e duas ADRs que divergem dos defaults do pack .NET.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
mkdir -p "$T"
node "$FORGE_BIN" init --target "$T" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$T/"
perl -0pi -e 's/(capabilities:\n(?:\s*#[^\n]*\n)*\s*active:) \[\]/$1 [backend-dotnet-relational, backend-node-postgres]/' "$T/.forge/forge.yaml"
grep -q 'active: \[backend-dotnet-relational, backend-node-postgres\]' "$T/.forge/forge.yaml"
git -C "$T" init -q
git -C "$T" add -A
git -C "$T" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: monorepo billing"
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
