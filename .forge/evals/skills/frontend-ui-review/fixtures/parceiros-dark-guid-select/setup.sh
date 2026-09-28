#!/usr/bin/env bash
# Monta em $1 o app "crm-web": tela de parceiros com dark mode quebrado (token fantasma --surface-2),
# BU exibida como UUID cru (backend sem endpoint id->nome), token --progress injetado em runtime via style inline,
# e <select> nativo improvisado em duas telas (partners e users) porque o DS não tem Select.
set -euo pipefail
T="${1:?uso: setup.sh <diretorio-alvo>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$T"
cp -R "$HERE/overlay/." "$T/"
G=(git -C "$T" -c user.name=eval -c user.email=eval@example.invalid)
git -C "$T" init -q -b main
"${G[@]}" add -A
"${G[@]}" commit -q -m "crm-web 2.3.1"
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
