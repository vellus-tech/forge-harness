#!/usr/bin/env bash
# Gate W144 — contador de controle obrigatório (issue #49, instância 1).
#
# O modo de falha: um gate que itera sobre um universo e encontra o universo VAZIO imprime a
# mesma linha e devolve o mesmo `exit 0` de um gate que iterou sobre 37 itens e não achou
# violação. Quem lê o log não distingue cobertura de ausência de cobertura, e o placar fica verde
# nos dois casos. A instância medida: `red-first` imprimiu `OK — 0 change(s) examinado(s)` no push
# de um bugfix — o gate existe para exigir vermelho antes do verde em bugfix e passou justamente
# num bugfix.
#
# A correção tem três estados observáveis, nunca dois:
#   OK  <gate>/universo — N item(ns) examinado(s)               (examinou e estava limpo)
#   FAIL <gate>/universo-vazio — 0 item(ns) examinado(s)        (NÃO examinou — default)
#   OK  <gate>/universo-vazio — 0 ... justificativa declarada   (não examinou, e está declarado)
#
#   [1] hook red-first: push com commit fix(...) e ZERO change ativo type:bugfix BLOQUEIA
#   [2] hook red-first: o contador de controle sai com o número de changes examinados
#   [3] red-evidence.sh ci: nenhum change ativo é universo vazio e reprova
#   [4] red-evidence.sh ci: N changes ativos com 0 type:bugfix é OK, com contador distinto
#   [5] check-ai-attribution.sh range: range que resolve para 0 commit reprova
#   [6] justificativa declarada converte vacuidade em OK PRÓPRIO; entrada sem '# motivo:' reprova
#   [7] check-authz: universo de arquivos vazio reprova; com arquivo, OK com contador
#   [8] check-observability: idem
#   [9] check-data-governance: idem
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TPL="$WS/template/.forge"

T="$(mktemp -d /tmp/forge-w144.XXXXXX)"
trap 'rm -rf "$T"' EXIT

mkrepo() { # mkrepo <dir> — repo git com esqueleto .forge/ e os scripts do harness
  mkdir -p "$1/.forge/specs/active"
  cp -R "$TPL/scripts" "$1/.forge/scripts"
  mkdir -p "$1/.forge/hooks/git"
  cp -R "$TPL/hooks/git/lib" "$1/.forge/hooks/git/lib"
  git -C "$1" init -q -b main 2>/dev/null || { mkdir -p "$1"; git -C "$1" init -q -b main; }
  git -C "$1" config user.email dev@test
  git -C "$1" config user.name dev
  git -C "$1" config commit.gpgsign false
}

mkchange() { # mkchange <root> <id> <type>
  mkdir -p "$1/.forge/specs/active/$2"
  printf 'id: %s\ntype: %s\nscale: 1\nstatus: implementing\n' "$2" "$3" > "$1/.forge/specs/active/$2/manifest.yaml"
}

ZERO=0000000000000000000000000000000000000000

# ── [1] e [2] — hook red-first sob push de um commit fix(...) ────────────────────────────────
R1="$T/r1"; mkdir -p "$R1"; mkrepo "$R1"
echo init > "$R1/a.txt"; git -C "$R1" add -A; git -C "$R1" commit -qm "chore: init"
echo patch > "$R1/a.txt"; git -C "$R1" add -A; git -C "$R1" commit -qm "fix(pay): corrige arredondamento"
SHA1="$(git -C "$R1" rev-parse HEAD)"

echo "[1] hook red-first BLOQUEIA push de fix(...) com ZERO change ativo type:bugfix"
out="$(printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA1" "$ZERO" \
  | REPO="$R1" bash "$R1/.forge/hooks/git/lib/check-red-first.sh" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [1]: hook aprovou o push de um fix(...) sem ter examinado change algum (rc=$rc, saída: '$out')"
  exit 1
fi
case "$out" in
  *universo-vazio*) : ;;
  *) echo "FAIL [1]: hook reprovou mas sem nomear o estado de universo vazio (saída: '$out')"; exit 1 ;;
esac
echo "OK [1]"

echo "[2] hook red-first imprime o contador de controle com N examinados"
mkchange "$R1" chg-bug bugfix
out="$(printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA1" "$ZERO" \
  | REPO="$R1" bash "$R1/.forge/hooks/git/lib/check-red-first.sh" 2>&1)"; rc=$?
case "$out" in
  *"1 change(s) type:bugfix examinado(s)"*) : ;;
  *) echo "FAIL [2]: contador de controle ausente com 1 change type:bugfix ativo (rc=$rc, saída: '$out')"; exit 1 ;;
esac
echo "OK [2]"

# ── [3] e [4] — red-evidence.sh ci ───────────────────────────────────────────────────────────
R2="$T/r2"; mkdir -p "$R2"; mkrepo "$R2"

echo "[3] red-evidence.sh ci reprova quando não há change ativo algum"
out="$(FORGE_ROOT="$R2" bash "$TPL/scripts/red-evidence.sh" ci 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [3]: ci aprovou sem ter examinado change algum (rc=$rc, saída: '$out')"
  exit 1
