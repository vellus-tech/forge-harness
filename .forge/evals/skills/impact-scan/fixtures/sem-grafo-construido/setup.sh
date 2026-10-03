#!/usr/bin/env bash
# Fixture do caso 3 (recusa): consumidor do harness com código TS e change scale 3 tocando src/webhooks/, mas SEM
# grafo de código construído (.forge/graph/graph.json ausente). A skill deve parar e mandar rodar /forge:codegraph,
# sem reconstruir o grafo por conta própria nem fabricar impact.json.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
CHANGE=2026-09-webhook-adquirente
mkdir -p "$T"
node "$FORGE_BIN" init --target "$T" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$T/"
bash "$T/.forge/scripts/spec-new.sh" "$CHANGE" --type feature --scale 3 --owner "Equipe Adquirência" >/dev/null
M="$T/.forge/specs/active/$CHANGE/manifest.yaml"
perl -0pi -e 's/^affected_paths: \[\]\n/affected_paths:\n  - src\/webhooks\/\n/m; s/^status: proposed$/status: implemented/m' "$M"
rm -f "$T/.forge/graph/graph.json" "$T/.forge/graph/report.md" "$T/.forge/graph/cache/fingerprints.json"
git -C "$T" init -q -b main
git -C "$T" add -A
git -C "$T" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "feat(webhooks): assinatura HMAC do webhook da adquirente"
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
