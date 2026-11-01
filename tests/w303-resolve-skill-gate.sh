#!/usr/bin/env bash
# Gate W303 — resolve-skill.sh <nome> [<arquivo>...] (TASK-08).
#
# Ordem: FORGE_SKILL_DIR_<NOME> -> .forge/skills/<nome>/ do projeto -> skill de usuario do
# adapter ativo ($HOME/.claude/skills/<nome>). Ausencia nas tres: FAIL skill <nome> ausente, rc 1.
#
# Cenarios:
#   [1] so .forge/skills/<nome> presente -> resolve esse
#   [2] FORGE_SKILL_DIR_<NOME> definido -> tem precedencia
#   [3] nenhuma das tres -> FAIL skill <nome> ausente, rc 1
#   [4] override definido mas inválido -> rc 1, sem queda silenciosa
#   [5] nome com travessia de caminho -> rc 2
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$WS/template/.forge/scripts/resolve-skill.sh"

T="$(mktemp -d /tmp/forge-w303.XXXXXX)"
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

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] override definido mas inválido -> rc 1, sem cair para a cópia do projeto"
out="$(cd "$R2" && FORGE_ROOT="$R2" FORGE_SKILL_DIR_MINHASKILL="$T/nao-existe" bash "$SCRIPT" minhaskill 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL [4]: rc esperado 1, obtido $rc (saída: $out)"; exit 1; }
case "$out" in
  *"$R2/.forge/skills/minhaskill"*) echo "FAIL [4]: caiu em silêncio para a cópia do projeto (saída: $out)"; exit 1 ;;
esac
mkdir -p "$T/override-incompleto"
out="$(cd "$R2" && FORGE_ROOT="$R2" FORGE_SKILL_DIR_MINHASKILL="$T/override-incompleto" bash "$SCRIPT" minhaskill SKILL.md 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL [4]: override sem o arquivo obrigatório aceito (rc=$rc, saída: $out)"; exit 1; }
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] nome com travessia de caminho -> rc 2"
out="$(cd "$R2" && FORGE_ROOT="$R2" bash "$SCRIPT" ../../tmp 2>&1)"; rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL [5]: rc esperado 2, obtido $rc (saída: $out)"; exit 1; }
echo "OK [5]"

echo "PASS w303-resolve-skill"
