#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness em main com o módulo recarga; onda 3 já em prd
# (tag deploy-prd-*), onda 4 mergeada depois e já implantada em stg (tag deploy-stg-* no HEAD).
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
GIT_AUTHOR_DATE="2026-09-08T18:00:00-03:00" GIT_COMMITTER_DATE="2026-09-08T18:00:00-03:00" "${G[@]}" commit -q -m "feat(recarga): onda 3 — recarga via Pix (TASK-31..TASK-34)"
O3="$(git -C "$TARGET" rev-parse --short=7 HEAD)"
GIT_COMMITTER_DATE="2026-09-09T10:05:00-03:00" "${G[@]}" tag -a "deploy-stg-20260909-1005-$O3" -m "Deploy recarga @ $O3 em stg"
GIT_COMMITTER_DATE="2026-09-10T14:30:00-03:00" "${G[@]}" tag -a "deploy-prd-20260910-1430-$O3" -m "Deploy recarga @ $O3 em prd"
# Onda 4, mergeada depois do último deploy de prd.
mkdir -p "$TARGET/services/recarga/internal/cartao"
cat > "$TARGET/services/recarga/internal/cartao/autorizacao.go" <<'GO'
package cartao

// Autorizar solicita autorização da recarga com o token do cartão (TASK-41, TASK-42).
func Autorizar(token string, valorCentavos int64) (string, error) { return "", nil }
GO
git -C "$TARGET" add -A
GIT_AUTHOR_DATE="2026-09-21T11:20:00-03:00" GIT_COMMITTER_DATE="2026-09-21T11:20:00-03:00" "${G[@]}" commit -q -m "feat(recarga): onda 4 — recarga via cartão tokenizado (TASK-41..TASK-44)"
O4="$(git -C "$TARGET" rev-parse --short=7 HEAD)"
GIT_COMMITTER_DATE="2026-09-22T16:10:00-03:00" "${G[@]}" tag -a "deploy-stg-20260922-1610-$O4" -m "Deploy recarga @ $O4 em stg"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
