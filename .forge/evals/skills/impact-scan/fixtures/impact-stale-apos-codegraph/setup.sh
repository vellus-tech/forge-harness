#!/usr/bin/env bash
# Fixture do caso 2 (borda): change scale 3 com affected_paths por DIRETÓRIO (src/billing/). O impact.json foi gerado
# num grafo antigo; depois entraram src/billing/refund.ts e src/api/routes/refunds.ts e o grafo foi reconstruído
# (como se o usuário tivesse rodado /forge:codegraph). Resultado: impact.json stale e sem os arquivos novos.
# Grava o sha256 do graph.json atual em .git/eval-graph.sha256 para o grader provar que o grafo não foi reconstruído.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
CHANGE=2026-09-estorno-parcial
GIT=(git -C "$T" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$T"
node "$FORGE_BIN" init --target "$T" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$T/"
bash "$T/.forge/scripts/spec-new.sh" "$CHANGE" --type feature --scale 3 --owner "Equipe Bilhetagem" >/dev/null
M="$T/.forge/specs/active/$CHANGE/manifest.yaml"
perl -0pi -e 's/^affected_paths: \[\]\n/affected_paths:\n  - src\/billing\/\n/m; s/^status: proposed$/status: implemented/m' "$M"
git -C "$T" init -q -b main
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "feat(billing): base de faturamento"
bash "$T/.forge/scripts/graph.sh" build >/dev/null
bash "$T/.forge/scripts/impact.sh" --change "$CHANGE" >/dev/null
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "chore(spec): impact.json do estorno parcial"
cp -R "$HERE/overlay-pos-grafo/." "$T/"
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "feat(billing): estorno parcial e rota /refunds"
bash "$T/.forge/scripts/graph.sh" build >/dev/null
shasum -a 256 "$T/.forge/graph/graph.json" | cut -d' ' -f1 > "$T/.git/eval-graph.sha256"
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
