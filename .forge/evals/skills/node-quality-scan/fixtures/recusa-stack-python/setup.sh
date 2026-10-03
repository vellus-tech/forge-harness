#!/usr/bin/env bash
# Monta o consumidor servico-conciliacao (Python/FastAPI + psycopg), sem nenhum arquivo Node/TS,
# para que o scanner Node rode "limpo" por ausência de alvo. Há SQL por f-string e except vazio
# em app/repositorio.py, que o scanner Node não enxerga.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../../../../.." && pwd)"
mkdir -p "$T"
node "$REPO_ROOT/bin/forge.mjs" init --target "$T" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$T/"
CLEAN=("$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin")
rm -rf "${CLEAN[@]}"
G=(git -C "$T" -c user.name=eval -c user.email=eval@example.invalid)
"${G[@]}" init -q -b main
"${G[@]}" add -A
"${G[@]}" commit -qm "feat: servico-conciliacao 1.7.0"
rm -rf "${CLEAN[@]}"
