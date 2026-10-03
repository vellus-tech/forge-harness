#!/usr/bin/env bash
# Caso 1 (caminho principal): branch feat/tarifa/desconto-integracao com build verde, mas o commit afirma um arquivo de teste que não existe no diff; monorepo com apps/painel (Node) intocado.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$TARGET/"
# Runtime do projeto: stack Python, testes do serviço de tarifa via unittest (sem dependências externas).
perl -0pi -e 's/^  primary_stack:\s*$/  primary_stack: python/m; s/^  test:\s*$/  test: cd services\/tarifa \&\& python3 -m unittest discover -s tests -t ./m' "$TARGET/.forge/FORGE.md"
GIT=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
"${GIT[@]}" init -q -b main
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "chore: estado inicial da bilhetagem-urbana"

"${GIT[@]}" checkout -q -b feat/tarifa/desconto-integracao
cp -R "$HERE/overlay/branch/." "$TARGET/"
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -F "$HERE/commit-msg.txt"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"

