#!/usr/bin/env bash
# Monta a fixture em $1: consumidor do forge-harness com base em develop e o diff em feature/checkout-cartao (serviço payment, escopo PCI).
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
"${GIT[@]}" commit -q -m "chore: estado inicial do serviço payment"
git -C "$TARGET" checkout -q -b feature/checkout-cartao
cp -R "$HERE/overlay/feature/." "$TARGET/"
# Valor fictício montado em runtime para não versionar nada com cara de credencial no harness.
FAKE_KEY="acq_live_$(printf 'EXEMPLO%sNAOREAL' '-')_7Hq2Lx9Pz4"
sed -i.bak "s/__ACQ_API_KEY__/${FAKE_KEY}/" "$TARGET/services/payment/src/Payment.Api/appsettings.json"
rm -f "$TARGET/services/payment/src/Payment.Api/appsettings.json.bak"
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "feat(payment): checkout com cartão e integração com adquirente"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
