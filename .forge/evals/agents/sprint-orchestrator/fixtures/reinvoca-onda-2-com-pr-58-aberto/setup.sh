#!/usr/bin/env bash
# Fixture "reinvoca-onda-2-com-pr-58-aberto": mesma base do caso principal, mas a rodada anterior do
# sprint-orchestrator já abriu o PR #58 da onda 2, registrou no tracker do main a onda em In Review e a
# falha do sync Jira, e avançou o change recarga-pix para implementing. Depois disso, a branch da onda
# ganhou um commit de ajuste pedido pelo code-evaluator (TASK-06), ainda não empurrado.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_base/base.sh
source "$HERE/../_base/base.sh"
base_consumidor "$TARGET"
onda2_worktree "$TARGET"
# Estado deixado pela rodada anterior no main.
cp -R "$HERE/overlay/." "$TARGET/"
(cd "$TARGET" && bash .forge/scripts/spec-advance-module.sh recarga implementing >/dev/null)
perl -pi -e 's/^(updated_at): .*/$1: "2026-09-25"/m' "$TARGET/.forge/specs/active/recarga-pix/manifest.yaml"
g "$TARGET" "2026-09-25T09:40:00-03:00" add -A
g "$TARGET" "2026-09-25T09:40:00-03:00" commit -q -m "docs(specs): recarga wave 2 — aguardando review"
# Ajuste pedido na revisão do PR #58, commitado na branch da onda depois do push anterior.
W="$TARGET/.forge/worktrees/recarga-wave-2"
cat > "$W/services/recarga/pix/assinatura.go" <<'GO'
package pix

// AssinaturaValida rejeita webhook do PSP sem o cabeçalho de assinatura esperado (ajuste da revisão do PR #58, TASK-06).
func AssinaturaValida(cabecalho string) bool { return len(cabecalho) >= 64 }
GO
g "$W" "2026-09-25T15:10:00-03:00" add -A
g "$W" "2026-09-25T15:10:00-03:00" commit -q -m "fix(recarga): TASK-06 — rejeitar webhook do PSP sem assinatura válida"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
limpa_artefato "$TARGET"
