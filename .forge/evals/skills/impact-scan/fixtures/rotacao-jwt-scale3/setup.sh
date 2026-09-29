#!/usr/bin/env bash
# Fixture do caso 1 (caminho principal): consumidor do harness com código TS, grafo construído e change scale 3
# implementado cujo affected_paths aponta para src/auth/. Grava o sha256 do graph.json em .git/eval-graph.sha256
# (fora da árvore de trabalho) para o grader provar que o grafo não foi reconstruído.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
CHANGE=2026-09-rotacao-jwt
mkdir -p "$T"
node "$FORGE_BIN" init --target "$T" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$T/"
bash "$T/.forge/scripts/spec-new.sh" "$CHANGE" --type feature --scale 3 --owner "Equipe Plataforma" >/dev/null
M="$T/.forge/specs/active/$CHANGE/manifest.yaml"
perl -0pi -e 's/^affected_paths: \[\]\n/affected_paths:\n  - src\/auth\/jwt.ts\n  - src\/auth\/index.ts\n/m; s/^status: proposed$/status: implemented/m' "$M"
git -C "$T" init -q -b main
git -C "$T" add -A
git -C "$T" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "feat(auth): rotação de chave JWT por kid"
bash "$T/.forge/scripts/graph.sh" build >/dev/null
shasum -a 256 "$T/.forge/graph/graph.json" | cut -d' ' -f1 > "$T/.git/eval-graph.sha256"
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
