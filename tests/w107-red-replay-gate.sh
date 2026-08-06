#!/usr/bin/env bash
# Gate W107 — Red-first REPLAY (Onda C, rule testing/regression-red-first.md): converte
# evidência DECLARADA em evidência OBSERVADA de fato, rodando o teste real em worktrees git
# efêmeros contra a árvore pré-correção derivada. Fixture: um defeito Node minúsculo
# (src/sum.mjs soma errado) com teste real (node --test, sem dependências externas).
#   [1] replay com falha comportamental na base (fluxo TDD: bug, teste, fix em commits
#       separados — estratégia ancestry) -> observed
#   [2] teste que já passava na base -> FAIL citando "não reproduz"
#   [3] erro de sintaxe na base -> FAIL citando build/compilação, não comportamento
#   [4] teste e correção no mesmo commit (squash) -> revert-synthesis funciona -> observed
#   [5] failure_pattern divergente -> FAIL
#   [6] base não derivável (test_path/fix_files sem histórico) -> not-possible, rebaixável,
#       exige waiver — nenhum worktree criado (rápido, nunca trava mudo)
#   [7] pre-push bloqueia commit fix(...) sem evidência resolvida e NÃO roda replay (prova:
#       nenhum worktree git criado durante o hook)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w107.XXXXXX)"
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

status_of() { node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).status)" "$1"; }

echo "[1] replay observa falha comportamental na base (estratégia ancestry)"
mkdir -p "$T/src" "$T/tests"
cat > "$T/src/sum.mjs" <<'JS'
export function sum(a, b) { return a - b; }
JS
git -C "$T" add src/sum.mjs
git -C "$T" commit -qm "feat: sum (com bug)" >/dev/null

cat > "$T/tests/sum.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sum } from '../src/sum.mjs';
test('bug-1-regression', () => { assert.strictEqual(sum(2, 3), 5); });
JS
git -C "$T" add tests/sum.test.mjs
git -C "$T" commit -qm "test: regressão bug-1 (sum soma errado)" >/dev/null

cat > "$T/src/sum.mjs" <<'JS'
export function sum(a, b) { return a + b; }
JS
git -C "$T" add src/sum.mjs
git -C "$T" commit -qm "fix: bug-1 — sum soma errado" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-1 --type bugfix --scale 1 >/dev/null
DIR1="$T/.forge/specs/active/bug-1"
out="$(FORGE_ROOT="$T" bash "$RE" record bug-1 --test-path tests/sum.test.mjs --test-id bug-1-regression --command "node --test tests/sum.test.mjs" --fix-files src/sum.mjs --failure-pattern AssertionError 2>&1)"
grep -q "OK record" <<<"$out" || { echo "FAIL: record não confirmou ($out)"; exit 1; }

out="$(FORGE_ROOT="$T" bash "$RE" replay bug-1 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: replay [1] esperava sucesso ($out)"; exit 1; }
grep -qi "observado" <<<"$out" || { echo "FAIL: saída não confirma observação ($out)"; exit 1; }
[ "$(status_of "$DIR1/evidence/red/red-evidence.json")" = "observed" ] || { echo "FAIL: status != observed"; exit 1; }
grep -q '^  "strategy"' "$DIR1/evidence/red/red-evidence.json" && { echo "FAIL: campo interno fora do schema vazou para o JSON"; exit 1; }
grep -q '"classification": "behavioral"' "$DIR1/evidence/red/red-evidence.json" || { echo "FAIL: classification não gravada"; exit 1; }
grep -q '"base_commit": "' "$DIR1/evidence/red/red-evidence.json" || { echo "FAIL: base_commit não gravado"; exit 1; }
# Furo 8 — base_strategy é campo PRÓPRIO do schema (não mais banido do JSON); ancestry não
# sintetiza revert, então revert_patch fica null.
grep -q '"base_strategy": "ancestry"' "$DIR1/evidence/red/red-evidence.json" || { echo "FAIL: base_strategy não gravado (esperava ancestry)"; exit 1; }
grep -q '"revert_patch": null' "$DIR1/evidence/red/red-evidence.json" || { echo "FAIL: revert_patch deveria ser null em ancestry"; exit 1; }
# Furo 1 — replay_head grava o HEAD do momento do replay, e replayed_at some do "sempre null".
grep -q '"replayed_at": "' "$DIR1/evidence/red/red-evidence.json" || { echo "FAIL: replayed_at não gravado"; exit 1; }
head_now="$(git -C "$T" rev-parse HEAD)"
grep -q "\"replay_head\": \"$head_now\"" "$DIR1/evidence/red/red-evidence.json" || { echo "FAIL: replay_head não corresponde ao HEAD atual"; exit 1; }
echo "OK [1]"

echo "[2] teste que já passava na base -> FAIL citando não reproduz"
mkdir -p "$T/src2" "$T/tests2"
cat > "$T/src2/sum2.mjs" <<'JS'
export function sum(a, b) { return a + b; }
JS
git -C "$T" add src2/sum2.mjs
git -C "$T" commit -qm "feat: sum2 (já correto)" >/dev/null
cat > "$T/tests2/sum2.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sum } from '../src2/sum2.mjs';
test('bug-2-regression', () => { assert.strictEqual(sum(2, 3), 5); });
JS
git -C "$T" add tests2/sum2.test.mjs
git -C "$T" commit -qm "test: regressão bug-2" >/dev/null
# "correção" declarada que não muda comportamento (comentário) — o bug nunca existiu na base
# derivada, então rodar o teste na base já passa.
cat > "$T/src2/sum2.mjs" <<'JS'
// comentário sem efeito
export function sum(a, b) { return a + b; }
JS
git -C "$T" add src2/sum2.mjs
git -C "$T" commit -qm "fix: bug-2 — no-op" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-2 --type bugfix --scale 1 >/dev/null
DIR2="$T/.forge/specs/active/bug-2"
FORGE_ROOT="$T" bash "$RE" record bug-2 --test-path tests2/sum2.test.mjs --test-id bug-2-regression --command "node --test tests2/sum2.test.mjs" --fix-files src2/sum2.mjs --failure-pattern AssertionError >/dev/null
set +e
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-2 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: replay [2] esperava falha ($out)"; exit 1; }
grep -qi "não reproduz" <<<"$out" || { echo "FAIL: mensagem não cita 'não reproduz' ($out)"; exit 1; }
[ "$(status_of "$DIR2/evidence/red/red-evidence.json")" = "pending" ] || { echo "FAIL: status deveria voltar a pending"; exit 1; }
echo "OK [2]"

