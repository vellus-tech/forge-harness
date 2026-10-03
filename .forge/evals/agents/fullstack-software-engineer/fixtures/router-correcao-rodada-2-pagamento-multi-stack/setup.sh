#!/usr/bin/env bash
# Monta a fixture do caso em $1: consumidor do forge-harness com main + branch feat/pagamento-cartao (payment .NET, checkout React, runbook) já publicada num remoto bare local em .git/origin.git, pronta para a rodada 2 de correção do code-evaluator.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}"
GIT_ID=(-c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null

# Estado da main.
cp -R "$HERE/overlay/base/." "$TARGET/"
# Skills e agentes saem antes do primeiro commit, para o histórico e o status do alvo ficarem limpos.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
git -C "$TARGET" init -q -b main
git -C "$TARGET" add -A
git -C "$TARGET" "${GIT_ID[@]}" commit -q -m "chore: estado inicial do serviço de pagamento"

# Branch em revisão.
git -C "$TARGET" checkout -q -b feat/pagamento-cartao
cp -R "$HERE/overlay/branch/." "$TARGET/"
git -C "$TARGET" add -A
git -C "$TARGET" "${GIT_ID[@]}" commit -q -m "feat(payment): pagamento com cartão de crédito no checkout"

# Remoto bare dentro de .git (fora da árvore de trabalho) para o push da política de commit funcionar offline.
git init -q --bare "$TARGET/.git/origin.git"
git -C "$TARGET" remote add origin "$TARGET/.git/origin.git"
git -C "$TARGET" push -q origin main feat/pagamento-cartao
git -C "$TARGET" branch -q --set-upstream-to=origin/feat/pagamento-cartao

# Remove skills e agentes do alvo para não contaminar o baseline (garantia final, idempotente).
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
