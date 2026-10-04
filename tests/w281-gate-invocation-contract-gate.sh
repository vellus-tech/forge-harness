#!/usr/bin/env bash
# Gate W281 — contrato ÚNICO de invocação dos gates de runtime.gates (issue #192).
#
# Antes do fix, spec-verify.sh e run-gates.sh chamavam todo gate como `bash <gate>.sh <change-id>`,
# enquanto o pre-push sempre chamou `bash <gate>.sh --path <raiz>`. Gate de consumidor que valida a
# própria linha de comando (aceita só `[--path <raiz>]`) recusava o posicional e o /forge:verify
# reprovava por defeito de CHAMADA, sem achado nenhum — o mesmo gate, na mesma árvore, passava no
# push. Os gates do próprio template também sofriam: check-secrets.sh ("modo desconhecido '<id>'")
# e check-authz.sh (universo vazio no diretório do change) reprovavam o verify sempre.
#
# Contrato, igual nos três chamadores: `FORGE_CHANGE_ID=<id> bash <gate>.sh --path <raiz>` — zero
# posicionais; o change-id viaja por variável de ambiente para quem precisar dele (no pre-push ela
# não existe, não há change em foco).
#
#   [1] spec-verify.sh: gate de fixture que REJEITA argumento desconhecido passa, e o marcador
#       gravado pelo próprio gate prova a forma exata da chamada (argv e FORGE_CHANGE_ID) — sinal
#       positivo de execução, não ausência de erro (rules/testing/gate-delivery-channel.md).
#   [2] run-gates.sh (fechamento de wave): mesma fixture, mesmo contrato, veredito OK.
#   [3] paridade: o pre-push chama com a MESMA forma (`--path '$ROOT'`) — âncora estática, porque o
#       laço do hook é exercitado de ponta a ponta em tests/w190.
#   [4] check-secrets.sh, declarado em runtime.gates (forma documentada no forge.yaml), passa no
#       verify — antes recebia o change-id como "modo" e reprovava com rc 2.
#   [5] check-data-governance.sh no verify continua lendo os artefatos do CHANGE: "RLS opcional"
#       no requirements.md do change reprova o verify (o anti-padrão literal do incidente, que o
#       modo `--path` sozinho não veria, porque a varredura de árvore pula .forge/).
#   [6] controle de [5]: o mesmo change sem o anti-padrão passa.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w281.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"
T_REAL="$(cd "$T" && pwd -P)"

mkdir -p "$T/src"
printf 'export const answer = 42;\n' > "$T/src/a.ts"
git -C "$T" init -q
git -C "$T" -c user.email=w281@t -c user.name=w281 add -A >/dev/null
git -C "$T" -c user.email=w281@t -c user.name=w281 commit -qm init >/dev/null

mk_change() {
  local id="$1"
  (cd "$T" && bash "$S/spec-new.sh" "$id" --type feature --scale 0 >/dev/null
              bash "$S/spec-transition.sh" "$id" tasks-ready >/dev/null
              bash "$S/spec-transition.sh" "$id" implementing >/dev/null)
  perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$T/.forge/specs/active/$id/tasks.md"
  (cd "$T" && bash "$S/spec-transition.sh" "$id" implemented >/dev/null)
}

declare_gates() {
  perl -pi -e "s/^  gates:.*\$/  gates: $1/" "$T/.forge/FORGE.md"
  grep -qE "^  gates: $1\$" "$T/.forge/FORGE.md"
}

# Gate de consumidor: só aceita `[--path <raiz>]`; qualquer outro argumento é erro de uso (rc 2),
# exatamente a forma dos gates do azim-crm no relato do #192. Grava a chamada num marcador.
MARK="$T/strict-calls.log"
cat > "$S/check-fixture-strict.sh" <<EOF
#!/usr/bin/env bash
root="."
while [ \$# -gt 0 ]; do
  case "\$1" in
    --path) root="\${2:?}"; shift 2 ;;
    *) echo "uso: check-fixture-strict.sh [--path <raiz>]"; echo "argumento desconhecido: \$1"; exit 2 ;;
  esac
done
printf 'root=%s change=%s\n' "\$(cd "\$root" && pwd -P)" "\${FORGE_CHANGE_ID:-<unset>}" >> "$MARK"
echo "OK check-fixture-strict"
EOF
chmod +x "$S/check-fixture-strict.sh"

echo "[1] spec-verify.sh: gate que rejeita posicional passa; chamada = --path <raiz> + FORGE_CHANGE_ID"
mk_change chg-strict
declare_gates check-fixture-strict
: > "$MARK"
set +e
OUT1="$(FORGE_ROOT="$T" bash "$S/spec-verify.sh" chg-strict 2>&1)"; RC1=$?
set -e
if [ "$RC1" -ne 0 ]; then
  echo "FAIL [1]: verify reprovou (rc=$RC1) com gate que só rejeita a forma da chamada: $OUT1"
  echo "  log do gate: $(cat /tmp/forge-verify-chg-strict-check-fixture-strict.log 2>/dev/null)"
  exit 1
