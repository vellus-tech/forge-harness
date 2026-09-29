#!/usr/bin/env bash
# Monta um monorepo .NET consumidor do harness: baseline de build completo na raiz, um projeto
# legado cheio de achados (fora do escopo) e a branch feature/recarga-pix que só toca src/Recarga.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
mkdir -p "$T"
node "$FORGE_BIN" init --target "$T" -y --no-plugin >/dev/null
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
cp -R "$HERE/overlay/base/." "$T/"
G=(git -C "$T" -c user.name=eval -c user.email=eval@example.invalid)
"${G[@]}" init -q -b main
"${G[@]}" add -A
"${G[@]}" commit -q -m "base: monorepo com baseline de build e relatórios legados"
"${G[@]}" checkout -q -b feature/recarga-pix
cp -R "$HERE/overlay/change/." "$T/"
"${G[@]}" add -A
"${G[@]}" commit -q -m "feat(recarga): cobrança Pix para recarga de cartão"
