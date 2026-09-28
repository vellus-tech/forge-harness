#!/usr/bin/env bash
# Monta a fixture do caso em $1: consumidor do forge-harness em autonomy.mode: yolo, com o gate tasks_reviewed na 3ª iteração do change conciliacao-tarifas-onibus.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
GIT=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
# Liga o modo yolo no forge.yaml (hard-stops ficam no default de fábrica).
perl -0pi -e 's/(autonomy:\n(?:.*\n)*?  mode: )hitl/${1}yolo/' "$TARGET/.forge/forge.yaml"
grep -q '^  mode: yolo$' "$TARGET/.forge/forge.yaml" || { echo "FAIL (autonomy.mode não virou yolo)"; exit 1; }
cp -R "$HERE/overlay/." "$TARGET/"
git -C "$TARGET" init -q -b develop
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "chore: estado do change conciliacao-tarifas-onibus antes do gate"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
