#!/usr/bin/env bash
# Gate W277 — `FORGE_SECRETS_ENFORCE` sobrepõe o `secrets.enforce` do forge.yaml por invocação, e valor inválido reprova (Refs #174).
#
# POR QUE ESTE GATE EXISTE. O ensaio de campo da 0.16.0 achou num consumidor um `check-secrets.sh` que aceitava `FORGE_SECRETS_ENFORCE=warn|block` e reprovava qualquer outro valor com rc 2. O template nunca recebeu essa correção, e a versão do template IGNORAVA a variável em silêncio: o hook do consumidor invoca `FORGE_SECRETS_ENFORCE=block check-secrets.sh range <push>` para que o segredo que ENTRA no push bloqueie enquanto o passivo herdado (forge.yaml em `warn`) só avisa — com o template, esse push passava com rc 0 e um WARN, e o segredo novo entrava. A assimetria "o passivo avisa, o que entra bloqueia" é o único desenho que nem trava o time no dia da adoção (block global) nem deixa passar a ocorrência seguinte (warn global), e ela só existe se a política puder variar por invocação.
#
#   [1]  forge.yaml `warn` + FORGE_SECRETS_ENFORCE=block em modo range → achado reprova (rc != 0, FAIL)
#   [2]  forge.yaml `block` + FORGE_SECRETS_ENFORCE=warn em modo path → achado vira WARN, rc 0
#   [3]  FORGE_SECRETS_ENFORCE com valor inválido → rc 2 e mensagem nomeando a variável, mesmo sem achado no alvo
#   [4]  controle: variável ausente ou vazia → o forge.yaml governa (warn → rc 0; block → rc != 0)
#   [5]  integridade ignora o override: vacuidade reprova com FORGE_SECRETS_ENFORCE=warn
#   [6]  o modo report continua inventário (rc 0) mesmo com FORGE_SECRETS_ENFORCE=block
set -uo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado faria os comandos git abaixo obedecerem ao repositório de quem invocou o gate.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG
unset FORGE_SECRETS_ENFORCE FORGE_ROOT FORGE_SECRETS_ALLOWLIST

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${W277_CHECK:-$WS/template/.forge/scripts/check-secrets.sh}"
[ -f "$CHECK" ] || { echo "FAIL (check-secrets.sh ausente em $CHECK)"; exit 1; }

T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w276.XXXXXX")"
trap 'rm -rf "$T"' EXIT

FALHAS=0
falha() { echo "FAIL $*"; FALHAS=$((FALHAS + 1)); }

run_gate() { # run_gate <env-value|-> <args...> — "-" = variável ausente; ecoa em $out, rc em $rc
  local v="$1"; shift
  if [ "$v" = "-" ]; then
    out="$(env -u FORGE_SECRETS_ENFORCE bash "$CHECK" "$@" 2>&1)"; rc=$?
  else
    out="$(FORGE_SECRETS_ENFORCE="$v" bash "$CHECK" "$@" 2>&1)"; rc=$?
  fi
}

mkfix() { # mkfix <dir> <warn|block> — repositório git com forge.yaml declarando a política
  mkdir -p "$1/.forge"
  printf 'version: 1\nsecrets:\n  enforce: %s\n' "$2" > "$1/.forge/forge.yaml"
  git -C "$1" init -q -b main
  git -C "$1" config user.email dev@test
  git -C "$1" config user.name dev
  git -C "$1" config commit.gpgsign false
  printf 'nada aqui\n' > "$1/README.md"
  git -C "$1" add -A -f >/dev/null 2>&1
  git -C "$1" commit -qm base >/dev/null 2>&1
}

add_secret() { # add_secret <dir> — commit que INTRODUZ um segredo versionado
  printf 'db:\n  password: SenhaLiteralNova9\n' > "$1/values.yaml"
  git -C "$1" add -A -f >/dev/null 2>&1
  git -C "$1" commit -qm segredo >/dev/null 2>&1
}

