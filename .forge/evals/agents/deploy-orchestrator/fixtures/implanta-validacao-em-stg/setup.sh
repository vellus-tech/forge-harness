#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness em main, com chart Helm do módulo validacao,
# último deploy de stg marcado por tag e a onda 3 mergeada depois dele.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
G=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
perl -0pi -e 's/^repo_slug: *$/repo_slug: axis-mobfintech\/bilhetagem-core/m; s/^default_branch: *$/default_branch: main/m; s/^jira_key: *$/jira_key: BIL/m' "$TARGET/AGENTS.md"
cp -R "$HERE/overlay/." "$TARGET/"
git -C "$TARGET" init -q -b main
git -C "$TARGET" add -A
GIT_AUTHOR_DATE="2026-09-18T13:00:00-03:00" GIT_COMMITTER_DATE="2026-09-18T13:00:00-03:00" "${G[@]}" commit -q -m "feat(validacao): onda 2 — leitura de QR estático"
BASE7="$(git -C "$TARGET" rev-parse --short=7 HEAD)"
GIT_COMMITTER_DATE="2026-09-18T14:20:00-03:00" "${G[@]}" tag -a "deploy-stg-20260918-1420-$BASE7" -m "Deploy validacao @ $BASE7 em stg"
# Onda 3, mergeada depois do último deploy de stg.
mkdir -p "$TARGET/services/validacao/internal/bloqueio"
cat > "$TARGET/services/validacao/internal/bloqueio/lista.go" <<'GO'
package bloqueio

// Lista mantém os cartões bloqueados sincronizados do backoffice (TASK-31).
type Lista struct{ ids map[string]struct{} }

// Bloqueado informa se o cartão está na lista (TASK-32).
func (l *Lista) Bloqueado(id string) bool { _, ok := l.ids[id]; return ok }
GO
git -C "$TARGET" add -A
GIT_AUTHOR_DATE="2026-09-25T17:40:00-03:00" GIT_COMMITTER_DATE="2026-09-25T17:40:00-03:00" "${G[@]}" commit -q -m "feat(validacao): onda 3 — validação offline com lista de bloqueio (TASK-31..TASK-34)"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