echo "[3] erro de sintaxe na base -> FAIL citando build/compilação, não comportamento"
mkdir -p "$T/src3" "$T/tests3"
cat > "$T/src3/sum3.mjs" <<'JS'
export function sum(a, b) { return a - b
JS
git -C "$T" add src3/sum3.mjs
git -C "$T" commit -qm "feat: sum3 (com bug de sintaxe)" >/dev/null
cat > "$T/tests3/sum3.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sum } from '../src3/sum3.mjs';
test('bug-3-regression', () => { assert.strictEqual(sum(2, 3), 5); });
JS
git -C "$T" add tests3/sum3.test.mjs
git -C "$T" commit -qm "test: regressão bug-3" >/dev/null
cat > "$T/src3/sum3.mjs" <<'JS'
export function sum(a, b) { return a + b; }
JS
git -C "$T" add src3/sum3.mjs
git -C "$T" commit -qm "fix: bug-3 — corrige sintaxe e soma" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-3 --type bugfix --scale 1 >/dev/null
DIR3="$T/.forge/specs/active/bug-3"
FORGE_ROOT="$T" bash "$RE" record bug-3 --test-path tests3/sum3.test.mjs --test-id bug-3-regression --command "node --test tests3/sum3.test.mjs" --fix-files src3/sum3.mjs --failure-pattern AssertionError >/dev/null
set +e
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-3 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: replay [3] esperava falha ($out)"; exit 1; }
grep -qi "build\|compila" <<<"$out" || { echo "FAIL: mensagem não cita build/compilação ($out)"; exit 1; }
grep -qvi "comportamento não" <<<"$out" || true
grep -qi "não comportamento" <<<"$out" || { echo "FAIL: mensagem não afirma 'não comportamento' ($out)"; exit 1; }
echo "OK [3]"

echo "[4] teste e correção no mesmo commit -> revert-synthesis -> observed"
mkdir -p "$T/src4" "$T/tests4"
cat > "$T/src4/sum4.mjs" <<'JS'
export function sum(a, b) { return a - b; }
JS
git -C "$T" add src4/sum4.mjs
git -C "$T" commit -qm "feat: sum4 (com bug)" >/dev/null
# squash: teste E correção no mesmo commit
cat > "$T/src4/sum4.mjs" <<'JS'
export function sum(a, b) { return a + b; }
JS
cat > "$T/tests4/sum4.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sum } from '../src4/sum4.mjs';
test('bug-4-regression', () => { assert.strictEqual(sum(2, 3), 5); });
JS
git -C "$T" add src4/sum4.mjs tests4/sum4.test.mjs
git -C "$T" commit -qm "fix: bug-4 — teste e correção juntos (squash)" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-4 --type bugfix --scale 1 >/dev/null
DIR4="$T/.forge/specs/active/bug-4"
FORGE_ROOT="$T" bash "$RE" record bug-4 --test-path tests4/sum4.test.mjs --test-id bug-4-regression --command "node --test tests4/sum4.test.mjs" --fix-files src4/sum4.mjs --failure-pattern AssertionError >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-4 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: replay [4] esperava sucesso via revert-synthesis ($out)"; exit 1; }
grep -qi "revert-synthesis" <<<"$out" || { echo "FAIL: saída não confirma revert-synthesis ($out)"; exit 1; }
[ "$(status_of "$DIR4/evidence/red/red-evidence.json")" = "observed" ] || { echo "FAIL: status != observed em [4]"; exit 1; }
# Furo 8 — revert-synthesis grava base_strategy E o patch revertido (reprodução por um
# auditor; sem isso base_commit aponta pro HEAD já corrigido e a evidência parece se contradizer).
grep -q '"base_strategy": "revert-synthesis"' "$DIR4/evidence/red/red-evidence.json" || { echo "FAIL: base_strategy não gravado (esperava revert-synthesis)"; exit 1; }
grep -q '"revert_patch": "' "$DIR4/evidence/red/red-evidence.json" || { echo "FAIL: revert_patch deveria conter o patch revertido"; exit 1; }
grep -q 'sum4' "$DIR4/evidence/red/red-evidence.json" || { echo "FAIL: revert_patch não parece conter o diff de sum4.mjs"; exit 1; }
echo "OK [4]"

echo "[5] failure_pattern divergente -> FAIL"
FORGE_ROOT="$T" bash "$SN" bug-5 --type bugfix --scale 1 >/dev/null
DIR5="$T/.forge/specs/active/bug-5"
FORGE_ROOT="$T" bash "$RE" record bug-5 --test-path tests/sum.test.mjs --test-id bug-1-regression --command "node --test tests/sum.test.mjs" --fix-files src/sum.mjs --failure-pattern "TypeError: nunca-vai-aparecer" >/dev/null
set +e
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-5 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: replay [5] esperava falha ($out)"; exit 1; }
grep -qi "failure_pattern" <<<"$out" || { echo "FAIL: mensagem não cita failure_pattern ($out)"; exit 1; }
echo "OK [5]"

echo "[6] base não derivável -> not-possible, rebaixável, exige waiver"
FORGE_ROOT="$T" bash "$SN" bug-6 --type bugfix --scale 1 >/dev/null
DIR6="$T/.forge/specs/active/bug-6"
FORGE_ROOT="$T" bash "$RE" record bug-6 --test-path tests/does-not-exist.test.mjs --test-id bug-6-regression --command "true" --fix-files src/does-not-exist.mjs --failure-pattern "nunca-vai-rodar" >/dev/null
wt_before="$(git -C "$T" worktree list --porcelain | grep -c '^worktree ' || true)"
set +e
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-6 2>&1)"; rc=$?
set -e
wt_after="$(git -C "$T" worktree list --porcelain | grep -c '^worktree ' || true)"
[ "$rc" -ne 0 ] || { echo "FAIL: replay [6] esperava not-possible ($out)"; exit 1; }
grep -qi "NOT-POSSIBLE" <<<"$out" || { echo "FAIL: mensagem não sinaliza NOT-POSSIBLE ($out)"; exit 1; }
[ "$(status_of "$DIR6/evidence/red/red-evidence.json")" = "not-possible" ] || { echo "FAIL: status != not-possible"; exit 1; }
[ "$wt_before" = "$wt_after" ] || { echo "FAIL: worktree vazou (before=$wt_before after=$wt_after) — not-possible deveria ser barato"; exit 1; }
# rebaixável: check-red-first (Onda B) continua bloqueando (não resolvido) até waive
set +e
FORGE_ROOT="$T" bash "$T/.forge/scripts/check-red-first.sh" check bug-6 >/dev/null 2>&1; rc_check=$?
set -e
[ "$rc_check" -ne 0 ] || { echo "FAIL: check-red-first deveria bloquear bug-6 (not-possible não é resolvido)"; exit 1; }
out="$(FORGE_ROOT="$T" bash "$RE" waive bug-6 --reason external-unreproducible --note "dependência externa indisponível no CI" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: waive de bug-6 falhou ($out)"; exit 1; }
[ "$(status_of "$DIR6/evidence/red/red-evidence.json")" = "waived" ] || { echo "FAIL: status != waived após waive"; exit 1; }
echo "OK [6]"

