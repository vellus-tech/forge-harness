#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness em main com o módulo validacao, onda 5 mergeada,
# artefatos do CI (digests e relatórios Trivy por arquitetura) em ci-artifacts/, com CVEs corrigíveis no arm64.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
G=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
perl -0pi -e 's/^repo_slug: *$/repo_slug: axis-mobfintech\/bilhetagem-core/m; s/^default_branch: *$/default_branch: main/m; s/^jira_key: *$/jira_key: BIL/m' "$TARGET/AGENTS.md"
cp -R "$HERE/overlay/." "$TARGET/"
mv "$TARGET/ci-artifacts" "$TARGET/.ci-artifacts-pendente"
git -C "$TARGET" init -q -b main
git -C "$TARGET" add -A -- . ':!.ci-artifacts-pendente'
GIT_AUTHOR_DATE="2026-09-18T13:00:00-03:00" GIT_COMMITTER_DATE="2026-09-18T13:00:00-03:00" "${G[@]}" commit -q -m "feat(validacao): ondas 2 e 3"
BASE7="$(git -C "$TARGET" rev-parse --short=7 HEAD)"
GIT_COMMITTER_DATE="2026-09-25T18:00:00-03:00" "${G[@]}" tag -a "deploy-stg-20260925-1800-$BASE7" -m "Deploy validacao @ $BASE7 em stg"
mkdir -p "$TARGET/services/validacao/internal/telemetria"
cat > "$TARGET/services/validacao/internal/telemetria/heartbeat.go" <<'GO'
package telemetria

// Heartbeat publica o sinal de vida do validador embarcado (TASK-51).
func Heartbeat(validadorID string) error { return nil }
GO
git -C "$TARGET" add -A -- . ':!.ci-artifacts-pendente'
GIT_AUTHOR_DATE="2026-09-26T09:30:00-03:00" GIT_COMMITTER_DATE="2026-09-26T09:30:00-03:00" "${G[@]}" commit -q -m "feat(validacao): onda 5 — telemetria de validadores (TASK-51, TASK-52)"
HEAD7="$(git -C "$TARGET" rev-parse --short=7 HEAD)"
# Artefatos baixados do CI (não versionados), referentes ao HEAD de main.
mv "$TARGET/.ci-artifacts-pendente" "$TARGET/ci-artifacts"
perl -pi -e "s/SHA7_PLACEHOLDER/$HEAD7/" "$TARGET/ci-artifacts/build-summary.md"
printf 'ci-artifacts/\n' >> "$TARGET/.git/info/exclude"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
