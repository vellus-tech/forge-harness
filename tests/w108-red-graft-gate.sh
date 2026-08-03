#!/usr/bin/env bash
# Gate W108 — Red-first REPLAY, base por ENXERTO DO TESTE (rule testing/regression-red-first.md).
# Cobre o buraco entre as duas estratégias existentes (w107[1] ancestry, w107[4] revert-synthesis):
# teste e correção no MESMO commit (squash) E um commit POSTERIOR tocando os mesmos fix_files.
#
# Nesse arranjo, as duas estratégias antigas erram:
#   - ancestry deriva base = parent(commit-de-ruído), que JÁ contém a correção -> o replay afirma
#     "teste já passa na árvore base" (afirmação falsa: o motor não mediu o que diz ter medido);
#   - revert-synthesis reverte o ÚLTIMO commit que tocou o arquivo (o ruído), não a correção; e
#     quando reverte o commit certo, o patch pode não aplicar sobre um HEAD que evoluiu.
# A base que existe de fato é parent(caseCommit) com o test_path enxertado de lá — 'test-graft'.
#
#   [1] squash + commit posterior de ruído -> replay observa Red por test-graft
#   [2] base_commit = parent(caseCommit) e graft_from = caseCommit (auditor reproduz)
#   [3] o enxerto não afrouxa nenhuma recusa: teste que passa na base pré-correção reprova (item 2)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w108.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
git -C "$T" init -q -b main
git -C "$T" config user.email t@t
git -C "$T" config user.name t
git -C "$T" config commit.gpgsign false
git -C "$T" add -A
git -C "$T" commit -qm "chore: init harness" >/dev/null

SN="$T/.forge/scripts/spec-new.sh"
RE="$T/.forge/scripts/red-evidence.sh"

json_field() { node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))[process.argv[2]] ?? 'null')" "$1" "$2"; }

echo "[1] squash (teste+correção juntos) + commit posterior de ruído -> test-graft observa o Red"
mkdir -p "$T/src8" "$T/tests8"
cat > "$T/src8/mul.mjs" <<'JS'
export function mul(a, b) { return a + b; }
JS
git -C "$T" add src8/mul.mjs
git -C "$T" commit -qm "feat: mul (com bug — soma em vez de multiplicar)" >/dev/null

# squash: o teste de regressão E a correção entram no MESMO commit
cat > "$T/src8/mul.mjs" <<'JS'
export function mul(a, b) { return a * b; }
JS
cat > "$T/tests8/mul.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mul } from '../src8/mul.mjs';
test('bug-8-regression', () => { assert.strictEqual(mul(3, 4), 12); });
JS
git -C "$T" add src8/mul.mjs tests8/mul.test.mjs
git -C "$T" commit -qm "fix: bug-8 — mul multiplica (teste e correção juntos)" >/dev/null
CASE_COMMIT="$(git -C "$T" rev-parse HEAD)"
BASE_EXPECTED="$(git -C "$T" rev-parse HEAD^)"

# commit POSTERIOR de ruído no mesmo fix_file: reescreve a linha corrigida, sem relação com o bug.
# É o que faz ancestry escolher uma base já corrigida E o patch reverso do squash não aplicar.
cat > "$T/src8/mul.mjs" <<'JS'
export function mul(a, b) { return Number(a) * Number(b); }
JS
git -C "$T" add src8/mul.mjs
git -C "$T" commit -qm "refactor: coage entradas de mul (nada a ver com bug-8)" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-8 --type bugfix --scale 1 >/dev/null
DIR8="$T/.forge/specs/active/bug-8"
FORGE_ROOT="$T" bash "$RE" record bug-8 --test-path tests8/mul.test.mjs --test-id bug-8-regression \
  --command "node --test tests8/mul.test.mjs" --fix-files src8/mul.mjs --failure-pattern AssertionError >/dev/null

out="$(FORGE_ROOT="$T" bash "$RE" replay bug-8 2>&1)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [1] (replay não observou o Red: $out)"; exit 1; }
EV8="$DIR8/evidence/red/red-evidence.json"
[ "$(json_field "$EV8" status)" = "observed" ] || { echo "FAIL [1] (status != observed: $(json_field "$EV8" status))"; exit 1; }
[ "$(json_field "$EV8" base_strategy)" = "test-graft" ] || { echo "FAIL [1] (base_strategy esperado test-graft, veio $(json_field "$EV8" base_strategy))"; exit 1; }
[ "$(json_field "$EV8" classification)" = "behavioral" ] || { echo "FAIL [1] (falha na base não classificada como behavioral)"; exit 1; }
echo "OK [1]"

