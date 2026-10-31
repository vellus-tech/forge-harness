#!/usr/bin/env bash
# Gate W291 — resolve-skill.sh <nome> [<arquivo>...] (TASK-08).
#
# Ordem: FORGE_SKILL_DIR_<NOME> -> .forge/skills/<nome>/ do projeto -> skill de usuario do
# adapter ativo ($HOME/.claude/skills/<nome>). Ausencia nas tres: FAIL skill <nome> ausente, rc 1.
#
# Cenarios:
#   [1] so .forge/skills/<nome> presente -> resolve esse
#   [2] FORGE_SKILL_DIR_<NOME> definido -> tem precedencia
#   [3] nenhuma das tres -> FAIL skill <nome> ausente, rc 1
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$WS/template/.forge/scripts/resolve-skill.sh"

T="$(mktemp -d /tmp/forge-w291.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] so .forge/skills/<nome> presente -> resolve esse"
R1="$T/r1"; mkdir -p "$R1/.forge/skills/minhaskill"
printf 'conteudo\n' > "$R1/.forge/skills/minhaskill/SKILL.md"
out="$(cd "$R1" && FORGE_ROOT="$R1" bash "$SCRIPT" minhaskill 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [1]: rc=$rc saida: $out"; exit 1; }
case "$out" in
  *".forge/skills/minhaskill"*) : ;;
  *) echo "FAIL [1]: saida nao aponta para .forge/skills/minhaskill (saida: $out)"; exit 1 ;;
esac
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] FORGE_SKILL_DIR_<NOME> definido -> tem precedencia"
R2="$T/r2"; mkdir -p "$R2/.forge/skills/minhaskill" "$T/override-minhaskill"
printf 'conteudo projeto\n' > "$R2/.forge/skills/minhaskill/SKILL.md"
printf 'conteudo override\n' > "$T/override-minhaskill/SKILL.md"
out="$(cd "$R2" && FORGE_ROOT="$R2" FORGE_SKILL_DIR_MINHASKILL="$T/override-minhaskill" bash "$SCRIPT" minhaskill 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [2]: rc=$rc saida: $out"; exit 1; }
case "$out" in
  *"$T/override-minhaskill"*) : ;;
  *) echo "FAIL [2]: FORGE_SKILL_DIR_MINHASKILL nao teve precedencia (saida: $out)"; exit 1 ;;
esac
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] nenhuma das tres -> FAIL skill <nome> ausente, rc 1"
R3="$T/r3"; mkdir -p "$R3"
out="$(cd "$R3" && FORGE_ROOT="$R3" HOME="$T/home-vazio" bash "$SCRIPT" skillfantasma 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL [3]: rc esperado 1, obtido $rc (saida: $out)"; exit 1; }
case "$out" in
  *"FAIL skill skillfantasma ausente"*) : ;;
  *) echo "FAIL [3]: mensagem nao casa com 'FAIL skill skillfantasma ausente' (saida: $out)"; exit 1 ;;
esac
echo "OK [3]"

echo "PASS w291-resolve-skill"
