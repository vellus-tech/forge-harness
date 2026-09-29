#!/usr/bin/env bash
# Funções compartilhadas pelas fixtures do sprint-orchestrator (sourced pelos setup.sh de cada caso).
# Monta um consumidor do forge-harness (bilhetagem-recarga, Jira REC) com o módulo recarga em ondas,
# um change SDD ativo vinculado ao módulo e a worktree da onda pedida. Os diretórios do artefato sob
# avaliação (.forge/skills, .forge/agents, .claude/skills, .claude/agents, plugin/) nunca entram no git.
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$BASE_DIR/../../../../../.." && pwd)}"

g() { local dir="$1" when="$2"; shift 2; GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" git -C "$dir" -c user.name=eval -c user.email=eval@example.invalid "$@"; }

limpa_artefato() {
  rm -rf "$1/.forge/skills" "$1/.forge/agents" "$1/.claude/skills" "$1/.claude/agents" "$1/plugin"
}

# base_consumidor <alvo>: main com a onda 1 mergeada e o change recarga-pix em tasks-ready.
base_consumidor() {
  local T="$1"
  mkdir -p "$T"
  node "$REPO/bin/forge.mjs" init --target "$T" -y --no-plugin >/dev/null
  perl -0pi -e 's/^repo_slug: *$/repo_slug: axis-mobfintech\/bilhetagem-recarga/m; s/^default_branch: *$/default_branch: main/m; s/^jira_key: *$/jira_key: REC/m; s/^jira_site: *$/jira_site: axis-mobfintech.atlassian.net/m' "$T/AGENTS.md"
  limpa_artefato "$T"
  cp -R "$BASE_DIR/overlay/." "$T/"
  (cd "$T" && bash .forge/scripts/spec-new.sh recarga-pix --type feature --scale 1 --owner eval >/dev/null)
  perl -0pi -e 's/^status: .*/status: tasks-ready/m; s/^affected_paths: \[\]/affected_paths:\n  - docs\/product\/modules\/recarga\/\n  - services\/recarga\//m; s/requirements_reviewed: false/requirements_reviewed: true/; s/tasks_reviewed: false/tasks_reviewed: true/; s/^(created_at|updated_at): .*/$1: "2026-09-15"/mg' "$T/.forge/specs/active/recarga-pix/manifest.yaml"
  git -C "$T" init -q -b main
  git -C "$T" add -A
  g "$T" "2026-09-22T16:40:00-03:00" commit -q -m "feat(recarga): onda 1 — cadastro de cartão e consulta de saldo (#41)"
}

# marca_task <worktree> <TASK-NN> <sha> <quando>: [ ] -> [X] com o SHA no tracker da worktree e commita.
marca_task() {
  local W="$1" id="$2" sha="$3" when="$4" trk="$1/docs/product/modules/recarga/PROGRESS-TRACKING.md"
  perl -pi -e "s/^- \\[[ -]\\] ($id .*?)-\$/- [X] \${1}$sha/" "$trk"
  g "$W" "$when" add "$trk"
  g "$W" "$when" commit -q -m "chore(specs): $id — concluída"
}

# onda2_worktree <alvo>: worktree .forge/worktrees/recarga-wave-2 na branch feat/recarga/wave-2, 100% [X], limpa.
onda2_worktree() {
  local T="$1" W="$1/.forge/worktrees/recarga-wave-2" sha
  git -C "$T" worktree add -q "$W" -b feat/recarga/wave-2
  mkdir -p "$W/services/recarga/pix"
  cat > "$W/services/recarga/pix/cobranca.go" <<'GO'
package pix

// Cobranca é a cobrança Pix dinâmica de uma recarga, identificada por txid único (TASK-05).
type Cobranca struct {
	TxID           string
	ValorCentavos  int64
	CartaoID       string
}
GO
  g "$W" "2026-09-24T10:05:00-03:00" add -A
  g "$W" "2026-09-24T10:05:00-03:00" commit -q -m "feat(recarga): TASK-05 — gerar cobrança Pix dinâmica com txid único"
  sha="$(git -C "$W" rev-parse --short=7 HEAD)"; marca_task "$W" TASK-05 "$sha" "2026-09-24T10:06:00-03:00"
  cat > "$W/services/recarga/pix/webhook.go" <<'GO'
package pix

// Confirmacoes guarda os txids já confirmados pelo PSP; repetir o webhook é no-op (TASK-06, PBT-02).
type Confirmacoes struct{ vistos map[string]bool }

// Registrar devolve true só na primeira confirmação de um txid.
func (c *Confirmacoes) Registrar(txid string) bool {
	if c.vistos[txid] { return false }
	c.vistos[txid] = true
	return true
}
GO
  g "$W" "2026-09-24T13:30:00-03:00" add -A
  g "$W" "2026-09-24T13:30:00-03:00" commit -q -m "feat(recarga): TASK-06 — webhook do PSP idempotente por txid"
  sha="$(git -C "$W" rev-parse --short=7 HEAD)"; marca_task "$W" TASK-06 "$sha" "2026-09-24T13:31:00-03:00"
  cat > "$W/services/recarga/pix/credito.go" <<'GO'
package pix

// Creditar soma o valor ao saldo do cartão apenas quando a confirmação é nova (TASK-07).
func Creditar(saldo int64, valor int64, nova bool) int64 {
	if !nova { return saldo }
	return saldo + valor
}
GO
  g "$W" "2026-09-24T16:10:00-03:00" add -A
  g "$W" "2026-09-24T16:10:00-03:00" commit -q -m "feat(recarga): TASK-07 — creditar saldo após confirmação do PSP"
  sha="$(git -C "$W" rev-parse --short=7 HEAD)"; marca_task "$W" TASK-07 "$sha" "2026-09-24T16:11:00-03:00"
  cat > "$W/services/recarga/pix/expiracao.go" <<'GO'
package pix

import "time"

// Expirada informa se a cobrança passou dos 30 minutos sem pagamento (TASK-08).
func Expirada(criada, agora time.Time) bool { return agora.Sub(criada) > 30*time.Minute }
GO
  g "$W" "2026-09-25T09:20:00-03:00" add -A
  g "$W" "2026-09-25T09:20:00-03:00" commit -q -m "feat(recarga): TASK-08 — expirar cobrança Pix após 30 minutos"
  sha="$(git -C "$W" rev-parse --short=7 HEAD)"; marca_task "$W" TASK-08 "$sha" "2026-09-25T09:21:00-03:00"
  perl -pi -e 's/^\| 2    \| ⏳ Pendente \| 4 \| 0 \| 0 \| - \|/| 2    | ✅ Concluída | 4 | 4 | 0 | - |/; s/^Última atualização: .*/Última atualização: 2026-09-25 09:25 (task-coder onda 2 concluída)/' "$W/docs/product/modules/recarga/PROGRESS-TRACKING.md"
  g "$W" "2026-09-25T09:25:00-03:00" add -A
  g "$W" "2026-09-25T09:25:00-03:00" commit -q -m "chore(specs): recarga onda 2 — 4/4 TASKs concluídas"
}
