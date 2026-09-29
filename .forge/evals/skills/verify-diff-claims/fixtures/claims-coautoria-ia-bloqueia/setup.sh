#!/usr/bin/env bash
# Monta a fixture do caso em $1: consumidor do forge-harness com main + branch feat/recarga-cartao de dois commits do "coder".
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
GIT="git -C $TARGET -c user.name=eval -c user.email=eval@example.invalid"
strip() { rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"; }
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$TARGET/"
# Remove skills e agentes antes do primeiro commit: não ficam nem no histórico.
strip
git -C "$TARGET" init -q -b main
$GIT add -A
$GIT commit -q -m "chore: estado inicial do projeto"
$GIT checkout -q -b feat/recarga-cartao
for c in c1 c2; do
  cp -R "$HERE/overlay/$c/." "$TARGET/"
  $GIT add -A
  $GIT commit -q -F "$HERE/$c.msg"
done
# Garantia final: nada de skills/agentes do harness no alvo (baseline limpo).
strip
