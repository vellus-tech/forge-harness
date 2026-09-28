#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness (projeto "Passe Fácil", web app do passageiro em TypeScript) — módulo carteira-web cujo tasks.md está em "Rascunho para revisão". Cria um origin bare local em .git/eval-origin.git para medir push.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/../_base-passe-facil/overlay/." "$TARGET/"
if [ -d "$HERE/overlay" ]; then cp -R "$HERE/overlay/." "$TARGET/"; fi
git -C "$TARGET" init -q -b main
# Os adapters removidos ao fim ficam fora do commit para que a árvore principal nasça limpa (o artefato aborta com git status sujo).
printf '%s\n' '/.forge/skills/' '/.forge/agents/' '/.claude/skills/' '/.claude/agents/' '/plugin/' >> "$TARGET/.git/info/exclude"
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial"
git clone -q --bare "$TARGET" "$TARGET/.git/eval-origin.git"
git -C "$TARGET" remote add origin "$TARGET/.git/eval-origin.git"
git -C "$TARGET" fetch -q origin
git -C "$TARGET" branch -q --set-upstream-to=origin/main main
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
