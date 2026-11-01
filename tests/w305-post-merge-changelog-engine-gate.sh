#!/usr/bin/env bash
# Gate W293 — post-merge religado ao motor único (TASK-10, add-unify-changelog-skill).
#
# O hook `post-merge` deixa de chamar `scripts/lib/changelog-from-merge.mjs` e passa a
# delegar para `skills/readme-generator/scripts/changelog-engine.mjs` em modo --merge-range,
# pelo mesmo `resolve_delegated()` que já existe (issue #49). O hook NUNCA usa
# `resolve-skill.sh` (REQ-07) — esse resolvedor é só do comando.
#
#   [1] alvo ausente com skills/readme-generator/ presente → delegation_failed, texto cita
#       scripts/changelog-engine.mjs
#   [2] .forge/ ausente inteiro → no-op silencioso, hook sai rc 0 sem mencionar o motor
#   [3] sem node no PATH → no-op sem erro (delegation_failed permanece 0)
#   [4] hook nunca commita — git log sem novo commit após rodar
#   [5] FORGE_SKILL_DIR_README_GENERATOR no ambiente NÃO é consultado pelo hook — alvo ausente
#       no projeto falha mesmo com override válido apontando para outro lugar
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$WS/template/.forge/hooks/git/post-merge"
ENGINE_REL="skills/readme-generator/scripts/changelog-engine.mjs"

T="$(mktemp -d /tmp/forge-w293.XXXXXX)"
trap 'rm -rf "$T"' EXIT

mkrepo() { # mkrepo <dir> — repo com harness completo instalado
  mkdir -p "$1"
  cp -R "$WS/template/.forge" "$1/.forge"
  git -C "$1" init -q -b main
  git -C "$1" config user.email t@t
  git -C "$1" config user.name t
  git -C "$1" config commit.gpgsign false
  printf 'x\n' > "$1/a.txt"
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" commit -qm "chore: init" >/dev/null 2>&1
}

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] alvo ausente com skills/readme-generator/ presente → delegation_failed citando changelog-engine.mjs"
R1="$T/r1"; mkrepo "$R1"
[ -d "$R1/.forge/skills/readme-generator" ] || { echo "FAIL [1]: fixture sem .forge/skills/readme-generator/ — pré-condição do cenário não bate"; exit 1; }
rm -f "$R1/.forge/$ENGINE_REL"
out="$(cd "$R1" && bash "$R1/.forge/hooks/git/post-merge" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [1]: post-merge concluiu com sucesso delegando para changelog-engine.mjs ausente (saída: '$out')"
  exit 1
fi
case "$out" in
  *changelog-engine.mjs*) : ;;
  *) echo "FAIL [1]: falhou sem nomear changelog-engine.mjs ausente (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *changelog-from-merge.mjs*) echo "FAIL [1]: saída ainda referencia o alvo antigo changelog-from-merge.mjs (saída: '$out')"; exit 1 ;;
esac
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] .forge/ ausente inteiro → no-op silencioso, hook sai rc 0"
R2="$T/r2"; mkdir -p "$R2"
git -C "$R2" init -q -b main
git -C "$R2" config user.email t@t; git -C "$R2" config user.name t; git -C "$R2" config commit.gpgsign false
printf 'x\n' > "$R2/a.txt"; git -C "$R2" add -A >/dev/null 2>&1
git -C "$R2" commit -qm "chore: init" >/dev/null 2>&1
HOOKS="$WS/template/.forge/hooks/git"
out="$(cd "$R2" && bash "$HOOKS/post-merge" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [2]: post-merge reprovou num repositório sem .forge/ (rc=$rc, saída: '$out')"; exit 1; }
case "$out" in
  *changelog-engine.mjs*|*FALHOU*) echo "FAIL [2]: hook mencionou o motor de changelog sem harness instalado (saída: '$out')"; exit 1 ;;
esac
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] sem node no PATH → no-op sem erro"
R3="$T/r3"; mkrepo "$R3"
stub="$T/stubbin"; mkdir -p "$stub"
for c in bash git sed head cat printf grep awk sort basename dirname mkdir rm cp mv find xargs tr wc; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$stub/$c"
done
out="$(cd "$R3" && PATH="$stub" bash "$R3/.forge/hooks/git/post-merge" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [3]: post-merge reprovou sem node no PATH (rc=$rc, saída: '$out')"; exit 1; }
case "$out" in
  *FALHOU*) echo "FAIL [3]: hook reportou falha de delegação só por node estar ausente do PATH (saída: '$out')"; exit 1 ;;
esac
echo "OK [3]"

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] hook nunca commita"
R4="$T/r4"; mkrepo "$R4"
before="$(git -C "$R4" rev-list --count HEAD)"
cd "$R4" && bash "$R4/.forge/hooks/git/post-merge" >/dev/null 2>&1; cd - >/dev/null
after="$(git -C "$R4" rev-list --count HEAD)"
[ "$before" = "$after" ] || { echo "FAIL [4]: post-merge criou commit novo (antes=$before depois=$after)"; exit 1; }
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] FORGE_SKILL_DIR_README_GENERATOR no ambiente NÃO é consultado pelo hook"
R5="$T/r5"; mkrepo "$R5"
rm -f "$R5/.forge/$ENGINE_REL"
OVERRIDE="$T/override-skill/scripts"
mkdir -p "$OVERRIDE"
printf '#!/usr/bin/env node\nprocess.exit(0);\n' > "$OVERRIDE/changelog-engine.mjs"
out="$(cd "$R5" && FORGE_SKILL_DIR_README_GENERATOR="$T/override-skill" bash "$R5/.forge/hooks/git/post-merge" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [5]: post-merge usou (ou aceitou) o override de ambiente — o hook não deveria consultar FORGE_SKILL_DIR_* (saída: '$out')"
  exit 1
fi
case "$out" in
  *changelog-engine.mjs*) : ;;
  *) echo "FAIL [5]: falhou por motivo diferente do esperado — alvo ausente no projeto deveria ser citado (saída: '$out')"; exit 1 ;;
esac
echo "OK [5]"

echo "PASS w293-post-merge-changelog-engine"
