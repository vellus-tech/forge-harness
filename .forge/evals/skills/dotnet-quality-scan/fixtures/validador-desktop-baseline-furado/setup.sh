#!/usr/bin/env bash
# Monta um consumidor do harness com um app WinForms (.NET 8) cujo baseline de build está furado:
# TreatWarningsAsErrors=false, severidade de nomenclatura só dentro de dotnet_naming_rule (armadilha
# do IDE1006) e sem Directory.Packages.props. Os achados do scanner são majoritariamente exceções
# legítimas (event handler async void com try/catch, porta hexagonal) e um defeito real (DateTime.Now).
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
"${G[@]}" commit -q -m "validador desktop: sincronização da tabela tarifária"