echo "[1] forge.yaml warn + FORGE_SECRETS_ENFORCE=block em range → o segredo que entra no push reprova"
R1="$T/r1"; mkfix "$R1" warn; add_secret "$R1"
( cd "$R1" && run_gate block range HEAD~1..HEAD; echo "$rc" > "$T/rc1"; printf '%s' "$out" > "$T/out1" )
rc="$(cat "$T/rc1")"; out="$(cat "$T/out1")"
if [ "$rc" -eq 0 ]; then
  falha "[1]: FORGE_SECRETS_ENFORCE=block foi ignorado — o push com segredo novo passou com rc 0 (o forge.yaml warn venceu): $out"
elif ! grep -q "FAIL secrets/conn-cred" <<<"$out"; then
  falha "[1]: rc=$rc mas sem o FAIL do achado — reprovou por outra causa: $out"
else
  echo "OK [1] (rc=$rc)"
fi

echo "[2] forge.yaml block + FORGE_SECRETS_ENFORCE=warn em path → o achado vira aviso"
R2="$T/r2"; mkfix "$R2" block; add_secret "$R2"
run_gate warn path "$R2"
if [ "$rc" -ne 0 ]; then
  falha "[2]: FORGE_SECRETS_ENFORCE=warn foi ignorado — o forge.yaml block venceu (rc=$rc): $out"
elif ! grep -q "WARN secrets/conn-cred" <<<"$out"; then
  falha "[2]: rc 0 mas o achado sumiu em vez de virar aviso — pior que bloquear: $out"
else
  echo "OK [2]"
fi

echo "[3] valor inválido → rc 2 nomeando a variável, mesmo com o alvo limpo"
R3="$T/r3"; mkfix "$R3" warn
f0=$FALHAS
for v in bloquear BLOCK 'warn ' 1; do
  run_gate "$v" path "$R3"
  if [ "$rc" -ne 2 ]; then
    falha "[3]: FORGE_SECRETS_ENFORCE='$v' saiu rc=$rc (esperado 2) — valor inválido aceito em silêncio: $out"
  elif ! grep -q "FORGE_SECRETS_ENFORCE" <<<"$out"; then
    falha "[3]: FORGE_SECRETS_ENFORCE='$v' saiu rc 2 sem nomear a variável — quem lê não sabe o que corrigir: $out"
  fi
done
[ "$FALHAS" -eq "$f0" ] && echo "OK [3]"

echo "[4] controle: variável ausente ou vazia → o forge.yaml governa"
f0=$FALHAS
for v in - ''; do
  run_gate "$v" path "$R2"   # R2: forge.yaml block, com segredo
  [ "$rc" -ne 0 ] || falha "[4]: variável '${v:-<vazia>}' com forge.yaml block passou (rc 0): $out"
  run_gate "$v" path "$R1"   # R1: forge.yaml warn, com segredo
  [ "$rc" -eq 0 ] || falha "[4]: variável '${v:-<vazia>}' com forge.yaml warn bloqueou (rc=$rc): $out"
done
[ "$FALHAS" -eq "$f0" ] && echo "OK [4]"

echo "[5] integridade ignora o override: vacuidade reprova com FORGE_SECRETS_ENFORCE=warn"
run_gate warn path "$R1/nao-existe"
if [ "$rc" -eq 0 ]; then falha "[5]: vacuidade passou sob FORGE_SECRETS_ENFORCE=warn — gate que não rodou não pode se reportar verde: $out"; else echo "OK [5] (rc=$rc)"; fi

echo "[6] modo report continua inventário com FORGE_SECRETS_ENFORCE=block"
run_gate block report "$R1"
if [ "$rc" -ne 0 ]; then falha "[6]: report reprovou sob FORGE_SECRETS_ENFORCE=block — o inventário não é política (rc=$rc): $out"
elif ! grep -q "REPORT secrets" <<<"$out"; then falha "[6]: report não emitiu o inventário: $out"
else echo "OK [6]"; fi

if [ "$FALHAS" -gt 0 ]; then echo "W277 FAIL — $FALHAS falha(s)"; exit 1; fi
echo "W277 OK"