echo "[2] base_commit = parent(caseCommit) e graft_from = caseCommit"
[ "$(json_field "$EV8" base_commit)" = "$BASE_EXPECTED" ] || { echo "FAIL [2] (base_commit $(json_field "$EV8" base_commit) != parent do squash $BASE_EXPECTED)"; exit 1; }
[ "$(json_field "$EV8" graft_from)" = "$CASE_COMMIT" ] || { echo "FAIL [2] (graft_from $(json_field "$EV8" graft_from) != commit do squash $CASE_COMMIT)"; exit 1; }
echo "OK [2]"

echo "[3] enxerto não afrouxa recusa: teste que já passava na base pré-correção reprova (item 2)"
mkdir -p "$T/src9" "$T/tests9"
cat > "$T/src9/ok.mjs" <<'JS'
export function ok() { return 1; }
JS
git -C "$T" add src9/ok.mjs
git -C "$T" commit -qm "feat: ok" >/dev/null
# squash que NÃO corrige nada de fato — o teste passa igual na árvore anterior
cat > "$T/src9/ok.mjs" <<'JS'
export function ok() { return 1; } // comentário
JS
cat > "$T/tests9/ok.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ok } from '../src9/ok.mjs';
test('bug-9-regression', () => { assert.strictEqual(ok(), 1); });
JS
git -C "$T" add src9/ok.mjs tests9/ok.test.mjs
git -C "$T" commit -qm "fix: bug-9 — teste e 'correção' juntos" >/dev/null
cat > "$T/src9/ok.mjs" <<'JS'
export function ok() { return Number(1); }
JS
git -C "$T" add src9/ok.mjs
git -C "$T" commit -qm "refactor: ruído em ok" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-9 --type bugfix --scale 1 >/dev/null
DIR9="$T/.forge/specs/active/bug-9"
FORGE_ROOT="$T" bash "$RE" record bug-9 --test-path tests9/ok.test.mjs --test-id bug-9-regression \
  --command "node --test tests9/ok.test.mjs" --fix-files src9/ok.mjs --failure-pattern AssertionError >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-9 2>&1)" && rc=0 || rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [3] (replay aceitou evidência de um teste que já passava na base: $out)"; exit 1; }
grep -qi "não reproduz\|nao reproduz" <<<"$out" || { echo "FAIL [3] (recusa não cita 'não reproduz': $out)"; exit 1; }
[ "$(json_field "$DIR9/evidence/red/red-evidence.json" status)" != "observed" ] || { echo "FAIL [3] (status observed indevido)"; exit 1; }
echo "OK [3]"

echo "[4] falha de gate bash ('FAIL [n] (...)') classifica como comportamental, não 'unknown'"
# Sem esta assinatura, nenhum bugfix de um repositório cujos testes são gates shell consegue Red
# observado: o replay roda o gate, vê a falha real, e a recusa por 'item 3 — erro de build'. O
# formato é convenção estabelecida (todo gate deste repo emite `FAIL [n] (motivo)`), e a âncora de
# início de linha evita casar prosa que mencione a palavra no meio de uma frase.
node -e "
import('$WS/template/.forge/scripts/lib/red-classify.mjs').then((m) => {
  const cases = [
    ['FAIL [1] (hooksPath sobrescrito)', 'behavioral'],
    ['[3] update em repo com hooksPath customizado\nFAIL [3] (update sobrescreveu hooksPath)', 'behavioral'],
    ['tudo certo por aqui, sem FAIL [1] no meio da frase', 'unknown'],
    ['SyntaxError: Unexpected token', 'build-error'],
  ];
  for (const [text, want] of cases) {
    const got = m.classify(text);
    if (got !== want) { console.log('FAIL [4] (classify(' + JSON.stringify(text.slice(0, 40)) + ') = ' + got + ', esperado ' + want + ')'); process.exit(1); }
  }
  process.exit(0);
});
" || { echo "FAIL [4] (classificador não reconhece falha de gate bash)"; exit 1; }
echo "OK [4]"

echo "PASS w108-red-graft-gate"