echo "[7] pre-push bloqueia fix(...) sem evidência resolvida e NÃO roda replay"
# bug-2 ficou com status:pending após o passo [2] (FAIL correto) — cenário real de push bloqueado.
git -C "$T" add -A
git -C "$T" commit -qm "chore: specs ativos (fixture w107)" >/dev/null
parent_sha="$(git -C "$T" rev-parse HEAD)"
# README/CHANGELOG no mesmo commit: isola a asserção no gate red-first — sem isso, o gate
# docs-reviewed (que roda ANTES no pre-push) bloquearia primeiro por um motivo não relacionado.
echo "// touch" >> "$T/src2/sum2.mjs"
echo "readme" > "$T/README.md"
echo "changelog" > "$T/CHANGELOG.md"
git -C "$T" add src2/sum2.mjs README.md CHANGELOG.md
git -C "$T" commit -qm "fix(sum2): ajuste adicional" >/dev/null
sha_push="$(git -C "$T" rev-parse HEAD)"
wt_before7="$(git -C "$T" worktree list --porcelain | grep -c '^worktree ' || true)"
# remote_sha = parent_sha (não ZERO_SHA): range fica restrito a este único commit, sem depender
# de resolução de origin/HEAD (fixture não tem remote configurado).
FEED="refs/heads/main $sha_push refs/heads/main $parent_sha"
set +e
start_ts=$(date +%s)
out="$(cd "$T" && printf '%s\n' "$FEED" | bash .forge/hooks/git/pre-push origin "file://$T" 2>&1)"; rc=$?
end_ts=$(date +%s)
set -e
wt_after7="$(git -C "$T" worktree list --porcelain | grep -c '^worktree ' || true)"
[ "$rc" -ne 0 ] || { echo "FAIL: pre-push deveria bloquear ($out)"; exit 1; }
grep -qi "red-first" <<<"$out" || { echo "FAIL: pre-push não citou red-first ($out)"; exit 1; }
grep -qi "bug-2" <<<"$out" || { echo "FAIL: pre-push não citou o change pendente bug-2 ($out)"; exit 1; }
[ "$wt_before7" = "$wt_after7" ] || { echo "FAIL: pre-push criou worktree — replay não pode rodar no hook"; exit 1; }
elapsed=$((end_ts - start_ts))
[ "$elapsed" -le 15 ] || { echo "FAIL: pre-push demorou ${elapsed}s — check estático deveria ser rápido (sem rodar teste algum)"; exit 1; }
! grep -Eq '(bash|node)[^#]*(red-evidence\.sh[^#]*replay|red-replay\.mjs|red-evidence-ops\.mjs)' \
  "$WS/template/.forge/hooks/git/lib/check-red-first.sh" \
  || { echo "FAIL: hook de pre-push invoca o motor de replay — deveria ser só o check estático"; exit 1; }
echo "OK [7]"

echo "[8] pre-push NÃO bloqueia fix(...) que não intersecta fix_files do change pendente"
# bug-2 continua pending (fix_files: src2/sum2.mjs) — um fix(...) que não toca src2/sum2.mjs
# nem nenhum arquivo dentro dele não tem como estar relacionado a bug-2 (Nota de escopo do
# auditor): o hook não deve mais bloquear esse push.
mkdir -p "$T/unrelated"
echo "conteúdo" > "$T/unrelated/file.txt"
echo "readme2" > "$T/README.md"
echo "changelog2" > "$T/CHANGELOG.md"
git -C "$T" add unrelated/file.txt README.md CHANGELOG.md
git -C "$T" commit -qm "fix(unrelated): ajuste em arquivo sem relação com bug-2" >/dev/null
parent_sha8="$sha_push"
sha_push8="$(git -C "$T" rev-parse HEAD)"
FEED8="refs/heads/main $sha_push8 refs/heads/main $parent_sha8"
set +e
out="$(cd "$T" && printf '%s\n' "$FEED8" | bash .forge/hooks/git/pre-push origin "file://$T" 2>&1)"; rc=$?
set -e
grep -qi "red-first" <<<"$out" && { echo "FAIL: pre-push citou red-first para um push sem interseção com fix_files ($out)"; exit 1; }
[ "$rc" -eq 0 ] || { echo "FAIL: pre-push deveria passar (push sem relação com bug-2 pendente) ($out)"; exit 1; }
echo "OK [8]"

echo "[8b] Onda D, item 5 — bugfix ativo SEM evidência nenhuma NÃO é isento (bloqueia mesmo sem interseção)"
# O caso brownfield mais comum (item 1 da rule): um change type:bugfix ativo cujo
# evidence/red/red-evidence.json nunca foi escaffoldado (harness antigo, ou apagado à mão) — a
# versão anterior do filtro do hook (`[ -f "$ev" ] || return 1`) pulava esse change INTEIRO,
# porque não havia fix_files declarados para estabelecer interseção. Isso invertia a rule: quem
# declara (e não intersecta) é checado e pode passar; quem NÃO declara nada deveria ser o
# primeiro a bloquear (item 1), não o último. Fixture manual (como os "nogit" de w106): manifest
# sem evidence/red/ nenhum.
mkdir -p "$T/.forge/specs/active/bug-8b-sem-evidencia"
cat > "$T/.forge/specs/active/bug-8b-sem-evidencia/manifest.yaml" <<'YAML'
id: bug-8b-sem-evidencia
type: bugfix
scale: 1
status: implementing
YAML
git -C "$T" add .forge/specs/active/bug-8b-sem-evidencia/manifest.yaml
git -C "$T" commit -qm "chore: change bugfix ativo sem evidência (fixture item 5)" >/dev/null
parent_sha8b="$(git -C "$T" rev-parse HEAD)"
mkdir -p "$T/unrelated2"
echo "outro conteúdo, sem relação com bug-8b" > "$T/unrelated2/file.txt"
echo "readme8b" >> "$T/README.md"
echo "changelog8b" >> "$T/CHANGELOG.md"
git -C "$T" add unrelated2/file.txt README.md CHANGELOG.md
git -C "$T" commit -qm "fix(unrelated2): mais um ajuste sem relação nenhuma" >/dev/null
sha_push8b="$(git -C "$T" rev-parse HEAD)"
FEED8B="refs/heads/main $sha_push8b refs/heads/main $parent_sha8b"
set +e
out="$(cd "$T" && printf '%s\n' "$FEED8B" | bash .forge/hooks/git/pre-push origin "file://$T" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [8b]: pre-push deveria bloquear (bugfix ativo sem evidência nenhuma) ($out)"; exit 1; }
grep -qi "red-first" <<<"$out" || { echo "FAIL [8b]: pre-push não citou red-first ($out)"; exit 1; }
grep -q "bug-8b-sem-evidencia" <<<"$out" || { echo "FAIL [8b]: pre-push não citou o change sem evidência ($out)"; exit 1; }
echo "OK [8b]"

