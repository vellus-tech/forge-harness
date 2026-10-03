#!/usr/bin/env bash
# Fixture do caso recarga-pix-sem-epic-context: consumidor do harness com o change 2026-09-recarga-pix (recarga de bilhete via Pix) já fatiado em
# stories (dev_loop.sharded: true, epic_context_compiled: false) e em implementing. design.md, requirements.md e tasks.md
# carregam trechos que NÃO estão na story-alvo nem no epic_context.md (retenção de 400 dias, particionamento mensal,
# job às 06h15, rotação de 90 dias, tasks de outras stories) para o grader detectar leitura fora do escopo.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
CHANGE=2026-09-recarga-pix
GIT=(git -C "$T" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$T"
node "$FORGE_BIN" init --target "$T" -y --no-plugin >/dev/null
bash "$T/.forge/scripts/spec-new.sh" "$CHANGE" --type feature --scale 3 --owner "Equipe Bilhetagem" >/dev/null
cp -R "$HERE/overlay/." "$T/"
M="$T/.forge/specs/active/$CHANGE/manifest.yaml"
perl -0pi -e 's/^status: proposed$/status: implementing/m; s/^  sharded: false$/  sharded: true/m; s/^  epic_context_compiled: false$/  epic_context_compiled: false/m' "$M"
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
git -C "$T" init -q -b main
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "chore(spec): 2026-09-recarga-pix fatiado em stories"
# Remoção final (idempotente): garante que nada de skills/agents do harness contamine o baseline.
rm -rf "$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin"
