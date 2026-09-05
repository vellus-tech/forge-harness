#!/usr/bin/env bash
# Gate W170 — spec-verify.sh migrado para lib/forge-runtime.sh (LDG-0014, pré-requisito da Onda 3
# do #82 — sem isto, run-gates.sh ganhar seletor de fase criaria DOIS contratos de fase
# divergentes em silêncio: um na lib compartilhada, outro na cópia privada do spec-verify).
#
#   [0] CONTROLE: gate declarado cujo script existe e PASSA — spec-verify continua OK, o check
#       aparece em verification.yaml com status: passed (mesma superfície de tests/w90 [4], aqui
#       só para provar que a migração não regrediu o caminho feliz antes de qualquer vermelho).
#   [1] FIAÇÃO: spec-verify.sh não define mais get_runtime()/run_check() PRÓPRIOS — usa
#       forge_get_runtime/forge_run_gate de lib/forge-runtime.sh (a fonte ÚNICA, não uma 2ª cópia
#       que só passa a existir "de fato" quando alguém lembra de manter as duas em sincronia).
#   [2] gate DECLARADO cujo script está AUSENTE agora REPROVA o verify — antes disto era
#       WARN + skip (silêncio verde para um pré-requisito faltando), e run-gates.sh já REPROVAVA
#       o mesmo cenário: as duas cópias divergiam na norma mais importante das duas. Este é o
#       vermelho central do item — a mensagem exata é a que o fix precisa produzir.
#   [3] regressão: gate declarado, script existe, mas REPROVA (rc≠0) — continua reprovando
#       o verify (comportamento inalterado, não é isto que a migração muda).
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w170.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"

git -C "$T" init -q
git -C "$T" -c user.email=w170@t -c user.name=w170 add -A >/dev/null
git -C "$T" -c user.email=w170@t -c user.name=w170 commit -qm init >/dev/null

# mk_change <id> — leva um change scale 0 até `implemented` (tasks 100%), pronto para
# spec-verify.sh. Mesma receita de tests/w32 (mk_verified) e tests/w90 [4].
mk_change() {
  local id="$1"
  (cd "$T" && bash "$S/spec-new.sh" "$id" --type feature --scale 0 >/dev/null
              bash "$S/spec-transition.sh" "$id" tasks-ready >/dev/null
              bash "$S/spec-transition.sh" "$id" implementing >/dev/null)
  perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$T/.forge/specs/active/$id/tasks.md"
  (cd "$T" && bash "$S/spec-transition.sh" "$id" implemented >/dev/null)
}

# declare_gate <nome> — substitui a linha "  gates:" (vazia no template, ou já reescrita por uma
# chamada anterior — cada caso usa seu próprio $T/.forge/FORGE.md compartilhado) por um CSV
# escalar de um gate só. Forma retrocompatível de sempre (nunca block-sequence aqui — este gate
# testa a extração compartilhada, não a fase do #82).
declare_gate() {
  perl -pi -e "s/^  gates:.*\$/  gates: $1/" "$T/.forge/FORGE.md"
  grep -qE "^  gates: $1\$" "$T/.forge/FORGE.md"
}

echo "[0] CONTROLE: gate declarado e script PASSA — verify OK, check em verification.yaml"
mk_change chg-ok
declare_gate check-data-governance
FORGE_ROOT="$T" bash "$S/spec-verify.sh" chg-ok >/dev/null
VY="$T/.forge/specs/active/chg-ok/verification.yaml"
[ -f "$VY" ] || { echo "FAIL [0]: verification.yaml não gravado"; exit 1; }
grep -qE '^\s*- name: check-data-governance$' "$VY" || { echo "FAIL [0]: check não registrado"; exit 1; }
grep -qE '^\s*status: passed$' "$VY" || { echo "FAIL [0]: status não é passed — $(cat "$VY")"; exit 1; }
echo "OK [0]"

echo "[1] FIAÇÃO: spec-verify.sh usa lib/forge-runtime.sh — sem cópia própria de get_runtime/run_check"
if grep -qE '^\s*get_runtime\(\)\s*\{' "$S/spec-verify.sh"; then
  echo "FAIL [1]: spec-verify.sh ainda define get_runtime() localmente (LDG-0014 não migrado)"
  exit 1
fi
grep -qE '\.\s+"\$SCRIPT_DIR/lib/forge-runtime\.sh"' "$S/spec-verify.sh" \
  || { echo "FAIL [1]: spec-verify.sh não faz source de lib/forge-runtime.sh"; exit 1; }
grep -qE 'forge_get_runtime|forge_run_gate|forge_runtime_gates' "$S/spec-verify.sh" \
  || { echo "FAIL [1]: spec-verify.sh não chama nenhuma função da lib compartilhada"; exit 1; }
echo "OK [1]"

echo "[2] gate DECLARADO com script AUSENTE reprova o verify (norma da casa — run-gates.sh já reprovava)"
mk_change chg-missing
declare_gate check-fixture-ausente
rm -f "$S/check-fixture-ausente.sh" 2>/dev/null || true   # nunca existiu; garante ausência
set +e
OUT2="$(FORGE_ROOT="$T" bash "$S/spec-verify.sh" chg-missing 2>&1)"
RC2=$?
set -e
[ "$RC2" -ne 0 ] || { echo "FAIL [2]: verify passou (rc=0) com gate declarado e script ausente: $OUT2"; exit 1; }
grep -q 'FAIL' <<< "$OUT2" || { echo "FAIL [2]: saída não contém FAIL: $OUT2"; exit 1; }
grep -qE 'check-fixture-ausente: MISSING \(.*check-fixture-ausente\.sh não existe\)' <<< "$OUT2" \
  || { echo "FAIL [2]: mensagem não é a MISSING esperada (mesma forma de run-gates.sh) — saída: $OUT2"; exit 1; }
grep -qi 'WARN.*skip' <<< "$OUT2" && { echo "FAIL [2]: ainda emite o WARN+skip antigo (não migrado)"; exit 1; }
echo "OK [2]"

echo "[3] regressão: gate declarado, script existe, REPROVA — verify continua reprovando"
mk_change chg-fail
printf '#!/usr/bin/env bash\nexit 1\n' > "$S/check-fixture-falha.sh"
chmod +x "$S/check-fixture-falha.sh"
declare_gate check-fixture-falha
set +e
OUT3="$(FORGE_ROOT="$T" bash "$S/spec-verify.sh" chg-fail 2>&1)"
RC3=$?
set -e
[ "$RC3" -ne 0 ] || { echo "FAIL [3]: verify passou (rc=0) com gate que reprova: $OUT3"; exit 1; }
grep -q 'check-fixture-falha: failed' <<< "$OUT3" || { echo "FAIL [3]: gate que reprovou não aparece como failed: $OUT3"; exit 1; }
echo "OK [3]"

echo "OK"