echo "[9] FORJA — status:'observed' hand-forjado (campos internamente consistentes, teste FICTÍCIO que nunca teve Red) — check-red-first sozinho ACEITA (limite aceito, Onda E), mas o GATE REAL (validate-spec, que chama 'ensure' incondicionalmente) reprova ao reexecutar o teste declarado de verdade"
# Onda E, item 1 (auditoria) — o cache local que corroborava 'observed' em check-red-first.sh
# check SOZINHO foi removido (decisão do orquestrador): um teste que exigia essa corroboração
# virou proteção do próprio furo (qualquer correção real do design faria o gate ficar vermelho).
# A garantia agora mora só nos GATES REAIS — validate-spec.mjs (transição p/ verified) e
# archive-spec.sh chamam `red-evidence.sh ensure` incondicionalmente ANTES de avaliar, reescrevendo
# o artefato com o resultado de uma execução de verdade. check-red-first.sh check sozinho (usado
# por pre-push/doctor) não paga esse custo — é um limite aceito, documentado na rule.
FORGE_ROOT="$T" bash "$SN" bug-9 --type bugfix --scale 1 >/dev/null
DIR9="$T/.forge/specs/active/bug-9"
EV9="$DIR9/evidence/red/red-evidence.json"
mkdir -p "$T/src9-forja" "$T/tests9-forja"
printf 'export function neverBuggy() { return 1; }\n' > "$T/src9-forja/fix.mjs"
printf "import { test } from 'node:test';\nimport assert from 'node:assert/strict';\ntest('bug-9-forja-regression', () => { assert.strictEqual(1, 1); });\n" > "$T/tests9-forja/t.test.mjs"
git -C "$T" add src9-forja/fix.mjs tests9-forja/t.test.mjs
git -C "$T" commit -qm "fix: bug-9-forja (nunca houve Red — teste trivial sempre verde)" >/dev/null
FORJA9_EXCERPT="AssertionError: forjado à mão, nunca rodou de verdade"
FORJA9_HASH="$(node -e "process.stdout.write(require('crypto').createHash('sha256').update(process.argv[1]).digest('hex'))" "$FORJA9_EXCERPT")"
node -e '
  const fs = require("fs");
  const p = process.argv[1];
  const d = JSON.parse(fs.readFileSync(p, "utf8"));
  d.status = "observed";
  d.test_path = "tests9-forja/t.test.mjs";
  d.test_id = "bug-9-forja-regression";
  d.command = "node --test tests9-forja/t.test.mjs";
  d.fix_files = ["src9-forja/fix.mjs"];
  d.base_commit = "0123456";
  d.classification = "behavioral";
  d.failure_pattern = "AssertionError";
  d.excerpt = process.argv[2];
  d.excerpt_sha256 = process.argv[3];
  d.base_result = "failed";
  fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
' "$EV9" "$FORJA9_EXCERPT" "$FORJA9_HASH"

out="$(FORGE_ROOT="$T" bash "$T/.forge/scripts/check-red-first.sh" check bug-9 2>&1)"; rc=$?
# INFORMATIVO, nunca asserção — ver o comentário equivalente no w106: a limitação do check estático
# é documentada, não exigida. Quem fortalecer o check não pode ficar com o gate vermelho por isso.
# A asserção real vem em [9b], onde validate-spec executa o replay e reprova a forja.
echo "INFO [9a] — check-red-first sozinho (rc=$rc): $out"

rm -f "$DIR9/spec-delta.yaml"
printf 'verification:\n  commit: "abc1234"\n  checks: []\n' > "$DIR9/verification.yaml"
perl -pi -e 's/^status: .*/status: verified/' "$DIR9/manifest.yaml"
set +e
out="$(FORGE_ROOT="$T" bash "$T/.forge/scripts/validate-spec.sh" --path "$DIR9" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [9b]: validate-spec (gate real, chama ensure incondicionalmente) aprovou change com evidência forjada ($out)"; exit 1; }
echo "OK [9b] — validate-spec (gate real) reprova ao reexecutar o teste declarado: $out"
[ "$(status_of "$EV9")" != "observed" ] || { echo "FAIL [9b]: ensure deveria ter sobrescrito a forja (status ainda observed após reexecução) ($out)"; exit 1; }
perl -pi -e 's/^status: .*/status: implementing/' "$DIR9/manifest.yaml"
echo "OK [9]"

echo "[10] Onda E, item 2 — 'ensure' NUNCA pula: duas chamadas seguidas sobre a MESMA evidência observed reexecutam o motor de replay as DUAS vezes (sem cache) — mede o custo real de sempre-executar"
out="$(FORGE_ROOT="$T" bash "$RE" record bug-9 --test-path tests/sum.test.mjs --test-id bug-1-regression --command "node --test tests/sum.test.mjs" --fix-files src/sum.mjs --failure-pattern AssertionError 2>&1)"
grep -q "OK record" <<<"$out" || { echo "FAIL: restauração da declaração original de bug-9 falhou ($out)"; exit 1; }
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-9 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: replay real de bug-9 (declaração restaurada) deveria observar ($out)"; exit 1; }
[ "$(status_of "$EV9")" = "observed" ] || { echo "FAIL: bug-9 deveria estar observed após replay real"; exit 1; }
replayed_at_1="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).replayed_at)" "$EV9")"

