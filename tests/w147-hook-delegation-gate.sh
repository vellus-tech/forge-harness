#!/usr/bin/env bash
# Gate W147 — delegação NUNCA sucede em alvo ausente (issue #49, instância 4).
#
# Chamar algo que não existe é ERRO, não no-op. O `post-merge` do axis-go-cloud concluía com
# sucesso quando o alvo da delegação não existia, produzindo o mesmo desfecho de uma execução
# bem-sucedida — e um harness atualizado pela metade, ou um script apagado à mão, passava
# despercebido indefinidamente.
#
# A regra que os hooks passam a seguir: o no-op só é legítimo quando o harness NÃO está instalado.
# Se o diretório que hospeda o alvo existe, a ausência do alvo é falha.
#
#   [1] post-merge: .forge/scripts/lib/ presente e changelog-from-merge.mjs ausente → ERRO visível
#   [2] post-merge: alvo presente porém FALHANDO → o hook não reporta sucesso
#   [3] commit-msg: .forge/scripts/ presente e check-ai-attribution.sh ausente → BLOQUEIA
#   [4] pre-push: gate declarado em runtime.gates cujo script não existe → BLOQUEIA (era "skip")
#   [5] pre-push: .forge/hooks/git/lib/ presente e check-docs-reviewed.sh ausente → BLOQUEIA
#   [6] pre-commit: .forge/scripts/ presente e check-secrets.sh ausente → BLOQUEIA
#   [7] repositório SEM .forge/ nenhum: os hooks seguem no-op (a degradação legítima)
#   [8] AUTO-IRONIA: o universo de hooks varrido por este gate é contado e não pode ser vazio,
#       e um hook novo em template/.forge/hooks/git/ sem cenário aqui reprova
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$WS/template/.forge/hooks/git"

T="$(mktemp -d /tmp/forge-w147.XXXXXX)"
trap 'rm -rf "$T"' EXIT

ZERO=0000000000000000000000000000000000000000

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
echo "[1] post-merge: alvo de delegação ausente com .forge/scripts/lib/ presente → ERRO visível"
R1="$T/r1"; mkrepo "$R1"
rm -f "$R1/.forge/scripts/lib/changelog-from-merge.mjs"
out="$(cd "$R1" && bash "$R1/.forge/hooks/git/post-merge" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [1]: post-merge concluiu com sucesso delegando para um alvo que não existe (saída: '$out')"
  exit 1
fi
case "$out" in
  *changelog-from-merge.mjs*) : ;;
  *) echo "FAIL [1]: falhou sem nomear o alvo ausente (saída: '$out')"; exit 1 ;;
esac
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] post-merge: alvo presente porém FALHANDO → o hook não reporta sucesso"
printf 'process.exit(3);\n' > "$R1/.forge/scripts/lib/changelog-from-merge.mjs"
out="$(cd "$R1" && bash "$R1/.forge/hooks/git/post-merge" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [2]: post-merge reportou sucesso com a delegação falhando (saída: '$out')"
  exit 1
fi
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] commit-msg: check-ai-attribution.sh ausente com .forge/scripts/ presente → BLOQUEIA"
R3="$T/r3"; mkrepo "$R3"
rm -f "$R3/.forge/scripts/check-ai-attribution.sh"
printf 'chore: mensagem qualquer\n' > "$T/msg3.txt"
out="$(cd "$R3" && bash "$R3/.forge/hooks/git/commit-msg" "$T/msg3.txt" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [3]: commit-msg aprovou a mensagem sem o gate que deveria delegar (saída: '$out')"
  exit 1
fi
echo "OK [3]"

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] pre-push: gate declarado em runtime.gates cujo script não existe → BLOQUEIA"
R4="$T/r4"; mkrepo "$R4"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n  gates: gate-fantasma\n' > "$R4/.forge/FORGE.md"
SHA4="$(git -C "$R4" rev-parse HEAD)"
out="$(cd "$R4" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA4" "$ZERO" | bash "$R4/.forge/hooks/git/pre-push" origin "file://$R4" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [4]: pre-push passou com um gate declarado e inexistente — declarar e não existir virou silêncio verde (saída: '$out')"
  exit 1
fi
case "$out" in
  *gate-fantasma*) : ;;
  *) echo "FAIL [4]: bloqueou sem nomear o gate declarado ausente (saída: '$out')"; exit 1 ;;
