#!/usr/bin/env bash
# Monta a fixture em $1: consumidor do forge-harness com base em develop e o PR #212 em feature/webhook-parceiros.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
GIT=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$TARGET/"
git -C "$TARGET" init -q -b develop
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "chore: estado inicial do serviço webhooks"
git -C "$TARGET" checkout -q -b feature/webhook-parceiros
cp -R "$HERE/overlay/feature/." "$TARGET/"
# Segredo fictício montado em runtime para não versionar nada com cara de credencial no harness.
FAKE="whsec_$(printf 'dev%sEXEMPLO' '-')_9fK2mQ7xR4tV8bN1"
for f in "$TARGET/services/webhooks/.env" "$TARGET/services/webhooks/src/Webhooks.Api/appsettings.Development.json"; do
  sed -i.bak "s/__WEBHOOK_SECRET__/${FAKE}/" "$f" && rm -f "$f.bak"
done
git -C "$TARGET" add -A
# O .env pode estar no .gitignore do consumidor; o PR o commitou mesmo assim (-f), que é o defeito sob revisão.
git -C "$TARGET" add -f services/webhooks/.env
"${GIT[@]}" commit -q -m "feat(webhooks): callback de parceiros (PR #212)"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