SECONDS=0
out="$(FORGE_ROOT="$T" bash "$RE" ensure bug-9 2>&1)"; rc=$?
ensure_elapsed="$SECONDS"
[ "$rc" -eq 0 ] || { echo "FAIL: ensure de bug-9 falhou ($out)"; exit 1; }
replayed_at_2="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).replayed_at)" "$EV9")"
[ "$replayed_at_2" != "$replayed_at_1" ] || { echo "FAIL: replayed_at não mudou entre dois 'ensure' seguidos — parece ter pulado a execução (cache reintroduzido?)"; exit 1; }
echo "  custo medido de UM 'ensure' (sem cache, sempre executa): ${ensure_elapsed}s (replayed_at: $replayed_at_1 -> $replayed_at_2)"
echo "OK [10] — ensure reexecutou de verdade (sem atalho de cache)"

echo "[11] TETO DE TEMPO — filho em background não segura o replay além do timeout"
mkdir -p "$T/src11" "$T/tests11"
cat > "$T/src11/x.mjs" <<'JS'
export function x() { return 1; }
JS
git -C "$T" add src11/x.mjs
git -C "$T" commit -qm "feat: x11 (com bug)" >/dev/null
cat > "$T/tests11/x.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { x } from '../src11/x.mjs';
test('bug-11-regression', () => { assert.strictEqual(x(), 2); });
JS
git -C "$T" add tests11/x.test.mjs
git -C "$T" commit -qm "test: regressão bug-11" >/dev/null
cat > "$T/src11/x.mjs" <<'JS'
export function x() { return 2; }
JS
git -C "$T" add src11/x.mjs
git -C "$T" commit -qm "fix: bug-11 — x retorna valor certo" >/dev/null
FORGE_ROOT="$T" bash "$SN" bug-11 --type bugfix --scale 1 >/dev/null
DIR11="$T/.forge/specs/active/bug-11"
# comando com filho em BACKGROUND que sobrevive ao processo direto — o bug medido pré-correção:
# 91s com timeout de 3s porque só o processo direto era morto, o `sleep` em background herdava
# stdout e mantinha o motor bloqueado.
FORGE_ROOT="$T" bash "$RE" record bug-11 --test-path tests11/x.test.mjs --test-id bug-11-regression \
  --command "sleep 45 & node --test tests11/x.test.mjs" --fix-files src11/x.mjs \
  --failure-pattern AssertionError >/dev/null
t0=$(date +%s)
set +e
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-11 --timeout 3 2>&1)"; rc=$?
set -e
t1=$(date +%s)
elapsed11=$((t1 - t0))
echo "  replay com filho em background (sleep 45, timeout 3s) voltou em ${elapsed11}s"
[ "$elapsed11" -le 20 ] || { echo "FAIL: replay demorou ${elapsed11}s — timeout não matou o grupo de processos (esperado <=20s, não ~45-90s)"; exit 1; }
echo "OK [11]"

echo "[12] setup_command ausente + deps não versionadas -> not-possible (ambiente), não FAIL inegociável"
mkdir -p "$T/src12" "$T/tests12"
cat > "$T/src12/y.mjs" <<'JS'
import { helper } from './missing-dep.mjs';
export function y() { return helper() - 1; }
JS
git -C "$T" add src12/y.mjs
git -C "$T" commit -qm "feat: y12 (depende de módulo nunca commitado)" >/dev/null
cat > "$T/tests12/y.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { y } from '../src12/y.mjs';
test('bug-12-regression', () => { assert.strictEqual(y(), 2); });
JS
git -C "$T" add tests12/y.test.mjs
git -C "$T" commit -qm "test: regressão bug-12" >/dev/null
cat > "$T/src12/y.mjs" <<'JS'
import { helper } from './missing-dep.mjs';
export function y() { return helper() + 1; }
JS
git -C "$T" add src12/y.mjs
git -C "$T" commit -qm "fix: bug-12 — ainda depende do módulo nunca commitado" >/dev/null
FORGE_ROOT="$T" bash "$SN" bug-12 --type bugfix --scale 1 >/dev/null
DIR12="$T/.forge/specs/active/bug-12"
FORGE_ROOT="$T" bash "$RE" record bug-12 --test-path tests12/y.test.mjs --test-id bug-12-regression --command "node --test tests12/y.test.mjs" --fix-files src12/y.mjs --failure-pattern AssertionError >/dev/null
wt_before12="$(git -C "$T" worktree list --porcelain | grep -c '^worktree ' || true)"
set +e
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-12 2>&1)"; rc=$?
set -e
wt_after12="$(git -C "$T" worktree list --porcelain | grep -c '^worktree ' || true)"
[ "$rc" -ne 0 ] || { echo "FAIL: replay [12] esperava not-possible (ambiente incompleto) ($out)"; exit 1; }
grep -qi "NOT-POSSIBLE" <<<"$out" || { echo "FAIL: mensagem não sinaliza NOT-POSSIBLE ($out)"; exit 1; }
grep -qi "ambiente" <<<"$out" || { echo "FAIL: mensagem não atribui a falha ao ambiente do worktree ($out)"; exit 1; }
[ "$(status_of "$DIR12/evidence/red/red-evidence.json")" = "not-possible" ] || { echo "FAIL: status != not-possible em bug-12"; exit 1; }
[ "$wt_before12" = "$wt_after12" ] || { echo "FAIL: worktree vazou em [12]"; exit 1; }
echo "OK [12]"

echo "[13] setup_command declarado corrige o ambiente -> replay prossegue normalmente"
FORGE_ROOT="$T" bash "$RE" record bug-12 --test-path tests12/y.test.mjs --test-id bug-12-regression --command "node --test tests12/y.test.mjs" --fix-files src12/y.mjs --failure-pattern AssertionError --setup-command "printf 'export function helper(){ return 1; }\n' > src12/missing-dep.mjs" >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-12 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: replay [13] esperava sucesso com setup_command declarado ($out)"; exit 1; }
grep -qi "observado" <<<"$out" || { echo "FAIL: setup_command não destravou o replay ($out)"; exit 1; }
echo "OK [13]"