esac
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] pre-push: .forge/hooks/git/lib/ presente e check-docs-reviewed.sh ausente → BLOQUEIA"
R5="$T/r5"; mkrepo "$R5"
rm -f "$R5/.forge/hooks/git/lib/check-docs-reviewed.sh"
SHA5="$(git -C "$R5" rev-parse HEAD)"
out="$(cd "$R5" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA5" "$ZERO" | bash "$R5/.forge/hooks/git/pre-push" origin "file://$R5" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [5]: pre-push passou com a lib de docs-reviewed sumida do diretório de libs (saída: '$out')"
  exit 1
fi
case "$out" in
  *check-docs-reviewed.sh*) : ;;
  *) echo "FAIL [5]: bloqueou sem nomear a lib ausente (saída: '$out')"; exit 1 ;;
esac
echo "OK [5]"

# ── [6] ──────────────────────────────────────────────────────────────────────────────────────
echo "[6] pre-commit: check-secrets.sh ausente com .forge/scripts/ presente → BLOQUEIA"
R6="$T/r6"; mkrepo "$R6"
rm -f "$R6/.forge/scripts/check-secrets.sh"
printf 'novo\n' > "$R6/b.txt"
git -C "$R6" add b.txt >/dev/null 2>&1
out="$(cd "$R6" && bash "$R6/.forge/hooks/git/pre-commit" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [6]: pre-commit aprovou o índice sem o gate de segredo que deveria delegar (saída: '$out')"
  exit 1
fi
case "$out" in
  *check-secrets.sh*) : ;;
  *) echo "FAIL [6]: bloqueou sem nomear o alvo ausente (saída: '$out')"; exit 1 ;;
esac
echo "OK [6]"

# ── [7] ──────────────────────────────────────────────────────────────────────────────────────
echo "[7] repositório SEM .forge/ nenhum: os hooks seguem no-op (degradação legítima)"
R7="$T/r7"; mkdir -p "$R7"
git -C "$R7" init -q -b main
git -C "$R7" config user.email t@t; git -C "$R7" config user.name t; git -C "$R7" config commit.gpgsign false
printf 'x\n' > "$R7/a.txt"; git -C "$R7" add -A >/dev/null 2>&1
git -C "$R7" commit -qm "chore: init" >/dev/null 2>&1
printf 'chore: msg\n' > "$T/msg7.txt"
for h in commit-msg post-merge; do
  args=""; [ "$h" = "commit-msg" ] && args="$T/msg7.txt"
  # shellcheck disable=SC2086
  out="$(cd "$R7" && bash "$HOOKS/$h" $args 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL [7]: $h reprovou num repositório sem harness instalado (rc=$rc, saída: '$out')"; exit 1; }
done
SHA7="$(git -C "$R7" rev-parse HEAD)"
out="$(cd "$R7" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA7" "$ZERO" | bash "$HOOKS/pre-push" origin "file://$R7" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [7]: pre-push reprovou num repositório sem harness instalado (rc=$rc, saída: '$out')"; exit 1; }
echo "OK [7]"

# ── [8] AUTO-IRONIA ──────────────────────────────────────────────────────────────────────────
echo "[8] o universo de hooks é contado, não pode ser vazio, e hook novo sem cenário reprova"
COBERTOS="commit-msg post-merge pre-commit pre-push"
n_hooks=0
for f in "$HOOKS"/*; do
  [ -f "$f" ] || continue
  n_hooks=$((n_hooks + 1))
  nome="$(basename "$f")"
  case " $COBERTOS " in
    *" $nome "*) : ;;
    *) echo "FAIL [8]: hook '$nome' existe em template/.forge/hooks/git/ e não tem cenário neste gate — delegação não coberta é delegação não verificada"; exit 1 ;;
  esac
done
if [ "$n_hooks" -eq 0 ]; then
  echo "FAIL [8]/universo-vazio — 0 hook(s) examinado(s) em $HOOKS: o gate não examinou nada."
  echo "      Um gate de delegação que aprova por não ter olhado é a instância 1 dentro da correção da 4."
  exit 1
fi
echo "OK [8] — $n_hooks hook(s) examinado(s)"

echo "PASS w147-hook-delegation"
