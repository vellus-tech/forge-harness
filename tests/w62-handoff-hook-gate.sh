#!/usr/bin/env bash
# Gate W4.2 — handoff SessionStart/SessionEnd hooks (opt-in via forge.yaml handoff.auto):
#   [1] default install → handoff.auto: false; .claude/settings.json has exactly 2 "command":
#       entries (worktree-guard + prevent-secrets-leak.sh, both armed by default since issue
#       #125), no SessionStart/SessionEnd (C5 regression guard)
#   [2] flip handoff.auto: true + re-sync claude adapter → settings.json gains SessionStart +
#       SessionEnd hooks pointing at the session scripts; 4 "command": entries total
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR/GIT_WORK_TREE/GIT_INDEX_FILE/GIT_COMMON_DIR/GIT_OBJECT_DIRECTORY
# herdados do ambiente (de uma sessão paralela mal isolada) fariam este gate — que cria
# repositório git sintético e/ou instala via installer/install.sh ou forge.mjs init/update, que
# gravam core.hooksPath e identidade no repositório do alvo — obedecer ao repositório real de
# quem exportou a variável, não ao alvo sintético. Incidente P1 medido em 2026-09-26.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w42.XXXXXX)"
trap 'rm -rf "$T"' EXIT

sync() { (cd "$T" && bash .forge/scripts/sync-adapters.sh "$@" >/dev/null); }

echo "[1] install default (claude only) — handoff.auto: false"
"$WS/installer/install.sh" --target "$T" --slug fixture-app --name "Fixture App" --desc "Gate W4.2" >/dev/null

grep -q '^handoff:' "$T/.forge/forge.yaml"
grep -q 'auto: false' "$T/.forge/forge.yaml"

SETTINGS="$T/.claude/settings.json"
[ -f "$SETTINGS" ]
python3 -m json.tool "$SETTINGS" >/dev/null

COUNT1="$(grep -o '"command":' "$SETTINGS" | wc -l | tr -d ' ')"
[ "$COUNT1" -eq 2 ]
grep -q 'enforce-worktree-location.sh' "$SETTINGS"
grep -q 'prevent-secrets-leak.sh' "$SETTINGS"
# LDG-0182: sob set -e, `! grep -q ...` sozinho nunca reprova o gate (o retorno invertido isenta a
# linha do set -e), então uma regressão que injetasse SessionStart/SessionEnd no install default
# passaria em silêncio (medido: renomear a chave PreToolUse para SessionStart mantém "OK [1]").
! grep -q 'SessionStart' "$SETTINGS" || \
  { echo "FAIL [1]: install default (handoff.auto: false) tem SessionStart em settings.json"; exit 1; }
! grep -q 'SessionEnd' "$SETTINGS" || \
  { echo "FAIL [1]: install default (handoff.auto: false) tem SessionEnd em settings.json"; exit 1; }
echo "OK [1]"

echo "[2] flip handoff.auto: true + re-sync claude adapter"
sed -i.bak 's/auto: false/auto: true/' "$T/.forge/forge.yaml"
rm -f "$T/.forge/forge.yaml.bak"
grep -q 'auto: true' "$T/.forge/forge.yaml"

sync --adapter claude

python3 -m json.tool "$SETTINGS" >/dev/null

grep -q '"SessionStart"' "$SETTINGS"
grep -q '"SessionEnd"' "$SETTINGS"
grep -q 'on-session-start.sh' "$SETTINGS"
grep -q 'on-session-end.sh' "$SETTINGS"

COUNT2="$(grep -o '"command":' "$SETTINGS" | wc -l | tr -d ' ')"
[ "$COUNT2" -eq 4 ]
echo "OK [2]"

echo "OK"
