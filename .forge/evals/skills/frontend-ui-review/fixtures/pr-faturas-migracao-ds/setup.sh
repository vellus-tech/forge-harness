#!/usr/bin/env bash
# Monta em $1 um app React "fatura-web" com main (baseline) e branch feat/faturas-ds (o PR em revisão).
# O diff do PR toca só src/features/invoices; src/features/partners (fora do diff) já tem token fantasma e cor hardcoded.
set -euo pipefail
T="${1:?uso: setup.sh <diretorio-alvo>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$T"
cp -R "$HERE/overlay/base/." "$T/"
G=(git -C "$T" -c user.name=eval -c user.email=eval@example.invalid)
git -C "$T" init -q -b main
"${G[@]}" add -A
"${G[@]}" commit -q -m "fatura-web 1.4.0"
git -C "$T" checkout -q -b feat/faturas-ds
cp -R "$HERE/overlay/pr/." "$T/"
"${G[@]}" add -A
"${G[@]}" commit -q -m "feat(invoices): migra a tela de faturas para o design system"
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