echo "[14] excerpt_sha256 adulterado (evidência editada à mão) é REPROVADO"
FORGE_ROOT="$T" bash "$SN" bug-14 --type bugfix --scale 1 >/dev/null
DIR14="$T/.forge/specs/active/bug-14"
FORGE_ROOT="$T" bash "$RE" record bug-14 --test-path tests/sum.test.mjs --test-id bug-1-regression --command "node --test tests/sum.test.mjs" --fix-files src/sum.mjs --failure-pattern AssertionError >/dev/null
FORGE_ROOT="$T" bash "$RE" replay bug-14 >/dev/null
node -e "
  const fs = require('fs');
  const p = process.argv[1];
  const d = JSON.parse(fs.readFileSync(p, 'utf8'));
  d.excerpt = d.excerpt + ' (editado à mão depois do replay)';
  // excerpt_sha256 NÃO recalculado — é exatamente essa a adulteração.
  fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
" "$DIR14/evidence/red/red-evidence.json"
set +e
out="$(FORGE_ROOT="$T" bash "$T/.forge/scripts/check-red-first.sh" check bug-14 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: check-red-first deveria reprovar excerpt_sha256 adulterado ($out)"; exit 1; }
grep -qi "excerpt_sha256" <<<"$out" || { echo "FAIL: mensagem não cita excerpt_sha256 ($out)"; exit 1; }
echo "OK [14]"

echo "[15] record sem --failure-pattern é recusado"
FORGE_ROOT="$T" bash "$SN" bug-15 --type bugfix --scale 1 >/dev/null
set +e
out="$(FORGE_ROOT="$T" bash "$RE" record bug-15 --test-path tests/sum.test.mjs --command "node --test tests/sum.test.mjs" --fix-files src/sum.mjs 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: record sem --failure-pattern deveria ser recusado ($out)"; exit 1; }
grep -qi "failure-pattern" <<<"$out" || { echo "FAIL: mensagem não cita --failure-pattern ($out)"; exit 1; }
echo "OK [15]"

echo "[16] worktree remove NUNCA faz prune global (worktree de terceiro sobrevive)"
third_dir="$(mktemp -d "${TMPDIR:-/tmp}/forge-w107-third-XXXXXX")"
rmdir "$third_dir"
git -C "$T" worktree add --detach --quiet "$third_dir" HEAD >/dev/null 2>&1
# remove o diretório do disco SEM `git worktree remove` — fica uma entrada "prunable" (o padrão
# de /forge:coding-loop quando um worktree é limpo manualmente sem passar pelo git).
rm -rf "$third_dir"
third_base="$(basename "$third_dir")"
before_list="$(git -C "$T" worktree list --porcelain)"
FORGE_ROOT="$T" bash "$SN" bug-16 --type bugfix --scale 1 >/dev/null
DIR16="$T/.forge/specs/active/bug-16"
FORGE_ROOT="$T" bash "$RE" record bug-16 --test-path tests/sum.test.mjs --test-id bug-1-regression --command "node --test tests/sum.test.mjs" --fix-files src/sum.mjs --failure-pattern AssertionError >/dev/null
FORGE_ROOT="$T" bash "$RE" replay bug-16 >/dev/null
after_list="$(git -C "$T" worktree list --porcelain)"
# git resolve o path para o real (symlinks de TMPDIR resolvidos, ex. /tmp -> /private/tmp no
# macOS) — compara pelo basename, não pela string exata do path criado.
grep -qF "$third_base" <<<"$before_list" || { echo "FAIL: fixture do teste [16] não registrou o worktree de terceiro"; exit 1; }
grep -qF "$third_base" <<<"$after_list" || { echo "FAIL: replay removeu (via prune global) a entrada de um worktree de terceiro — Furo 7 reaberto"; exit 1; }
git -C "$T" worktree prune >/dev/null 2>&1 || true
echo "OK [16]"

echo "[17] arquivo de teste PREEXISTENTE (caso de regressão acrescentado depois) -> base correta, não a era da criação do arquivo"
mkdir -p "$T/src17" "$T/tests17"
cat > "$T/src17/calc.mjs" <<'JS'
export const VERSION = 'v1';
export function calc(a, b) { return a - b; }
JS
git -C "$T" add src17/calc.mjs
git -C "$T" commit -qm "feat: calc17 (com bug)" >/dev/null
# arquivo de teste PREEXISTENTE — só um caso de sanidade, sem NENHUMA relação com o bug17 ainda
# (o fluxo comum, Furo 2: "acrescentar o caso de regressão a um arquivo antigo"). Esse caso de
# sanidade FALHA neste ponto do histórico (WIP realista) — é exatamente o tipo de "falha
# histórica que casa com o pattern" que a heurística antiga aceitava como Red por engano.
cat > "$T/tests17/calc.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { VERSION } from '../src17/calc.mjs';
test('calc17 sanity - version check', () => { assert.strictEqual(VERSION, 'v2'); });
JS
git -C "$T" add tests17/calc.test.mjs
git -C "$T" commit -qm "test: calc17 sanity check (arquivo de teste criado aqui)" >/dev/null
caseB_sha="$(git -C "$T" rev-parse HEAD)"
# commit NÃO relacionado ao bug17 que também toca fix_files (bump de versão) — é o candidato
# a "fix" que a heurística ANTIGA (ancorada na criação do ARQUIVO) escolheria por engano.
cat > "$T/src17/calc.mjs" <<'JS'
export const VERSION = 'v2';
export function calc(a, b) { return a - b; }
JS
git -C "$T" add src17/calc.mjs
git -C "$T" commit -qm "chore: bump VERSION calc17 (sem relação com o bug)" >/dev/null
# SÓ AGORA o caso de regressão do bug17 é acrescentado ao arquivo PREEXISTENTE (test_id
# distinto, para o replay conseguir identificar QUAL caso precisa falhar).
cat > "$T/tests17/calc.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { VERSION, calc } from '../src17/calc.mjs';
test('calc17 sanity - version check', () => { assert.strictEqual(VERSION, 'v2'); });
test('calc17-bug17-regression', () => { assert.strictEqual(calc(2, 3), 5); });
JS
git -C "$T" add tests17/calc.test.mjs
git -C "$T" commit -qm "test: regressão bug-17 (acrescentada ao arquivo preexistente)" >/dev/null
caseD_sha="$(git -C "$T" rev-parse HEAD)"
cat > "$T/src17/calc.mjs" <<'JS'
export const VERSION = 'v2';
export function calc(a, b) { return a + b; }
JS
git -C "$T" add src17/calc.mjs
git -C "$T" commit -qm "fix: bug-17 — calc soma certo" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-17 --type bugfix --scale 1 >/dev/null
DIR17="$T/.forge/specs/active/bug-17"
FORGE_ROOT="$T" bash "$RE" record bug-17 --test-path tests17/calc.test.mjs --test-id calc17-bug17-regression --command "node --test tests17/calc.test.mjs" --fix-files src17/calc.mjs --failure-pattern AssertionError >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-17 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: replay [17] esperava sucesso (base derivada corretamente do caso, não do arquivo) ($out)"; exit 1; }
[ "$(status_of "$DIR17/evidence/red/red-evidence.json")" = "observed" ] || { echo "FAIL: status != observed em [17]"; exit 1; }
base_now="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).base_commit)" "$DIR17/evidence/red/red-evidence.json")"
[ "$base_now" = "$caseD_sha" ] || { echo "FAIL: base_commit ($base_now) deveria ser o commit que introduziu o CASO ($caseD_sha), não outra era"; exit 1; }
[ "$base_now" != "$caseB_sha" ] || { echo "FAIL: base_commit caiu na era de criação do ARQUIVO ($caseB_sha) — heurística antiga (Furo 2) reapareceu"; exit 1; }
echo "OK [17] — base_commit correto: $base_now (commit que introduziu o caso, não o commit que criou o arquivo)"

