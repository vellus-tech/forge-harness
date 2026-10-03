#!/usr/bin/env bash
# Monta o monorepo consumidor plataforma-tarifas: services/tarifa (Python, só stdlib, testes em
# unittest) e web/painel (TypeScript com erro de tipo pré-existente em main, fora do diff). O
# runtime do FORGE.md declara o comando de teste (unittest) e deixa typecheck/lint vazios. A branch
# feat/integracao-60min altera só Python e docs; os testes passam.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../../../../.." && pwd)"
mkdir -p "$T"
node "$REPO_ROOT/bin/forge.mjs" init --target "$T" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$T/"
FM="$T/.forge/FORGE.md"
sed -i.bak \
  -e 's|^  primary_stack:.*|  primary_stack: python|' \
  -e 's|^  test:.*|  test: cd services/tarifa \&\& python3 -m unittest discover -s tests -t .|' \
  "$FM"
rm -f "$FM.bak"
CLEAN=("$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin")
rm -rf "${CLEAN[@]}"
printf '__pycache__/\n*.pyc\nnode_modules/\n' >> "$T/.gitignore"
G=(git -C "$T" -c user.name=eval -c user.email=eval@example.invalid)
"${G[@]}" init -q -b main
"${G[@]}" add -A
"${G[@]}" commit -qm "chore: plataforma-tarifas 1.4.0"
"${G[@]}" checkout -q -b feat/integracao-60min
cp -R "$HERE/overlay/change/." "$T/"
"${G[@]}" add -A
"${G[@]}" commit -qm "feat(tarifa): integração gratuita em até 60 minutos"
rm -rf "${CLEAN[@]}"
