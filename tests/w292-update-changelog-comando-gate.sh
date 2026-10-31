#!/usr/bin/env bash
# Gate W292 — verificacao estatica de template/.forge/commands/docs/update-changelog.md (TASK-09).
#
# Cenarios:
#   [1] trava de branch protegida (develop/master/main) documentada nos Passos a Executar
#   [2] deteccao de release-please-config.json documentada (REQ-10)
#   [3] os 4 gates nomeados explicitamente, incluindo check-ai-attribution.sh text
#   [4] nenhuma instrucao de "git commit" no corpo (comando nunca commita)
#   [5] resolve-skill.sh citado (REQ-12)
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="$WS/template/.forge/commands/docs/update-changelog.md"

[ -f "$CMD" ] || { echo "FAIL: comando nao encontrado em $CMD"; exit 1; }
body="$(cat "$CMD")"

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] trava de branch protegida documentada"
case "$body" in
  *develop*master*main*|*develop*|*master*|*main*)
    echo "$body" | grep -qiE 'develop.{0,40}master.{0,40}main|branch protegida' \
      || { echo "FAIL: comando nao documenta trava de branch protegida (develop/master/main)"; exit 1; }
    ;;
  *) echo "FAIL: comando nao menciona develop/master/main"; exit 1 ;;
esac
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] deteccao de release-please-config.json documentada"
echo "$body" | grep -q 'release-please-config.json' \
  || { echo "FAIL: comando nao documenta deteccao de release-please-config.json"; exit 1; }
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] os 4 gates nomeados explicitamente"
for gate in released preserve lint; do
  echo "$body" | grep -q "$gate" || { echo "FAIL: comando nao nomeia o gate '$gate'"; exit 1; }
done
echo "$body" | grep -q 'check-ai-attribution.sh text' \
  || { echo "FAIL: comando nao documenta check-ai-attribution.sh text"; exit 1; }
echo "OK [3]"

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] nenhuma instrucao de git commit no corpo (negacoes do tipo 'nunca'/'nenhum' nao contam)"
if echo "$body" | grep -iE 'git commit' | grep -viE 'nunca|nenhum|não commit|nao commit'; then
  echo "FAIL: comando instrui commit"; exit 1
fi
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] resolve-skill.sh citado"
echo "$body" | grep -q 'resolve-skill.sh' || { echo "FAIL: comando nao chama resolve-skill.sh"; exit 1; }
echo "OK [5]"

echo "PASS w292-update-changelog-comando"