fi
case "$out" in
  *universo-vazio*) : ;;
  *) echo "FAIL [3]: ci reprovou sem nomear o estado de universo vazio (saída: '$out')"; exit 1 ;;
esac
echo "OK [3]"

echo "[4] red-evidence.sh ci: 2 changes ativos e 0 type:bugfix é OK, com contador distinto"
mkchange "$R2" chg-feat feature
mkchange "$R2" chg-ref refactor
out="$(FORGE_ROOT="$R2" bash "$TPL/scripts/red-evidence.sh" ci 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL [4]: ci reprovou com 2 changes ativos examinados (rc=$rc, saída: '$out')"
  exit 1
fi
case "$out" in
  *"2 change(s) ativo(s) examinado(s)"*) : ;;
  *) echo "FAIL [4]: ci não imprimiu o contador de changes ativos examinados (saída: '$out')"; exit 1 ;;
esac
echo "OK [4]"

# ── [5] — check-ai-attribution.sh range vazio ────────────────────────────────────────────────
echo "[5] check-ai-attribution.sh range reprova quando o range resolve para 0 commit"
R3="$T/r3"; mkdir -p "$R3"; mkrepo "$R3"
echo a > "$R3/a.txt"; git -C "$R3" add -A; git -C "$R3" commit -qm "chore: init"
out="$(cd "$R3" && FORGE_ROOT="$R3" bash "$TPL/scripts/check-ai-attribution.sh" range HEAD..HEAD 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [5]: range vazio virou OK — 'não havia commit' e 'os commits estavam limpos' colapsaram (saída: '$out')"
  exit 1
fi
case "$out" in
  *universo-vazio*) : ;;
  *) echo "FAIL [5]: reprovou sem nomear o estado de universo vazio (saída: '$out')"; exit 1 ;;
esac
echo "OK [5]"

# ── [6] — justificativa declarada ────────────────────────────────────────────────────────────
echo "[6] justificativa declarada vira OK PRÓPRIO; entrada sem '# motivo:' reprova por integridade"
printf 'ai-attribution  # motivo: repositório de fixture, sem histórico próprio\n' \
  > "$R3/.forge/empty-universe-allowlist.txt"
out="$(cd "$R3" && FORGE_ROOT="$R3" bash "$TPL/scripts/check-ai-attribution.sh" range HEAD..HEAD 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL [6]: justificativa declarada não liberou a vacuidade (rc=$rc, saída: '$out')"
  exit 1
fi
case "$out" in
  *"justificativa declarada"*) : ;;
  *) echo "FAIL [6]: vacuidade justificada saiu indistinguível de um universo examinado (saída: '$out')"; exit 1 ;;
esac
printf 'ai-attribution\n' > "$R3/.forge/empty-universe-allowlist.txt"
out="$(cd "$R3" && FORGE_ROOT="$R3" bash "$TPL/scripts/check-ai-attribution.sh" range HEAD..HEAD 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [6]: isenção SEM justificativa passou — isenção anônima é como um gate é esvaziado (saída: '$out')"
  exit 1
fi
rm -f "$R3/.forge/empty-universe-allowlist.txt"
echo "OK [6]"

# ── [7]/[8]/[9] — os três gates de governança sobre universo de arquivos ─────────────────────
EMPTY="$T/vazio"; mkdir -p "$EMPTY"
FULL="$T/cheio"; mkdir -p "$FULL"
printf '# doc\n\nnada de mais.\n' > "$FULL/doc.md"
printf 'package main\nfunc main() {}\n' > "$FULL/main.go"

check_universe() { # check_universe <n> <nome> <script> [args-extra...]
  local n="$1" nome="$2" script="$3"; shift 3
  echo "[$n] $nome: universo de arquivos vazio reprova; com arquivo, OK com contador"
  out="$(FORGE_ROOT="$EMPTY" bash "$script" --path "$EMPTY" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "FAIL [$n]: $nome aprovou sem ter varrido arquivo algum (saída: '$out')"
    return 1
  fi
  case "$out" in
    *universo-vazio*) : ;;
    *) echo "FAIL [$n]: $nome reprovou sem nomear o estado de universo vazio (saída: '$out')"; return 1 ;;
  esac
  out="$(FORGE_ROOT="$FULL" bash "$script" --path "$FULL" "$@" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL [$n]: $nome reprovou sobre um alvo limpo com 2 arquivos (rc=$rc, saída: '$out')"
    return 1
  fi
  case "$out" in
    *"examinado(s)"*) : ;;
    *) echo "FAIL [$n]: $nome não imprimiu o contador de arquivos examinados (saída: '$out')"; return 1 ;;
  esac
  echo "OK [$n]"
  return 0
}

check_universe 7 check-authz            "$TPL/scripts/check-authz.sh" || exit 1
check_universe 8 check-observability    "$TPL/scripts/check-observability.sh" || exit 1
check_universe 9 check-data-governance  "$TPL/scripts/check-data-governance.sh" || exit 1

echo "PASS w144-gate-control-counter"
