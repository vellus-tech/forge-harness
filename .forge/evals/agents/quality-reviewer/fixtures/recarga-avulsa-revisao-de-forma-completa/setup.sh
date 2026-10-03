#!/usr/bin/env bash
# Monta em $1 um consumidor do forge-harness (.NET + PostgreSQL) com base em develop e a branch feature/recarga-avulsa com três commits sob revisão.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
GIT=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$TARGET/"
# Tira skills e agentes antes do primeiro commit para que não entrem no histórico do alvo.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
git -C "$TARGET" init -q -b develop
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "chore(infra): estado inicial do serviço de recarga"
git -C "$TARGET" checkout -q -b feature/recarga-avulsa
cp -R "$HERE/overlay/c1/." "$TARGET/"
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "feat(recarga): adicionar recarga avulsa no domínio" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
cp -R "$HERE/overlay/c2/." "$TARGET/"
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "feat(data): adicionar tabela de recargas avulsas"
cp -R "$HERE/overlay/c3/." "$TARGET/"
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "docs(docs): registrar resumo da implementação da recarga avulsa"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
