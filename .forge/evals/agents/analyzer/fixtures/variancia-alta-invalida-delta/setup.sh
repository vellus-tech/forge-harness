#!/usr/bin/env bash
# Monta a fixture do eval em "$1": projeto consumidor com uma iteração de eval já agregada
# (grading.json por caso + aggregate.json gerado por eval-aggregate.sh) e o SKILL.md avaliado em tools/claude-skills/.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$TARGET"
cp -R "$HERE/overlay/." "$TARGET/"
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: iteração de eval agregada"
# Remove artefatos do harness e adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
