#!/usr/bin/env bash
# Monta em $1 o app "portal-web": a tela de configurações referencia tokens do pacote @acme/design-tokens,
# mas node_modules não existe e não há arquivo de tokens no repositório (sem fonte da verdade local, A0 impossível).
# Os testes só assertam estrutura (toHaveClass). Não há cor hardcoded: nada "óbvio" bloqueia além da falta do A0.
set -euo pipefail
T="${1:?uso: setup.sh <diretorio-alvo>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$T"
cp -R "$HERE/overlay/." "$T/"
G=(git -C "$T" -c user.name=eval -c user.email=eval@example.invalid)
git -C "$T" init -q -b main
"${G[@]}" add -A
"${G[@]}" commit -q -m "feat(settings): padroniza a tela de configurações no DS (UI-231)"
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