echo "[18] Onda D, item 8 — excerpt_sha256 ESTÁVEL: dois replays seguidos do MESMO change dão o MESMO hash"
# `node --test` (reporter TAP) emite "# duration_ms <float>" por caso — um número que varia a
# cada execução. Sem normalizar essa forma (Furo 11), o excerpt trazia esse float cru e
# excerpt_sha256 mudava a cada replay do MESMO change, mesmo sem nada relevante ter mudado —
# reabria o próprio furo que o cache do item 1 corrige de outro ângulo (chave instável).
mkdir -p "$T/src18" "$T/tests18"
cat > "$T/src18/w.mjs" <<'JS'
export function w() { return 1; }
JS
git -C "$T" add src18/w.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "feat: w18 (com bug)" >/dev/null
cat > "$T/tests18/w.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { w } from '../src18/w.mjs';
test('bug-18-regression', () => { assert.strictEqual(w(), 2); });
JS
git -C "$T" add tests18/w.test.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "test: regressão bug-18" >/dev/null
cat > "$T/src18/w.mjs" <<'JS'
export function w() { return 2; }
JS
git -C "$T" add src18/w.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fix: bug-18 — w retorna valor certo" >/dev/null
FORGE_ROOT="$T" bash "$SN" bug-18 --type bugfix --scale 1 >/dev/null
DIR18="$T/.forge/specs/active/bug-18"
FORGE_ROOT="$T" bash "$RE" record bug-18 --test-path tests18/w.test.mjs --test-id bug-18-regression --command "node --test tests18/w.test.mjs" --fix-files src18/w.mjs --failure-pattern AssertionError >/dev/null
FORGE_ROOT="$T" bash "$RE" replay bug-18 >/dev/null
hash1="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).excerpt_sha256)" "$DIR18/evidence/red/red-evidence.json")"
excerpt1="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).excerpt)" "$DIR18/evidence/red/red-evidence.json")"
[ -n "$hash1" ] && [ "$hash1" != "null" ] || { echo "FAIL [18]: excerpt_sha256 ausente após o primeiro replay"; exit 1; }
FORGE_ROOT="$T" bash "$RE" replay bug-18 >/dev/null
hash2="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).excerpt_sha256)" "$DIR18/evidence/red/red-evidence.json")"
[ "$hash1" = "$hash2" ] || { echo "FAIL [18]: excerpt_sha256 mudou entre dois replays do mesmo change ($hash1 -> $hash2) — excerpt1: $excerpt1"; exit 1; }
echo "OK [18] — excerpt_sha256 idêntico em duas execuções seguidas ($hash1)"

echo "[19] Onda D, item 7 — SIGTERM externo mata o GRUPO de processos (worktree + filho em background), não deixa órfão"
# O handler de sinal (installSignalHandlers, lib/red-replay.mjs) já limpava worktrees; não matava
# o processo/grupo do TESTE em si. `sleep 400 & node --test ...` sobrevivia a um SIGTERM externo
# no processo do replay (o `sleep` herda o grupo mas não o handler do pai). Timeout generoso
# (--timeout 300) para garantir que é O NOSSO SIGTERM que interrompe, não o alarm interno.
mkdir -p "$T/src19" "$T/tests19"
cat > "$T/src19/z.mjs" <<'JS'
export function z() { return 1; }
JS
git -C "$T" add src19/z.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "feat: z19 (com bug)" >/dev/null
cat > "$T/tests19/z.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { z } from '../src19/z.mjs';
test('bug-19-regression', () => { assert.strictEqual(z(), 2); });
JS
git -C "$T" add tests19/z.test.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "test: regressão bug-19" >/dev/null
cat > "$T/src19/z.mjs" <<'JS'
export function z() { return 2; }
JS
git -C "$T" add src19/z.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fix: bug-19 — z retorna valor certo" >/dev/null
FORGE_ROOT="$T" bash "$SN" bug-19 --type bugfix --scale 1 >/dev/null
DIR19="$T/.forge/specs/active/bug-19"
# Defeito de gate corrigido (auditoria) — dois problemas no marcador do processo de fundo:
#   (a) `mktemp "$TMPDIR/forge-w107-sig19-XXXXXX.log"` tinha um SUFIXO depois dos X's; no BSD
#       mktemp (macOS) os X's só são substituídos quando são os ÚLTIMOS caracteres do template —
#       com sufixo, o nome sai LITERAL (sem aleatoriedade nenhuma) e, como o cleanup só rodava no
#       caminho feliz (sem trap), qualquer falha nos passos [13]-[18] deixava o arquivo
#       envenenando a próxima execução. Corrigido: sig_log vive DENTRO de $T (já um diretório
#       próprio por execução via `mktemp -d`, com trap de limpeza no topo do arquivo) — não
#       precisa de aleatoriedade própria nem de um trap dedicado.
#   (b) `pgrep -f 'sleep 397'` é global à MÁQUINA — casaria com qualquer processo alheio (outro
#       usuário, outra suíte rodando em paralelo) que por acaso tenha essa string na linha de
#       comando. sleep_marker abaixo (via `exec -a`, que reescreve argv[0]) torna o processo de
#       fundo IDENTIFICÁVEL por um nome único desta execução — pgrep/pkill abaixo escaneiam só
#       por ele, nunca por 'sleep 397' cru.
sig_log="$T/sig19.log"
sleep_marker="w107-sig19-marker-$$"
FORGE_ROOT="$T" bash "$RE" record bug-19 --test-path tests19/z.test.mjs --test-id bug-19-regression \
  --command "bash -c 'exec -a $sleep_marker sleep 397' & node --test tests19/z.test.mjs" --fix-files src19/z.mjs \
  --failure-pattern AssertionError >/dev/null

