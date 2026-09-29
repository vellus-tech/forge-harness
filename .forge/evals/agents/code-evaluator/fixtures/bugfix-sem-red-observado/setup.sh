#!/usr/bin/env bash
# Caso 2 (borda): bugfix com build verde e claims verdadeiros, mas o change type:bugfix no diff tem evidência de Red ainda pending.
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

"${GIT[@]}" checkout -q -b fix/tarifa-arredondamento-meia
cp -R "$HERE/overlay/branch/." "$TARGET/"
FORGE_ROOT="$TARGET" bash "$TARGET/.forge/scripts/spec-new.sh" fix-arredondamento-meia --type bugfix --scale 1 --owner backend-engineer >/dev/null
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -F "$HERE/commit-msg.txt"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"