fi
[ "$(cat "$MARK")" = "root=$T_REAL change=chg-strict" ] \
  || { echo "FAIL [1]: chamada inesperada — marcador: '$(cat "$MARK")'"; exit 1; }
grep -qE "command: \"FORGE_CHANGE_ID='chg-strict' bash '[^']*check-fixture-strict\.sh' --path '[^']*'\"" \
  "$T/.forge/specs/active/chg-strict/verification.yaml" \
  || { echo "FAIL [1]: verification.yaml não registra a forma da chamada: $(grep -A1 'check-fixture-strict' "$T/.forge/specs/active/chg-strict/verification.yaml")"; exit 1; }
echo "OK [1]"

echo "[2] run-gates.sh: mesmo contrato no fechamento de wave"
: > "$MARK"
set +e
OUT2="$(FORGE_ROOT="$T" bash "$S/run-gates.sh" chg-strict W1 2>&1)"; RC2=$?
set -e
[ "$RC2" -eq 0 ] && [ "$(printf '%s\n' "$OUT2" | tail -1)" = "OK" ] \
  || { echo "FAIL [2]: run-gates reprovou (rc=$RC2): $OUT2"; exit 1; }
[ "$(cat "$MARK")" = "root=$T_REAL change=chg-strict" ] \
  || { echo "FAIL [2]: chamada inesperada — marcador: '$(cat "$MARK")'"; exit 1; }
echo "OK [2]"

echo "[3] paridade: pre-push chama o gate com a mesma forma (--path '\$ROOT', sem posicional)"
grep -qF "run_check \"\$gate\" \"bash '\$gate_script' --path '\$ROOT'\"" "$WS/template/.forge/hooks/git/pre-push" \
  || { echo "FAIL [3]: pre-push não chama mais o gate com --path '\$ROOT' — contrato divergiu"; exit 1; }
for f in spec-verify.sh run-gates.sh; do
  if grep -nE "bash '\\\$(gate_script|script)' '\\\$ID'" "$WS/template/.forge/scripts/$f"; then
    echo "FAIL [3]: $f ainda passa o change-id como posicional"; exit 1
  fi
done
echo "OK [3]"

echo "[4] check-secrets.sh declarado em runtime.gates passa no verify"
mk_change chg-secrets
declare_gates check-secrets
set +e
OUT4="$(FORGE_ROOT="$T" bash "$S/spec-verify.sh" chg-secrets 2>&1)"; RC4=$?
set -e
LOG4="/tmp/forge-verify-chg-secrets-check-secrets.log"
[ "$RC4" -eq 0 ] || { echo "FAIL [4]: verify reprovou (rc=$RC4): $OUT4"; echo "  log: $(cat "$LOG4" 2>/dev/null)"; exit 1; }
grep -q 'modo desconhecido' "$LOG4" && { echo "FAIL [4]: check-secrets recebeu o change-id como modo"; exit 1; }
echo "OK [4]"

echo "[5] check-data-governance no verify ainda lê os artefatos do change (RLS opcional reprova)"
mk_change chg-rls
printf '\n- A tabela de tenants terá RLS opcional nesta fase.\n' >> "$T/.forge/specs/active/chg-rls/requirements.md"
declare_gates check-data-governance
set +e
OUT5="$(FORGE_ROOT="$T" bash "$S/spec-verify.sh" chg-rls 2>&1)"; RC5=$?
set -e
LOG5="/tmp/forge-verify-chg-rls-check-data-governance.log"
[ "$RC5" -ne 0 ] || { echo "FAIL [5]: verify passou com 'RLS opcional' no requirements.md do change — o gate deixou de ler o change: $OUT5"; exit 1; }
grep -q 'CONFLICT' "$LOG5" && grep -q 'requirements.md' "$LOG5" \
  || { echo "FAIL [5]: reprovou, mas não pelo achado de data-governance no requirements.md: $(cat "$LOG5")"; exit 1; }
echo "OK [5]"

echo "[6] controle de [5]: change sem o anti-padrão passa"
mk_change chg-clean
set +e
OUT6="$(FORGE_ROOT="$T" bash "$S/spec-verify.sh" chg-clean 2>&1)"; RC6=$?
set -e
[ "$RC6" -eq 0 ] || { echo "FAIL [6]: verify reprovou change limpo (rc=$RC6): $OUT6"; echo "  log: $(cat /tmp/forge-verify-chg-clean-check-data-governance.log 2>/dev/null)"; exit 1; }
grep -qE 'OK data-governance/universo — [1-9][0-9]* arquivo' /tmp/forge-verify-chg-clean-check-data-governance.log \
  || { echo "FAIL [6]: data-governance não examinou nada: $(cat /tmp/forge-verify-chg-clean-check-data-governance.log)"; exit 1; }
echo "OK [6]"

echo "OK"