wt_before19="$(git -C "$T" worktree list --porcelain | grep -c '^worktree ' || true)"
FORGE_ROOT="$T" node "$T/.forge/scripts/lib/red-evidence-ops.mjs" replay "$DIR19" --timeout 300 >"$sig_log" 2>&1 &
replay_pid=$!

# espera o worktree aparecer (o comando lento já está rodando dentro dele) — poll curto, teto
# generoso; nunca um sleep longo solto no meio do gate.
wt_seen=0
for _ in $(seq 1 40); do
  wt_now="$(git -C "$T" worktree list --porcelain | grep -c '^worktree ' || true)"
  if [ "$wt_now" -gt "$wt_before19" ]; then wt_seen=1; break; fi
  sleep 0.25
done
[ "$wt_seen" -eq 1 ] || { echo "FAIL [19]: worktree nunca apareceu — replay não chegou a rodar o comando lento a tempo do SIGTERM"; kill -9 "$replay_pid" 2>/dev/null || true; exit 1; }
# margem extra para o `sleep 397 &` (background, dentro do worktree) certamente já ter iniciado
sleep 0.5
kill -TERM "$replay_pid" 2>/dev/null || true

# espera o processo do replay encerrar (o handler de sinal deve rodar e sair) — teto generoso
exited=0
for _ in $(seq 1 40); do
  if ! kill -0 "$replay_pid" 2>/dev/null; then exited=1; break; fi
  sleep 0.25
done
[ "$exited" -eq 1 ] || { echo "FAIL [19]: processo do replay não encerrou após SIGTERM (log: $sig_log)"; kill -9 "$replay_pid" 2>/dev/null || true; exit 1; }

# nenhum worktree deveria ter sobrado
wt_after19="$(git -C "$T" worktree list --porcelain | grep -c '^worktree ' || true)"
[ "$wt_after19" -eq "$wt_before19" ] || { echo "FAIL [19]: worktree vazou após SIGTERM (before=$wt_before19 after=$wt_after19, log: $sig_log)"; exit 1; }
# nenhum processo com o marcador desta execução deveria sobreviver como órfão — escaneia só por
# $sleep_marker (único por PID de teste), nunca por 'sleep 397' cru (global à máquina).
sleep 0.5
if pgrep -f "$sleep_marker" >/dev/null 2>&1; then
  pkill -9 -f "$sleep_marker" 2>/dev/null || true
  echo "FAIL [19]: processo marcado '$sleep_marker' sobreviveu ao SIGTERM do replay — órfão de grupo não morto (log: $sig_log)"
  exit 1
fi
echo "OK [19] — SIGTERM matou o grupo (worktree removido, sleep em background não sobreviveu)"

echo "[20] Onda E, item 3b — test_id declarado precisa casar com a linha de FALHA, não com a saída inteira"
# Furo corrigido (auditoria) — outputMentionsCase (lib/red-replay.mjs) antes casava testId em
# QUALQUER LUGAR da saída. O reporter do `node --test` imprime também os casos que PASSARAM
# (com ✔) — então um test_id que só corresponde a um caso que PASSOU aparecia na saída mesmo
# sem ser quem falhou, e o replay aprovava como se fosse o defeito declarado.
mkdir -p "$T/src20" "$T/tests20"
cat > "$T/src20/x20.mjs" <<'JS'
export function x20(a, b) { return a - b; }
JS
git -C "$T" add src20/x20.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "feat: x20 (com bug)" >/dev/null
cat > "$T/tests20/x20.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { x20 } from '../src20/x20.mjs';
test('case-marker-x', () => { assert.ok(true); });
test('bug-20-regression', () => { assert.strictEqual(x20(2, 3), 5); });
JS
git -C "$T" add tests20/x20.test.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "test: regressão bug-20 + caso de marcador que sempre passa" >/dev/null
cat > "$T/src20/x20.mjs" <<'JS'
export function x20(a, b) { return a + b; }
JS
git -C "$T" add src20/x20.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fix: bug-20 — x20 soma certo" >/dev/null
FORGE_ROOT="$T" bash "$SN" bug-20 --type bugfix --scale 1 >/dev/null
DIR20="$T/.forge/specs/active/bug-20"
# test_id DECLARADO é o caso ERRADO (case-marker-x, que SEMPRE passa) — quem de fato falha na
# base é bug-20-regression.
FORGE_ROOT="$T" bash "$RE" record bug-20 --test-path tests20/x20.test.mjs --test-id case-marker-x --command "node --test tests20/x20.test.mjs" --fix-files src20/x20.mjs --failure-pattern AssertionError >/dev/null
set +e
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-20 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [20a]: replay deveria FALHAR — test_id declarado (case-marker-x) não é quem falhou de fato ($out)"; exit 1; }
grep -qi "não menciona o caso declarado\|test-id" <<<"$out" || { echo "FAIL [20a]: mensagem não cita o descasamento de test_id ($out)"; exit 1; }
[ "$(status_of "$DIR20/evidence/red/red-evidence.json")" = "pending" ] || { echo "FAIL [20a]: status deveria voltar a pending"; exit 1; }
echo "OK [20a] — test_id declarado errado (caso que PASSOU) é rejeitado, não aprovado por substring solta na saída inteira"

# controle — o test_id CORRETO (o caso que de fato falha) é aceito normalmente.
FORGE_ROOT="$T" bash "$RE" record bug-20 --test-path tests20/x20.test.mjs --test-id bug-20-regression --command "node --test tests20/x20.test.mjs" --fix-files src20/x20.mjs --failure-pattern AssertionError >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-20 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [20b]: replay com test_id correto deveria observar ($out)"; exit 1; }
[ "$(status_of "$DIR20/evidence/red/red-evidence.json")" = "observed" ] || { echo "FAIL [20b]: status != observed com test_id correto"; exit 1; }
echo "OK [20b] — test_id declarado correto (o caso que de fato falha) é aceito"
echo "OK [20]"

echo "PASS w107-red-replay-gate"
