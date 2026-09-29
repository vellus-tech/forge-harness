#!/usr/bin/env bash
# Fixture: brownfield — packages/design-tokens e docs/product/design-system/tokens.md já existem e batem com o handoff; faltam icons, ui-components e os outros três docs.
set -euo pipefail
ALVO="${1:?uso: setup.sh <diretorio-alvo>}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
source "$AQUI/../_shared/lib.sh"
forge_consumer "$ALVO" rotaviva
monorepo_root "$ALVO"
handoff_bundle "$ALVO"
cp -R "$AQUI/overlay/." "$ALVO/"
finalize "$ALVO"
