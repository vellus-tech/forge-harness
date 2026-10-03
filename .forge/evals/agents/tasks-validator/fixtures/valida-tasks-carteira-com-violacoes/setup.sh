#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness + base "Embarque Fácil" + módulo Carteira com requirements/design aprovados e um tasks.md com defeitos plantados.
# Defeitos plantados no tasks.md: PBT-02 (idempotência do crédito) e RNF 2 (mascaramento de CPF em logs) sem TASK; TASK-06 ausente do Status Geral;
# TASK-03 com implementação (3.1) antes do teste (3.2); ciclo de dependência TASK-04 ↔ TASK-05; TASK-05 manda push direto em main.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/../_base-embarque-facil/overlay/." "$TARGET/"
cp -R "$HERE/overlay/." "$TARGET/"
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
