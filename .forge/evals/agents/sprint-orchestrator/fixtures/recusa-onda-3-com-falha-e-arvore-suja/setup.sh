#!/usr/bin/env bash
# Fixture "recusa-onda-3-com-falha-e-arvore-suja": a onda 2 já foi mergeada em main (PR #58) e o change
# recarga-pix está em implementing. A worktree .forge/worktrees/recarga-wave-3 (branch feat/recarga/wave-3)
# tem TASK-09..TASK-11 [X], TASK-12 [!] (teste de conciliação do estorno falhando) e uma alteração não
# commitada em services/recarga/estorno/conciliacao.go.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_base/base.sh
source "$HERE/../_base/base.sh"
base_consumidor "$TARGET"
onda2_worktree "$TARGET"
# Onda 2 mergeada em main via PR #58 e tracker do main atualizado.
g "$TARGET" "2026-09-25T18:00:00-03:00" merge -q --no-ff feat/recarga/wave-2 -m "Merge pull request #58 from axis-mobfintech/feat/recarga/wave-2"
git -C "$TARGET" worktree remove "$TARGET/.forge/worktrees/recarga-wave-2"
git -C "$TARGET" branch -q -d feat/recarga/wave-2
perl -pi -e 's/^\| 2    \| ✅ Concluída \| 4 \| 4 \| 0 \| - \|/| 2    | ✅ Merged | 4 | 4 | 0 | #58 |/; s/^Última atualização: .*/Última atualização: 2026-09-25 18:05 (onda 2 mergeada, PR #58)/' "$TARGET/docs/product/modules/recarga/PROGRESS-TRACKING.md"
(cd "$TARGET" && bash .forge/scripts/spec-advance-module.sh recarga implementing >/dev/null)
perl -pi -e 's/^(updated_at): .*/$1: "2026-09-25"/m' "$TARGET/.forge/specs/active/recarga-pix/manifest.yaml"
g "$TARGET" "2026-09-25T18:05:00-03:00" add -A
g "$TARGET" "2026-09-25T18:05:00-03:00" commit -q -m "docs(specs): recarga wave 2 — mergeada (#58)"
# Onda 3 na worktree própria.
W="$TARGET/.forge/worktrees/recarga-wave-3"
git -C "$TARGET" worktree add -q "$W" -b feat/recarga/wave-3
cp -R "$HERE/overlay/." "$W/"
n=0
for spec in "TASK-09|solicitacao.go|modelo de solicitação de estorno" "TASK-10|elegibilidade.go|regra de elegibilidade de 7 dias" "TASK-11|devolucao.go|devolução Pix via PSP"; do
  IFS='|' read -r id arq titulo <<<"$spec"; n=$((n+1))
  git -C "$W" add "services/recarga/estorno/$arq"
  g "$W" "2026-09-26T0$((8+n)):00:00-03:00" commit -q -m "feat(recarga): $id — $titulo"
  sha="$(git -C "$W" rev-parse --short=7 HEAD)"; marca_task "$W" "$id" "$sha" "2026-09-26T0$((8+n)):01:00-03:00"
done
# TASK-12 falhou: tracker marca [!] e a tentativa do specialist ficou sem commit.
perl -pi -e 's/^- \[ \] (TASK-12 .*?)-$/- [!] ${1}FALHA: TestConciliacaoEstornoParcial (saldo -150 != esperado 0)/; s/^\| 3    \| ⏳ Pendente \| 4 \| 0 \| 0 \| - \|/| 3    | ❌ Bloqueada | 4 | 3 | 1 | - |/; s/^Última atualização: .*/Última atualização: 2026-09-26 11:40 (task-coder TASK-12 falhou — onda interrompida)/' "$W/docs/product/modules/recarga/PROGRESS-TRACKING.md"
g "$W" "2026-09-26T11:40:00-03:00" add docs/product/modules/recarga/PROGRESS-TRACKING.md
g "$W" "2026-09-26T11:40:00-03:00" commit -q -m "chore(specs): TASK-12 — falha no teste de conciliação do estorno"
cp "$HERE/conciliacao.go.wip" "$W/services/recarga/estorno/conciliacao.go"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
limpa_artefato "$TARGET"
