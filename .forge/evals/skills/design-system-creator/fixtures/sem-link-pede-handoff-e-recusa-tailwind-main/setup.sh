#!/usr/bin/env bash
# Fixture: consumidor do harness com monorepo JS vazio e SEM bundle de handoff — o prompt não traz o link.
set -euo pipefail
ALVO="${1:?uso: setup.sh <diretorio-alvo>}"
source "$(cd "$(dirname "$0")/../_shared" && pwd)/lib.sh"
forge_consumer "$ALVO" rotaviva
monorepo_root "$ALVO"
finalize "$ALVO"
