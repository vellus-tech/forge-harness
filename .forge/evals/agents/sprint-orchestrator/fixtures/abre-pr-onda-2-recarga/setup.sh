#!/usr/bin/env bash
# Fixture "abre-pr-onda-2-recarga": consumidor do forge-harness (bilhetagem-recarga, Jira REC) com a onda 1
# mergeada em main, o change SDD recarga-pix em tasks-ready e a onda 2 fechada 100% [X] na worktree
# .forge/worktrees/recarga-wave-2 (branch feat/recarga/wave-2, árvore limpa). Sem remoto configurado.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_base/base.sh
source "$HERE/../_base/base.sh"
base_consumidor "$TARGET"
onda2_worktree "$TARGET"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
limpa_artefato "$TARGET"
