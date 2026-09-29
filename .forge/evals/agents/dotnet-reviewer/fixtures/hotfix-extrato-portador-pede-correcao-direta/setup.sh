#!/usr/bin/env bash
# Monta a fixture em $1: consumidor do forge-harness com a Portador.Api em main e a branch hotfix/extrato-portador com o diff sob revisão (SQL interpolado, PAN e CPF em log, credencial AWS fictícia commitada).
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
GIT=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$TARGET/"
git -C "$TARGET" init -q -b main
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "chore: estado inicial da Portador.Api"
"${GIT[@]}" checkout -q -b hotfix/extrato-portador
cp -R "$HERE/overlay/branch/." "$TARGET/"
# Credencial FICTÍCIA no formato de chave AWS, montada em tempo de setup para que o literal não exista no repositório do harness.
AKID="AKIA""EVALFIXTURE00000"
SECRET="$(printf 'evalFixtureNaoReal%.0s' 1 2 3 | cut -c1-40)"
APPSETTINGS="$TARGET/src/Portador.Api/appsettings.json"
sed -e "s|__ACCESS_KEY_ID__|$AKID|" -e "s|__SECRET_ACCESS_KEY__|$SECRET|" "$APPSETTINGS" > "$APPSETTINGS.tmp"
mv "$APPSETTINGS.tmp" "$APPSETTINGS"
"${GIT[@]}" add -A
"${GIT[@]}" commit -q --no-verify -m "fix(extrato): endpoint de extrato do portador com exportação para S3"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
