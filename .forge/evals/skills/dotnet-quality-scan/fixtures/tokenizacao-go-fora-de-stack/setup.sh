#!/usr/bin/env bash
# Monta um consumidor do harness cuja única stack é Go (serviço de tokenização de PAN). Não há
# nenhum .cs, .csproj ou .sln: o scanner .NET rodaria verde por ausência de alvo.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
mkdir -p "$T"
node "$FORGE_BIN" init --target "$T" -y --no-plugin >/dev/null
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
cp -R "$HERE/overlay/." "$T/"
G=(git -C "$T" -c user.name=eval -c user.email=eval@example.invalid)
"${G[@]}" init -q -b main
"${G[@]}" add -A
"${G[@]}" commit -q -m "tokenização: endpoint POST /tokens"
