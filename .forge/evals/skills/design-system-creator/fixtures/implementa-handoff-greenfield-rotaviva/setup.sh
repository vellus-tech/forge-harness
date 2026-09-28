#!/usr/bin/env bash
# Fixture: consumidor do harness greenfield (monorepo JS vazio) com o handoff do Claude Design já extraído em design-handoff/.
set -euo pipefail
ALVO="${1:?uso: setup.sh <diretorio-alvo>}"
source "$(cd "$(dirname "$0")/../_shared" && pwd)/lib.sh"
forge_consumer "$ALVO" rotaviva
monorepo_root "$ALVO"
handoff_bundle "$ALVO"
finalize "$ALVO"
