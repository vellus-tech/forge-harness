#!/usr/bin/env bash
# Gate W106 — Red-first estático (Onda B, rule testing/regression-red-first.md), SEM rodar
# teste algum (o replay real é a Onda C):
#   [1]  spec-new --type bugfix escaffolda evidence/red/red-evidence.json com status pending
#   [2]  pending bloqueia a transição a verified no validate-spec (item 1, bloqueante)
#   [3]  evidência observed passa
#   [4]  waiver non-behavioral é RECUSADO quando o DIFF REAL toca arquivo de código no grafo
#   [5]  waiver non-behavioral (fallback SEM git) cobre as três formas de affected_paths —
#        bloco, flow inline e vazio/ausente — casando por PREFIXO de diretório
#   [6]  waiver no-test-infra cria deferral E entrada no ledger
#   [7]  waive não é idempotente: recusa reabrir um waiver existente e recusa rebaixar uma
#        evidência observed sem --force; com --force grava waived_at sem tocar recorded_at
#   [8]  doctor sinaliza evidência pendente sem alterar o exit code (advisory, não-bloqueante)
#        — baseline saneado para rc_base=0 (placeholders preenchidos + adapters sincronizados)
#   [9]  change type:feature é no-op — nenhum finding
#   [10] itens BLOQUEANTES 2/3/4 + completude de replay, via `check` real (não via
#        validate-spec): cada um assertado isoladamente com rc=1 e a string do item
#   [11] itens REBAIXÁVEIS 5/6/7/8, via `check` real: rc=0 + "WARN", cada um isolado —
#        inclui a matriz de mock (módulo com extensão, spyOn sem a palavra "mock")
#   [12] red-classify distingue build-error de behavioral nas linguagens principais, cobre
#        pelo menos um caso comportamental de cada família (JS/.NET/Java/Go/Python/Rust) e
#        não regride nos falsos positivos conhecidos (asserção sobre exceção classificada
#        como build por acidente)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w106.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
# Furo 5 — sanear o baseline: uma cópia crua do template tem placeholders <PROJECT_*> não
# preenchidos e nenhum adapter sincronizado, então o doctor already sai rc=1 por motivos
# ALHEIOS ao red-first (mesmo padrão de tests/w12-sync-gate.sh). Sem isso, o passo [8] compararia
# "1 contra 1" e passaria mesmo que o bloco red-first do doctor virasse bloqueante por engano.
perl -pi -e 's/<PROJECT_SLUG>/fixture-app/g; s/<PROJECT_NAME>/Fixture App/g; s/<PROJECT_DESCRIPTION>/Fixture for the W106 gate/g' \
  "$T/.forge/FORGE.md" "$T/.forge/constitution.md" "$T/.forge/context.md"
FORGE_ROOT="$T" bash "$T/.forge/scripts/sync-adapters.sh" --adapter claude >/dev/null

SN="$T/.forge/scripts/spec-new.sh"
VS="$T/.forge/scripts/validate-spec.sh"
CR="$T/.forge/scripts/check-red-first.sh"
DR="$T/.forge/scripts/doctor.sh"
RE="$T/.forge/scripts/red-evidence.sh"
git -C "$T" init -q
git -C "$T" config user.email t@t; git -C "$T" config user.name t; git -C "$T" config commit.gpgsign false
git -C "$T" add -A && git -C "$T" commit -qm init >/dev/null

echo "[1] spec-new --type bugfix cria red-evidence.json pending"
FORGE_ROOT="$T" bash "$SN" bug-a --type bugfix --scale 1 >/dev/null
EV_A="$T/.forge/specs/active/bug-a/evidence/red/red-evidence.json"
[ -f "$EV_A" ] || { echo "FAIL: evidence/red/red-evidence.json não criado"; exit 1; }
grep -q '"status": "pending"' "$EV_A" || { echo "FAIL: status inicial != pending"; exit 1; }
grep -q '"change_id": "bug-a"' "$EV_A" || { echo "FAIL: change_id não interpolado no scaffold"; exit 1; }
echo "OK [1]"

echo "[2] pending bloqueia a transição a verified no validate-spec"
DIR_A="$T/.forge/specs/active/bug-a"
# spec-delta.yaml nasce em placeholder (regra §10.4 pré-existente, ortogonal a red-first) —
# removido aqui para isolar o red-first como único motivo de bloqueio sob teste.
rm -f "$DIR_A/spec-delta.yaml"
printf 'verification:\n  commit: "abc1234"\n  checks: []\n' > "$DIR_A/verification.yaml"
perl -pi -e 's/^status: .*/status: verified/' "$DIR_A/manifest.yaml"
set +e
out="$(FORGE_ROOT="$T" bash "$VS" --path "$DIR_A" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: validate-spec passou com evidência pending (esperava FAIL)"; exit 1; }
echo "$out" | grep -qi "red-evidence" || { echo "FAIL: mensagem não cita red-evidence.json ($out)"; exit 1; }
echo "OK [2]"

echo "[3] evidência observed (via REPLAY REAL — Onda D: só execução prova, não o campo) passa"
# Onda D — o único jeito de chegar a status:observed que o check aceita é rodar o motor de
# verdade (record + replay), nunca escrever os campos à mão (isso é EXATAMENTE o que o passo
# [3-FORJA] abaixo demonstra que agora reprova). Fixture mínima, real, sem dependências externas:
# node:test — mesmo padrão de tests/w107-red-replay-gate.sh.
mkdir -p "$T/src" "$T/tests"
cat > "$T/src/bug-a-calc.mjs" <<'JS'
export function calc(a, b) { return a - b; }
JS
git -C "$T" add src/bug-a-calc.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "feat: bug-a-calc (com bug)" >/dev/null
cat > "$T/tests/bug-a.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calc } from '../src/bug-a-calc.mjs';
test('bug-a-regression', () => { assert.strictEqual(calc(2, 3), 5); });
JS
git -C "$T" add tests/bug-a.test.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "test: regressão bug-a" >/dev/null
cat > "$T/src/bug-a-calc.mjs" <<'JS'
export function calc(a, b) { return a + b; }
JS
git -C "$T" add src/bug-a-calc.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fix: bug-a — calc soma certo" >/dev/null

out="$(FORGE_ROOT="$T" bash "$RE" record bug-a --test-path tests/bug-a.test.mjs --test-id bug-a-regression --command "node --test tests/bug-a.test.mjs" --fix-files src/bug-a-calc.mjs --failure-pattern AssertionError 2>&1)"
echo "$out" | grep -q "OK record" || { echo "FAIL: record de bug-a não confirmou ($out)"; exit 1; }
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-a 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: replay real de bug-a esperava sucesso ($out)"; exit 1; }
grep -q '"status": "observed"' "$EV_A" || { echo "FAIL: status != observed após replay real"; exit 1; }

set +e
out="$(FORGE_ROOT="$T" bash "$VS" --path "$DIR_A" 2>&1)"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: validate-spec falhou com evidência observed por replay real ($out)"; exit 1; }
echo "$out" | grep -q "OK bug-a" || { echo "FAIL: saída inesperada ($out)"; exit 1; }
echo "OK [3]"

echo "[3-FORJA] FORJA COMPLETA — status:observed escrito à mão (campos internamente consistentes) é ACEITA por check-red-first SOZINHO (limite aceito e documentado, Onda E), mas REPROVADA por validate-spec/spec-verify/archive (gates reais, que chamam 'ensure' incondicionalmente e reexecutam o teste declarado de verdade)"
# Onda E, item 1 (auditoria) — três rodadas tentaram fechar esta forja de dentro do artefato:
# (a) campos auto-declarados (Onda B), (b) replayed_at/replay_head (Onda C), (c) cache local
# chaveado por hash do artefato (Onda D). As três caíram pelo mesmo motivo estrutural — ou o
# campo é escrito por quem está sendo verificado (circular), ou o "atalho" vira, ele mesmo, o
# alvo que os gates passam a exigir para aprovar. A Onda D chegou a REJEITAR esta forja em
# check-red-first sozinho via corroboração por cache — mas isso exigia que o gate ESTÁTICO
# (usado por pre-push/doctor, que precisam ser rápidos) validasse execução, e o único jeito de
# "validar execução sem executar" foi um cache local que virou fonte de livelock e um arquivo
# versionável por acidente em projetos antigos. Removido. Agora: check-red-first.sh check
# SOZINHO aceita esta forja (campos internamente consistentes) — limite aceito, documentado na
# rule. A garantia real está nos GATES que decidem de verdade (validate-spec.mjs — chamado na
# transição para verified — e archive-spec.sh), que chamam `red-evidence.sh ensure`
# incondicionalmente ANTES de avaliar: ensure reexecuta o teste DECLARADO (mesmo o forjado) de
# verdade e sobrescreve o artefato com o resultado real antes que qualquer decisão bloqueante
# seja tomada.
FORJA_EXCERPT="AssertionError: forjado à mão, nunca rodou de verdade"
FORJA_HASH="$(node -e "process.stdout.write(require('crypto').createHash('sha256').update(process.argv[1]).digest('hex'))" "$FORJA_EXCERPT")"
head_now_forja="$(git -C "$T" rev-parse HEAD)"
node -e '
const fs = require("fs");
const p = process.argv[1];
const d = JSON.parse(fs.readFileSync(p, "utf8"));
d.status = "observed";
d.test_path = "tests/bug-a-forja.test.mjs";
d.test_id = "bug-a-forja-regression";
d.command = "node --test tests/bug-a-forja.test.mjs";
d.base_commit = "0123456";
d.excerpt = process.argv[2];
d.excerpt_sha256 = process.argv[3];
d.classification = "behavioral";
d.failure_pattern = "AssertionError";
d.base_result = "failed";
d.fix_files = ["src/bug-a-forja-fix.mjs"];
d.recorded_at = "2026-01-01T00:00:00.000Z";
d.replayed_at = "2026-01-01T00:00:01.000Z";
d.replay_head = process.argv[4];
fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
' "$EV_A" "$FORJA_EXCERPT" "$FORJA_HASH" "$head_now_forja"
# arquivos declarados existem de fato e COMMITADOS (para o motor de replay conseguir derivar uma
# base de verdade — sem histórico git, o veredito seria not-possible, não "fail: não reproduz") —
# mas o teste declarado SEMPRE passou (assert trivial, sem relação nenhuma com fix_files): nunca
# houve Red, em base alguma.
printf 'export function neverBuggy() { return 1; }\n' > "$T/src/bug-a-forja-fix.mjs"
printf "import { test } from 'node:test';\nimport assert from 'node:assert/strict';\ntest('bug-a-forja-regression', () => { assert.strictEqual(1, 1); });\n" > "$T/tests/bug-a-forja.test.mjs"
git -C "$T" add src/bug-a-forja-fix.mjs tests/bug-a-forja.test.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fix: bug-a-forja (nunca houve Red — teste trivial sempre verde)" >/dev/null

set +e
out_check="$(FORGE_ROOT="$T" bash "$CR" check bug-a 2>&1)"; rc_check=$?
set -e
# INFORMATIVO, nunca asserção: o check estático sozinho não executa nada, então hoje ele aceita uma
# forja internamente consistente — limite documentado na rule. Exigir rc=0 aqui transformaria a
# limitação em comportamento obrigatório e deixaria o gate vermelho para quem fortalecesse o check,
# que é o mesmo erro que fez o cache cair (ver ADR-0003, adenda 2). A garantia real é asserida logo
# abaixo, em [3-FORJA/validate-spec], que executa o replay.
echo "INFO [3-FORJA/check] — check estático sozinho (rc=$rc_check): $out_check"

perl -pi -e 's/^status: .*/status: verified/' "$DIR_A/manifest.yaml"
set +e
out_vs="$(FORGE_ROOT="$T" bash "$VS" --path "$DIR_A" 2>&1)"; rc_vs=$?
set -e
[ "$rc_vs" -ne 0 ] || { echo "FAIL [3-FORJA/validate-spec]: validate-spec (gate real, chama ensure) aprovou evidência forjada ($out_vs)"; exit 1; }
echo "OK [3-FORJA/validate-spec] — validate-spec (gate real) reprova ao reexecutar de verdade: $out_vs"
grep -q '"status": "observed"' "$EV_A" && { echo "FAIL [3-FORJA/validate-spec]: ensure deveria ter sobrescrito a forja (ainda observed)"; exit 1; }

# [3-FORJA/sem-FORGE_ROOT] — a invocação de PRODUÇÃO não passa FORGE_ROOT no ambiente (verify.md
# manda rodar `bash .forge/scripts/spec-transition.sh <id> verified` direto). Os scripts precisam
# exportar FORGE_ROOT a partir do próprio ROOT; sem isso o validador resolve o red-evidence.sh a
# partir do diretório do change, o existsSync falha e o replay é PULADO EM SILÊNCIO — furo real
# encontrado em auditoria, invisível para todo teste que invoca com FORGE_ROOT= na frente.
# Reescreve a forja INTEIRA, não só o status: o `ensure` do passo anterior já sobrescreveu o
# artefato com os dados reais da execução (base_result:passed, classification:unknown), e esses
# campos reprovariam sozinhos no check estático — a asserção passaria com e sem o export, ou seja,
# por motivo errado. Só uma forja internamente consistente isola o que este passo quer provar.
node -e '
const fs = require("fs");
const p = process.argv[1];
const d = JSON.parse(fs.readFileSync(p, "utf8"));
d.status = "observed";
d.test_path = "tests/bug-a-forja.test.mjs";
d.test_id = "bug-a-forja-regression";
d.command = "node --test tests/bug-a-forja.test.mjs";
d.base_commit = "0123456";
d.excerpt = process.argv[2];
d.excerpt_sha256 = process.argv[3];
d.classification = "behavioral";
d.failure_pattern = "AssertionError";
d.base_result = "failed";
d.fix_files = ["src/bug-a-forja-fix.mjs"];
d.recorded_at = "2026-01-01T00:00:00.000Z";
d.replayed_at = "2026-01-01T00:00:01.000Z";
d.replay_head = process.argv[4];
fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
' "$EV_A" "$FORJA_EXCERPT" "$FORJA_HASH" "$(git -C "$T" rev-parse HEAD)"
perl -pi -e 's/^status: .*/status: verified/' "$DIR_A/manifest.yaml"
set +e
out_nofr="$(cd "$T" && env -u FORGE_ROOT bash "$T/.forge/scripts/validate-spec.sh" --path "$DIR_A" 2>&1)"; rc_nofr=$?
set -e
[ "$rc_nofr" -ne 0 ] || { echo "FAIL [3-FORJA/sem-FORGE_ROOT]: sem FORGE_ROOT no ambiente o red-first se desligou em silêncio e aprovou a forja ($out_nofr)"; exit 1; }
echo "OK [3-FORJA/sem-FORGE_ROOT] — reprova também na invocação de produção: $out_nofr"
# devolve o manifest ao estado anterior (implementing) — as próximas etapas do gate não devem
# herdar um status verified fabricado por este sub-teste.
perl -pi -e 's/^status: .*/status: implementing/' "$DIR_A/manifest.yaml"

# spec-verify.sh — ensure roda de verdade (o teste declarado sempre passa: nunca reproduz na
# base), então o próprio replay real reescreve a forja com o veredito verdadeiro (FAIL, "não
# reproduz"), e o verify reprova pelo red-first não resolvido.
set +e
out_verify="$(FORGE_ROOT="$T" bash "$T/.forge/scripts/spec-verify.sh" bug-a 2>&1)"; rc_verify=$?
set -e
[ "$rc_verify" -ne 0 ] || { echo "FAIL [3-FORJA/spec-verify]: spec-verify aprovou change com evidência forjada ($out_verify)"; exit 1; }
echo "$out_verify" | grep -qi "red-first" || { echo "FAIL [3-FORJA/spec-verify]: mensagem não cita red-first ($out_verify)"; exit 1; }
echo "OK [3-FORJA/spec-verify] — spec-verify reprova: red-first citado"

# archive-spec.sh — pré-flight (validate-archive) já reprova antes de chegar ao ensure/check do
# red-first, porque o manifest não está verified (a forja nunca conseguiu transicionar) — ainda
# assim, roda o pré-flight completo para confirmar que a cadeia inteira (não só o passo isolado)
# nunca deixa a forja passar.
set +e
out_archive="$(FORGE_ROOT="$T" bash "$T/.forge/scripts/archive-spec.sh" bug-a 2>&1)"; rc_archive=$?
set -e
[ "$rc_archive" -ne 0 ] || { echo "FAIL [3-FORJA/archive]: archive-spec aprovou change com evidência forjada ($out_archive)"; exit 1; }
echo "OK [3-FORJA/archive] — archive reprova: $out_archive"

# restaura bug-a para o estado 'observed' real (do replay legítimo, início do passo [3]) antes de
# seguir com o resto do gate — os passos [7b]/[7c] esperam essa evidência para os testes de waive.
# A forja SOBRESCREVEU a declaração inteira (test_path/command/fix_files viraram os da forja) —
# um re-record com a declaração original é necessário antes de re-replayar; senão o replay
# reproduziria a FORJA (que sempre passa na base) em vez do defeito original de bug-a.
FORGE_ROOT="$T" bash "$RE" record bug-a --test-path tests/bug-a.test.mjs --test-id bug-a-regression --command "node --test tests/bug-a.test.mjs" --fix-files src/bug-a-calc.mjs --failure-pattern AssertionError >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-a 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: restauração pós-forja do replay de bug-a falhou ($out)"; exit 1; }
grep -q '"status": "observed"' "$EV_A" || { echo "FAIL: bug-a não voltou a observed após re-replay"; exit 1; }
echo "OK [3-FORJA]"

# baseline do exit code do doctor com o estado mínimo possível (só bug-a, já resolvido) —
# comparado no passo [8]. Furo 5: o baseline agora é de fato rc=0 (asserção explícita abaixo),
# graças ao saneamento de placeholders/adapters feito no topo do arquivo.
set +e
FORGE_ROOT="$T" bash "$DR" >/dev/null 2>&1; rc_base=$?
set -e
[ "$rc_base" -eq 0 ] || { echo "FAIL: doctor não sai rc=0 no baseline saneado (rc_base=$rc_base) — o passo [8] não teria como distinguir sinal de ruído"; exit 1; }

echo "[4] waiver non-behavioral é recusado quando o DIFF REAL toca código no grafo"
FORGE_ROOT="$T" bash "$SN" bug-b --type bugfix --scale 1 >/dev/null
DIR_B="$T/.forge/specs/active/bug-b"
mkdir -p "$T/.forge/graph" "$T/src/payments"
cat > "$T/.forge/graph/graph.json" <<'JSON'
{ "schema": "graph/v0", "nodes": [{ "id": "src/payments/charge.ts", "layer": "domain" }], "edges": [] }
JSON
# arquivo REAL, tocado de verdade — não commitado (untracked), o caso mais comum de change em
# progresso. `git diff` sozinho não veria isto; realDiffPaths também lê `git status --porcelain`
# por causa exatamente disso. Note: NADA foi declarado em affected_paths do manifest — a fonte
# de verdade agora é o diff, não a autodeclaração (Furo 2).
printf 'export function charge() { return 1; }\n' > "$T/src/payments/charge.ts"
set +e
out="$(FORGE_ROOT="$T" bash "$CR" waive bug-b --reason non-behavioral --note "só typo" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: waiver non-behavioral não foi recusado ($out)"; exit 1; }
echo "$out" | grep -qi "recusad" || { echo "FAIL: mensagem não indica recusa ($out)"; exit 1; }
EV_B="$DIR_B/evidence/red/red-evidence.json"
grep -q '"status": "pending"' "$EV_B" || { echo "FAIL: evidência mutada apesar da recusa"; exit 1; }
# commita o arquivo de teste — sem isso, ele fica untracked pelo resto do gate e o diff real
# (agora escaneado no worktree inteiro, não por-change) contaminaria waives de OUTROS changes
# nos passos seguintes (ex.: [7c] em bug-a). Reflete uma limitação real e deliberada do design
# (Furo 2): sem um conceito de "branch/base por change", o diff real é do worktree inteiro —
# o lado seguro é recusar quando HÁ diff de código no grafo, não tentar adivinhar de quem é.
git -C "$T" add src/payments/charge.ts
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fixture w106: charge.ts (passo 4)" >/dev/null
# commit neutro subsequente: move a ponta de HEAD~1..HEAD para fora de charge.ts — sem isso, o
# fallback do item 6 (Onda D — merge-base==HEAD cai para o ÚLTIMO commit) trataria QUALQUER waive
# non-behavioral posterior neste mesmo $T (compartilhado entre todos os passos do gate, sem
# conceito de branch por change) como se ainda estivesse tocando charge.ts — falso positivo para
# changes completamente não relacionados (ex.: [7c], sobre bug-a). O item 6 de verdade é coberto
# à parte, em fixture isolada (ver [13] mais abaixo).
echo "fixture w106 neutra" > "$T/NOTES-w106.md"
git -C "$T" add NOTES-w106.md
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "chore: marcador neutro pós-charge.ts (evita contaminação do fallback item 6 em passos seguintes)" >/dev/null
echo "OK [4]"

echo "[4-ITEM6] merge-base==HEAD (commit direto na branch base) não esvazia o diff — waiver ainda é recusado"
# Onda D, item 6 — fixture ISOLADA (repo próprio, branch única "main"): reproduz o cenário exato
# do furo — código tocando o grafo committed DIRETO na branch base (sem branch derivada), então
# merge-base(HEAD, main) === HEAD e a fonte (a) de realDiffPaths sai vazia por construção. Sem o
# fallback (a2) (cair para o último commit), o waiver non-behavioral seria aceito por engano —
# "diff vazio" não significa "não toca código", significa "HEAD já é a base".
T6="$(mktemp -d /tmp/forge-w106-item6.XXXXXX)"
cp -R "$WS/template/.forge" "$T6/.forge"
git -C "$T6" init -q -b main
git -C "$T6" config user.email t@t; git -C "$T6" config user.name t; git -C "$T6" config commit.gpgsign false
mkdir -p "$T6/.forge/graph" "$T6/src/billing"
cat > "$T6/.forge/graph/graph.json" <<'JSON'
{ "schema": "graph/v0", "nodes": [{ "id": "src/billing/invoice.ts", "layer": "domain" }], "edges": [] }
JSON
printf 'export function invoice() { return 1; }\n' > "$T6/src/billing/invoice.ts"
git -C "$T6" add -A
git -C "$T6" -c user.email=t@t -c user.name=t commit -qm "chore: init + invoice.ts direto na branch base (fixture item 6)" >/dev/null
FORGE_ROOT="$T6" bash "$T6/.forge/scripts/spec-new.sh" bug-item6 --type bugfix --scale 1 >/dev/null
set +e
out="$(FORGE_ROOT="$T6" bash "$T6/.forge/scripts/check-red-first.sh" waive bug-item6 --reason non-behavioral --note "so tipografia" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [4-ITEM6]: waiver non-behavioral aceito apesar de commit direto na base tocar código do grafo ($out)"; rm -rf "$T6"; exit 1; }
echo "$out" | grep -qi "recusad" || { echo "FAIL [4-ITEM6]: mensagem não indica recusa ($out)"; rm -rf "$T6"; exit 1; }
echo "$out" | grep -q "invoice.ts" || { echo "FAIL [4-ITEM6]: mensagem não cita o arquivo tocado ($out)"; rm -rf "$T6"; exit 1; }
rm -rf "$T6"
echo "OK [4-ITEM6]"

echo "[4-WAIVER-FORJADO] WAIVER FORJADO — colado à mão no JSON (nunca passou por cmdWaive), diff tocando código do grafo, é REPROVADO pelo check"
# Onda D, item 2 — cmdWaive recusa na hora de GRAVAR; mas um waiver colado à mão diretamente no
# JSON (sem nunca invocar /forge:red waive) nunca passava por essa recusa. cmdCheck agora
# REAPLICA a política inteira a cada execução — recalcula o diff real e bloqueia mesmo que o
# waiver já esteja lá, com o motivo declarado sendo non-behavioral e o diff tocando o grafo.
FORGE_ROOT="$T" bash "$SN" bug-waiver-forja --type bugfix --scale 1 >/dev/null
DIR_WF="$T/.forge/specs/active/bug-waiver-forja"
EV_WF="$DIR_WF/evidence/red/red-evidence.json"
mkdir -p "$T/src/payments"
printf 'export function refund() { return 1; }\n' > "$T/src/payments/refund.ts"
# node de grafo cobrindo o arquivo tocado (mesmo grafo do passo [4], estendido)
node -e '
  const fs = require("fs");
  const p = process.argv[1];
  const g = JSON.parse(fs.readFileSync(p, "utf8"));
  if (!g.nodes.some((n) => n.id === "src/payments/refund.ts")) g.nodes.push({ id: "src/payments/refund.ts", layer: "domain" });
  fs.writeFileSync(p, JSON.stringify(g, null, 2) + "\n");
' "$T/.forge/graph/graph.json"
# waiver colado à mão — status já "waived", SEM passar por cmdWaive nenhuma vez.
node -e '
  const fs = require("fs");
  const p = process.argv[1];
  const d = JSON.parse(fs.readFileSync(p, "utf8"));
  d.status = "waived";
  d.waiver = { reason: "non-behavioral", note: "colado a mao, nunca passou por cmdWaive", deferral_id: null, ledger_id: null };
  d.waived_at = "2026-01-01T00:00:00.000Z";
  fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
' "$EV_WF"
set +e
out="$(FORGE_ROOT="$T" bash "$CR" check bug-waiver-forja 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [4-WAIVER-FORJADO]: check aprovou waiver forjado à mão com diff tocando grafo ($out)"; exit 1; }
echo "$out" | grep -qi "waiver non-behavioral inválido" || { echo "FAIL [4-WAIVER-FORJADO]: mensagem não cita waiver inválido ($out)"; exit 1; }
echo "$out" | grep -q "refund.ts" || { echo "FAIL [4-WAIVER-FORJADO]: mensagem não cita o arquivo tocado ($out)"; exit 1; }
echo "OK [4-WAIVER-FORJADO] — check reprova: $out"
# commita refund.ts (+ marcador neutro) — mesmo cuidado do passo [4]: deixá-lo untracked
# contaminaria via git-status--porcelain o próximo waive non-behavioral do gate ([7c], bug-a).
git -C "$T" add src/payments/refund.ts
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fixture w106: refund.ts (passo 4-WAIVER-FORJADO)" >/dev/null
echo "fixture w106 neutra 2" >> "$T/NOTES-w106.md"
git -C "$T" add NOTES-w106.md
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "chore: marcador neutro pós-refund.ts" >/dev/null

echo "[5] waiver non-behavioral (fallback sem git) cobre as três formas de affected_paths"
T2="$(mktemp -d /tmp/forge-w106-nogit.XXXXXX)"
if git -C "$T2" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FAIL: fixture do passo [5] caiu dentro de um worktree git — não testaria o fallback"
  rm -rf "$T2"; exit 1
fi
mkdir -p "$T2/.forge/graph"
cat > "$T2/.forge/graph/graph.json" <<'JSON'
{
  "schema": "graph/v0",
  "nodes": [
    { "id": "app/module/foo.ts", "layer": "domain" },
    { "id": "x/y.ts", "layer": "domain" }
  ],
  "edges": []
}
JSON

mk_nogit_change() { # mk_nogit_change <id> <manifest-affected-paths-fragment>
  local id="$1" frag="$2"
  mkdir -p "$T2/.forge/specs/active/$id/evidence/red"
  { printf 'id: %s\n' "$id"; printf 'type: bugfix\n'; printf '%s\n' "$frag"; } \
    > "$T2/.forge/specs/active/$id/manifest.yaml"
  cat > "$T2/.forge/specs/active/$id/evidence/red/red-evidence.json" <<JSON
{
  "schema": "red-evidence/v1", "change_id": "$id", "status": "pending",
  "test_path": null, "test_id": null, "command": null, "base_commit": null,
  "failure_pattern": null, "excerpt": null, "excerpt_sha256": null, "classification": null,
  "base_result": null, "reproduces": "bugfix.md §1", "fix_files": [], "waiver": null,
  "recorded_at": null, "replayed_at": null, "waived_at": null
}
JSON
}

# forma 1 — bloco YAML, path é PREFIXO de diretório (a forma usada por todos os changes reais
# deste próprio repositório: "template/.forge/", não um arquivo exato)
mk_nogit_change "bug-nogit-block" 'affected_paths:
  - app/module/'
# forma 2 — flow inline, path é arquivo exato
mk_nogit_change "bug-nogit-flow" 'affected_paths: [x/y.ts]'
# forma 3 — vazio/ausente (nada declarado, nada a recusar)
mk_nogit_change "bug-nogit-empty" 'affected_paths: []'

set +e
out="$(FORGE_ROOT="$T2" bash "$CR" waive bug-nogit-block --reason non-behavioral --note x 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [5-block]: waiver não recusado para affected_paths em bloco com prefixo de diretório ($out)"; rm -rf "$T2"; exit 1; }
echo "OK [5-block] forma bloco + prefixo de diretório"

set +e
out="$(FORGE_ROOT="$T2" bash "$CR" waive bug-nogit-flow --reason non-behavioral --note x 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [5-flow]: waiver não recusado para affected_paths em flow inline ($out)"; rm -rf "$T2"; exit 1; }
echo "OK [5-flow] forma flow inline"

set +e
out="$(FORGE_ROOT="$T2" bash "$CR" waive bug-nogit-empty --reason non-behavioral --note x 2>&1)"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL [5-empty]: waiver recusado sem nada declarado em affected_paths ($out)"; rm -rf "$T2"; exit 1; }
echo "OK [5-empty] forma vazia/ausente aceita (nada tocado)"
rm -rf "$T2"
echo "OK [5]"

echo "[6] waiver no-test-infra cria deferral e entrada no ledger"
FORGE_ROOT="$T" bash "$SN" bug-c --type bugfix --scale 1 >/dev/null
set +e
out="$(FORGE_ROOT="$T" bash "$CR" waive bug-c --reason no-test-infra --note "brownfield sem suíte de testes utilizável" 2>&1)"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: waiver no-test-infra falhou ($out)"; exit 1; }
echo "$out" | grep -q "OK waive" || { echo "FAIL: saída inesperada ($out)"; exit 1; }
DEF_C="$T/.forge/specs/active/bug-c/deferrals.json"
[ -f "$DEF_C" ] || { echo "FAIL: deferrals.json não criado"; exit 1; }
grep -q '"status": "open"' "$DEF_C" || { echo "FAIL: deferral não está open"; exit 1; }
LEDGER="$T/.forge/ledger/ledger.json"
[ -f "$LEDGER" ] || { echo "FAIL: ledger.json não criado"; exit 1; }
grep -q "no-test-infra" "$LEDGER" || { echo "FAIL: ledger sem menção a no-test-infra"; exit 1; }
grep -q '"change_id": "bug-c"' "$LEDGER" || { echo "FAIL: ledger sem change_id bug-c"; exit 1; }
EV_C="$T/.forge/specs/active/bug-c/evidence/red/red-evidence.json"
grep -q '"status": "waived"' "$EV_C" || { echo "FAIL: evidência não marcada waived"; exit 1; }
grep -q '"reason": "no-test-infra"' "$EV_C" || { echo "FAIL: waiver.reason não gravado"; exit 1; }
echo "OK [6]"

echo "[8] doctor sinaliza sem alterar o exit code (baseline saneado — rc_base=0)"
set +e
out="$(FORGE_ROOT="$T" bash "$DR" 2>&1)"; rc_after=$?
set -e
echo "$out" | grep -q "red-first" || { echo "FAIL: doctor não mencionou red-first"; exit 1; }
echo "$out" | grep -q "bug-b" || { echo "FAIL: doctor não sinalizou bug-b pendente"; exit 1; }
echo "$out" | grep -q "bug-c" && { echo "FAIL: doctor sinalizou bug-c (waived — deveria estar resolvido)"; exit 1; }
[ "$rc_after" = "$rc_base" ] || { echo "FAIL: check red-first mudou o exit code do doctor ($rc_base -> $rc_after)"; exit 1; }
echo "OK [8]"

echo "[7] waive não é idempotente sem --force"
# 7a — bug-c já foi dispensado no passo [6]; um segundo waive sem --force é recusado, e não
# duplica deferral nem entrada de ledger (Furo 6 — antes, cada waive somava mais um de cada).
DEF_C_BEFORE="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).deferrals.length)' "$DEF_C")"
LEDGER_BEFORE="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).entries.length)' "$LEDGER")"
set +e
out="$(FORGE_ROOT="$T" bash "$CR" waive bug-c --reason no-test-infra --note "de novo" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [7a]: segundo waive sem --force não foi recusado ($out)"; exit 1; }
DEF_C_AFTER="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).deferrals.length)' "$DEF_C")"
LEDGER_AFTER="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).entries.length)' "$LEDGER")"
[ "$DEF_C_AFTER" = "$DEF_C_BEFORE" ] || { echo "FAIL [7a]: segundo waive recusado, mas ainda assim criou deferral ($DEF_C_BEFORE -> $DEF_C_AFTER)"; exit 1; }
[ "$LEDGER_AFTER" = "$LEDGER_BEFORE" ] || { echo "FAIL [7a]: segundo waive recusado, mas ainda assim criou entrada de ledger ($LEDGER_BEFORE -> $LEDGER_AFTER)"; exit 1; }
echo "OK [7a] segundo waive sem --force recusado, sem duplicar deferral/ledger"

# 7b — waive sobre evidência 'observed' (bug-a, do passo [3]) é recusado sem --force: não
# rebaixa em silêncio um Red real e replicado.
set +e
out="$(FORGE_ROOT="$T" bash "$CR" waive bug-a --reason non-behavioral --note "tenta rebaixar" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [7b]: waive sobre evidência observed não foi recusado sem --force ($out)"; exit 1; }
grep -q '"status": "observed"' "$EV_A" || { echo "FAIL [7b]: evidência observed foi rebaixada apesar da recusa"; exit 1; }
echo "OK [7b] waive sobre observed recusado sem --force"

# 7c — com --force, o rebaixamento é permitido; grava waived_at SEM sobrescrever recorded_at
# (Furo 6 — antes, o waive sobrescrevia recorded_at, apagando quando a evidência foi declarada).
RECORDED_AT_BEFORE="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).recorded_at)' "$EV_A")"
set +e
out="$(FORGE_ROOT="$T" bash "$CR" waive bug-a --reason non-behavioral --note "força" --force 2>&1)"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL [7c]: waive --force não foi aceito ($out)"; exit 1; }
grep -q '"status": "waived"' "$EV_A" || { echo "FAIL [7c]: --force não rebaixou a evidência"; exit 1; }
grep -q '"waived_at": "20' "$EV_A" || { echo "FAIL [7c]: waived_at não foi gravado"; exit 1; }
RECORDED_AT_AFTER="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).recorded_at)' "$EV_A")"
[ "$RECORDED_AT_AFTER" = "$RECORDED_AT_BEFORE" ] || { echo "FAIL [7c]: recorded_at foi sobrescrito ($RECORDED_AT_BEFORE -> $RECORDED_AT_AFTER)"; exit 1; }
echo "OK [7c] --force rebaixa e grava waived_at sem tocar recorded_at"

# 7d (Onda D, item 9) — --force SUBSTITUI, não acumula: bug-c já tem 1 deferral + 1 entrada de
# ledger open (do waive no-test-infra do passo [6]). 3x --force com o MESMO reason não podem
# deixar 4 deferrals/4 entradas todas open — um deferral open sozinho já basta para travar o
# archive, então "substituído" precisa significar RESOLVED, não mais um aberto empilhado.
for i in 1 2 3; do
  FORGE_ROOT="$T" bash "$CR" waive bug-c --reason no-test-infra --note "força #$i" --force >/dev/null
done
DEF_C_OPEN="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(d.deferrals.filter(x=>x.status==="open").length)' "$DEF_C")"
DEF_C_TOTAL="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).deferrals.length)' "$DEF_C")"
[ "$DEF_C_OPEN" -eq 1 ] || { echo "FAIL [7d]: esperava exatamente 1 deferral open após 3x --force, achou $DEF_C_OPEN (de $DEF_C_TOTAL total)"; exit 1; }
LEDGER_C_OPEN="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(d.entries.filter(e=>e.source && e.source.change_id === "bug-c" && e.status === "open").length)' "$LEDGER")"
[ "$LEDGER_C_OPEN" -eq 1 ] || { echo "FAIL [7d]: esperava exatamente 1 entrada de ledger open p/ bug-c após 3x --force, achou $LEDGER_C_OPEN"; exit 1; }
echo "OK [7d] 3x --force não acumula deferral/ledger open (1 open, histórico anterior resolved)"
echo "OK [7]"

echo "[9] change type:feature é no-op — nenhum finding"
FORGE_ROOT="$T" bash "$SN" feat-a --type feature --scale 1 >/dev/null
set +e
out="$(FORGE_ROOT="$T" bash "$CR" check feat-a 2>&1)"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: check-red-first falhou para type:feature ($out)"; exit 1; }
echo "$out" | grep -q "n/a" || { echo "FAIL: saída não indica no-op ($out)"; exit 1; }
echo "OK [9]"

echo "[10] itens bloqueantes 2/3/4 e completude de replay via check-red-first check (real)"
FORGE_ROOT="$T" bash "$SN" bug-x --type bugfix --scale 1 >/dev/null
EV_X="$T/.forge/specs/active/bug-x/evidence/red/red-evidence.json"

check_bugx() { # check_bugx <expected-rc> <grep-pattern-or-empty> <label>
  local exp="$1" pat="$2" label="$3"
  set +e
  out="$(FORGE_ROOT="$T" bash "$CR" check bug-x 2>&1)"; rc=$?
  set -e
  [ "$rc" -eq "$exp" ] || { echo "FAIL [$label]: rc=$rc (esperado $exp) ($out)"; exit 1; }
  if [ -n "$pat" ]; then
    echo "$out" | grep -qi "$pat" || { echo "FAIL [$label]: saída não casa com '$pat' ($out)"; exit 1; }
  fi
  echo "OK [$label]"
}

# 10a — item 2: status observed sem excerpt registrado
cat > "$EV_X" <<'JSON'
{
  "schema": "red-evidence/v1", "change_id": "bug-x", "status": "observed",
  "test_path": "tests/bug-x.spec.ts", "test_id": "regression: bug-x defeito",
  "command": "npx vitest run tests/bug-x.spec.ts", "base_commit": "0123456",
  "failure_pattern": "AssertionError", "excerpt": "", "excerpt_sha256": null,
  "classification": "behavioral", "base_result": null, "reproduces": "bugfix.md §1",
  "fix_files": ["src/fix.ts"], "waiver": null, "recorded_at": null, "replayed_at": null,
  "waived_at": null
}
JSON
check_bugx 1 "item 2" "10a-item2-excerpt-vazio"

# 10b — item 2: base_result 'passed' (teste já passava na base — não reproduz nada)
cat > "$EV_X" <<'JSON'
{
  "schema": "red-evidence/v1", "change_id": "bug-x", "status": "observed",
  "test_path": "tests/bug-x.spec.ts", "test_id": "regression: bug-x defeito",
  "command": "npx vitest run tests/bug-x.spec.ts", "base_commit": "0123456",
  "failure_pattern": "AssertionError", "excerpt": "AssertionError: expected 1 to equal 2",
  "excerpt_sha256": null, "classification": "behavioral", "base_result": "passed",
  "reproduces": "bugfix.md §1", "fix_files": ["src/fix.ts"], "waiver": null,
  "recorded_at": null, "replayed_at": null, "waived_at": null
}
JSON
check_bugx 1 "base_result" "10b-item2-base-result-passed"

# 10c — item 3: excerpt classifica como build-error mesmo com classification:"behavioral"
# declarado — o classificador vence o campo auto-declarado (Furo 3)
cat > "$EV_X" <<'JSON'
{
  "schema": "red-evidence/v1", "change_id": "bug-x", "status": "observed",
  "test_path": "tests/bug-x.spec.ts", "test_id": "regression: bug-x defeito",
  "command": "npx vitest run tests/bug-x.spec.ts", "base_commit": "0123456",
  "failure_pattern": "error TS2304", "excerpt": "error TS2304: Cannot find name 'foo'.",
  "excerpt_sha256": null, "classification": "behavioral", "base_result": null,
  "reproduces": "bugfix.md §1", "fix_files": ["src/fix.ts"], "waiver": null,
  "recorded_at": null, "replayed_at": null, "waived_at": null
}
JSON
check_bugx 1 "item 3" "10c-item3-classificador-vence-declarado"

# 10d — item 4: failure_pattern declarado não casa com o excerpt
cat > "$EV_X" <<'JSON'
{
  "schema": "red-evidence/v1", "change_id": "bug-x", "status": "observed",
  "test_path": "tests/bug-x.spec.ts", "test_id": "regression: bug-x defeito",
  "command": "npx vitest run tests/bug-x.spec.ts", "base_commit": "0123456",
  "failure_pattern": "TotallyDifferentPattern",
  "excerpt": "AssertionError: expected 1 to equal 2", "excerpt_sha256": null,
  "classification": "behavioral", "base_result": null, "reproduces": "bugfix.md §1",
  "fix_files": ["src/fix.ts"], "waiver": null, "recorded_at": null, "replayed_at": null,
  "waived_at": null
}
JSON
check_bugx 1 "item 4" "10d-item4-failure-pattern-diverge"

# 10e — completude de replay: base_commit ausente. Antes do Furo 4, um bugfix chegava a
# verified sem test_path/command/base_commit/classification/failure_pattern — a barra
# efetiva era só "existe arquivo com excerpt não-vazio".
cat > "$EV_X" <<'JSON'
{
  "schema": "red-evidence/v1", "change_id": "bug-x", "status": "observed",
  "test_path": "tests/bug-x.spec.ts", "test_id": "regression: bug-x defeito",
  "command": "npx vitest run tests/bug-x.spec.ts", "base_commit": null,
  "failure_pattern": "AssertionError", "excerpt": "AssertionError: expected 1 to equal 2",
  "excerpt_sha256": null, "classification": "behavioral", "base_result": null,
  "reproduces": "bugfix.md §1", "fix_files": ["src/fix.ts"], "waiver": null,
  "recorded_at": null, "replayed_at": null, "waived_at": null
}
JSON
check_bugx 1 "campos obrigat" "10e-completude-de-replay"

# controle — a mesma evidência, completa e consistente, passa sem findings bloqueantes. Onda E,
# item 1 (auditoria) — o controle anterior chegava a 'observed' escrevendo o CACHE local à mão
# (lib/red-replay-cache.mjs, removido); isso testava a mecânica do cache, não o comportamento do
# produto. Reescrito para chegar a 'observed' por REPLAY REAL (mesmo padrão do passo [3]) — um
# defeito genuíno (calc soma errado), teste real, correção real, três commits separados.
mkdir -p "$T/src-x10f" "$T/tests-x10f"
cat > "$T/src-x10f/calc.mjs" <<'JS'
export function calc(a, b) { return a - b; }
JS
git -C "$T" add src-x10f/calc.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "feat: bug-x item10f calc (com bug)" >/dev/null
cat > "$T/tests-x10f/calc.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calc } from '../src-x10f/calc.mjs';
test('bug-x-regression', () => { assert.strictEqual(calc(2, 3), 5); });
JS
git -C "$T" add tests-x10f/calc.test.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "test: regressão bug-x item10f" >/dev/null
cat > "$T/src-x10f/calc.mjs" <<'JS'
export function calc(a, b) { return a + b; }
JS
git -C "$T" add src-x10f/calc.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fix: bug-x item10f — calc soma certo" >/dev/null

out="$(FORGE_ROOT="$T" bash "$RE" record bug-x --test-path tests-x10f/calc.test.mjs --test-id bug-x-regression --command "node --test tests-x10f/calc.test.mjs" --fix-files src-x10f/calc.mjs --failure-pattern AssertionError 2>&1)"
echo "$out" | grep -q "OK record" || { echo "FAIL [10f]: record não confirmou ($out)"; exit 1; }
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-x 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [10f]: replay real esperava sucesso ($out)"; exit 1; }
check_bugx 0 "" "10f-controle-baseline-valida-com-replay-real"
echo "OK [10]"

echo "[11] itens rebaixáveis 5/6/7/8 via check-red-first check, chegando a observed por REPLAY REAL"
# Onda E, item 1 (auditoria) — antes, cada sub-caso chegava a 'observed' escrevendo o CAMPO à mão
# (status/excerpt/classification) e depois o CACHE local à mão (write_ev_d + write-cache.mjs) —
# nenhuma execução de teste acontecia nunca. Isso testava a mecânica do artefato/cache, não o
# comportamento do produto, e qualquer correção real do design fazia o gate ficar vermelho —
# exatamente o padrão do furo. Reescrito: cada sub-caso é um DEFEITO GENUÍNO (soma errada),
# reproduzido por REPLAY REAL (mesmo padrão dos passos [3]/[10f]) — a única diferença entre os
# cinco é a FORMA do fixture (grafo sem edge, commit único, nome neutro, mock/spy textual), não o
# mecanismo de prova.
FORGE_ROOT="$T" bash "$SN" bug-d --type bugfix --scale 1 >/dev/null
EV_D="$T/.forge/specs/active/bug-d/evidence/red/red-evidence.json"

check_bugd() { # check_bugd <grep-pattern> <label>
  set +e
  out="$(FORGE_ROOT="$T" bash "$CR" check bug-d 2>&1)"; rc=$?
  set -e
  [ "$rc" -eq 0 ] || { echo "FAIL [$2]: rc=$rc (esperado 0 — item rebaixável não deve bloquear) ($out)"; exit 1; }
  echo "$out" | grep -q "WARN" || { echo "FAIL [$2]: saída sem WARN ($out)"; exit 1; }
  echo "$out" | grep -qi "$1" || { echo "FAIL [$2]: saída não casa com '$1' ($out)"; exit 1; }
  echo "OK [$2]"
}

# item 5 — teste não alcança, no grafo, nenhum arquivo corrigido: nodes de teste E correção
# presentes no grafo, SEM edge conectando os dois (checkReachability resolve ambos e não acha
# interseção — 'no-intersection', não 'unknown').
mkdir -p "$T/src-d5" "$T/tests-d5"
cat > "$T/src-d5/calc.mjs" <<'JS'
export function calc(a, b) { return a - b; }
JS
git -C "$T" add src-d5/calc.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "feat: bug-d item5 calc (com bug)" >/dev/null
cat > "$T/tests-d5/calc.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calc } from '../src-d5/calc.mjs';
test('bug-d5-regression', () => { assert.strictEqual(calc(2, 3), 5); });
JS
git -C "$T" add tests-d5/calc.test.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "test: regressão bug-d item5" >/dev/null
cat > "$T/src-d5/calc.mjs" <<'JS'
export function calc(a, b) { return a + b; }
JS
git -C "$T" add src-d5/calc.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fix: bug-d item5 — calc soma certo" >/dev/null
node -e '
  const fs = require("fs");
  const p = process.argv[1];
  const g = JSON.parse(fs.readFileSync(p, "utf8"));
  g.nodes.push({ id: "src-d5/calc.mjs", layer: "domain" }, { id: "tests-d5/calc.test.mjs", layer: "test" });
  fs.writeFileSync(p, JSON.stringify(g, null, 2) + "\n");
' "$T/.forge/graph/graph.json"
FORGE_ROOT="$T" bash "$RE" record bug-d --test-path tests-d5/calc.test.mjs --test-id bug-d5-regression --command "node --test tests-d5/calc.test.mjs" --fix-files src-d5/calc.mjs --failure-pattern AssertionError >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-d 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [11a]: replay real (fixture item 5) esperava sucesso ($out)"; exit 1; }
check_bugd "item 5" "11a-item5-no-intersection"

# item 6 — teste e correção no MESMO commit (squash) — deriveBase cai em revert-synthesis (não
# há como separar temporalmente Red de Green), mas o replay ainda observa um defeito genuíno.
mkdir -p "$T/src-d6" "$T/tests-d6"
cat > "$T/src-d6/calc.mjs" <<'JS'
export function calc(a, b) { return a - b; }
JS
git -C "$T" add src-d6/calc.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "feat: bug-d item6 calc (com bug)" >/dev/null
cat > "$T/src-d6/calc.mjs" <<'JS'
export function calc(a, b) { return a + b; }
JS
cat > "$T/tests-d6/calc.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calc } from '../src-d6/calc.mjs';
test('bug-d6-regression', () => { assert.strictEqual(calc(2, 3), 5); });
JS
git -C "$T" add src-d6/calc.mjs tests-d6/calc.test.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fix: bug-d item6 — teste e correção juntos (squash)" >/dev/null
FORGE_ROOT="$T" bash "$RE" record bug-d --test-path tests-d6/calc.test.mjs --test-id bug-d6-regression --command "node --test tests-d6/calc.test.mjs" --fix-files src-d6/calc.mjs --failure-pattern AssertionError >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-d 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [11b]: replay real (fixture item 6, revert-synthesis) esperava sucesso ($out)"; exit 1; }
check_bugd "item 6" "11b-item6-mesmo-commit"

# item 7 — nome de teste sem referência ao defeito: nem keyword (bug/regress/defect/...) nem
# slug do change id ("bug") aparecem em test_id.
mkdir -p "$T/src-d7" "$T/tests-d7"
cat > "$T/src-d7/calc.mjs" <<'JS'
export function calc(a, b) { return a - b; }
JS
git -C "$T" add src-d7/calc.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "feat: bug-d item7 calc (com bug)" >/dev/null
cat > "$T/tests-d7/calc.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calc } from '../src-d7/calc.mjs';
test('generic-behavior-check', () => { assert.strictEqual(calc(2, 3), 5); });
JS
git -C "$T" add tests-d7/calc.test.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "test: caso de comportamento genérico (item7)" >/dev/null
cat > "$T/src-d7/calc.mjs" <<'JS'
export function calc(a, b) { return a + b; }
JS
git -C "$T" add src-d7/calc.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fix: bug-d item7 — calc soma certo" >/dev/null
FORGE_ROOT="$T" bash "$RE" record bug-d --test-path tests-d7/calc.test.mjs --test-id generic-behavior-check --command "node --test tests-d7/calc.test.mjs" --fix-files src-d7/calc.mjs --failure-pattern AssertionError >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-d 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [11c]: replay real (fixture item 7) esperava sucesso ($out)"; exit 1; }
check_bugd "item 7" "11c-item7-nome-sem-referencia"

# item 8a — mock do módulo inteiro, path COM extensão (Furo 7 — a regex de mock precisa tolerar
# a extensão sobrando antes da aspa de fechamento). O `vi.mock(...)` é um marcador TEXTUAL
# INERTE — o fixture roda em node:test (não vitest), então fica em comentário; a asserção real
# roda contra a implementação de verdade, sem mock nenhum.
mkdir -p "$T/src-d8a" "$T/tests-d8a"
cat > "$T/src-d8a/thing.mjs" <<'JS'
export function doThing() { return 1; }
JS
git -C "$T" add src-d8a/thing.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "feat: bug-d item8a thing (com bug)" >/dev/null
cat > "$T/tests-d8a/thing.test.mjs" <<'JS'
// vi.mock('../src-d8a/thing.mjs') — marcador textual inerte (ver nota acima); a asserção abaixo
// roda de verdade, sem mock nenhum.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { doThing } from '../src-d8a/thing.mjs';
test('bug-d8a-regression', () => { assert.strictEqual(doThing(), 2); });
JS
git -C "$T" add tests-d8a/thing.test.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "test: regressão bug-d item8a" >/dev/null
cat > "$T/src-d8a/thing.mjs" <<'JS'
export function doThing() { return 2; }
JS
git -C "$T" add src-d8a/thing.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fix: bug-d item8a — doThing retorna valor certo" >/dev/null
FORGE_ROOT="$T" bash "$RE" record bug-d --test-path tests-d8a/thing.test.mjs --test-id bug-d8a-regression --command "node --test tests-d8a/thing.test.mjs" --fix-files src-d8a/thing.mjs --failure-pattern AssertionError >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-d 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [11d]: replay real (fixture item 8a) esperava sucesso ($out)"; exit 1; }
check_bugd "item 8" "11d-item8a-mock-modulo-com-extensao"

# item 8b — jest/vi.spyOn de símbolo exportado, SEM a palavra "mock" no texto (Furo 7 — o guard
# antigo matava esse caso inteiro). Marcador textual inerte, mesmo racional do item 8a.
mkdir -p "$T/src-d8b" "$T/tests-d8b"
cat > "$T/src-d8b/spyfix.mjs" <<'JS'
export function doThing() { return 1; }
JS
git -C "$T" add src-d8b/spyfix.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "feat: bug-d item8b spyfix (com bug)" >/dev/null
cat > "$T/tests-d8b/spyfix.test.mjs" <<'JS'
// vi.spyOn(m, 'doThing') — marcador textual inerte, sem a palavra "mock" no texto.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { doThing } from '../src-d8b/spyfix.mjs';
test('bug-d8b-regression', () => { assert.strictEqual(doThing(), 2); });
JS
git -C "$T" add tests-d8b/spyfix.test.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "test: regressão bug-d item8b" >/dev/null
cat > "$T/src-d8b/spyfix.mjs" <<'JS'
export function doThing() { return 2; }
JS
git -C "$T" add src-d8b/spyfix.mjs
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "fix: bug-d item8b — doThing retorna valor certo" >/dev/null
FORGE_ROOT="$T" bash "$RE" record bug-d --test-path tests-d8b/spyfix.test.mjs --test-id bug-d8b-regression --command "node --test tests-d8b/spyfix.test.mjs" --fix-files src-d8b/spyfix.mjs --failure-pattern AssertionError >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" replay bug-d 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [11e]: replay real (fixture item 8b) esperava sucesso ($out)"; exit 1; }
check_bugd "item 8" "11e-item8b-spyon-sem-palavra-mock"
echo "OK [11]"

echo "[12] red-classify distingue build-error de behavioral (famílias + falsos positivos)"
cat > "$T/check-classify.mjs" <<'MJS'
import { classify } from './.forge/scripts/lib/red-classify.mjs';
const cases = [
  // build-error — assinaturas ancoradas, formato real de traceback/compilador
  ['error TS2304: Cannot find name \'foo\'.', 'build-error'],
  ['Program.cs(10,5): error CS0103: The name \'x\' does not exist', 'build-error'],
  ['Foo.java:10: error: cannot find symbol', 'build-error'],
  ['Traceback (most recent call last):\nModuleNotFoundError: No module named \'foo\'', 'build-error'],
  ['# command-line-arguments\nundefined: fmt.Prontln', 'build-error'],
  ['SyntaxError: Unexpected token \'{\'', 'build-error'],
  // controle do Furo 8: SEM o prefixo "E   " do pytest, é erro real de import/coleta — a
  // mesma classe de mensagem que, prefixada de "E   ", é comportamental (ver abaixo)
  ['ImportError: cannot import name \'X\' from \'Y\'', 'build-error'],
  // behavioral — famílias já cobertas
  ['AssertionError: expected 1 to equal 2', 'behavioral'],
  ['Expected: 3\nReceived: 4', 'behavioral'],
  ['E       assert 1 == 2', 'behavioral'],
  // Furo 8 — falsos positivos corrigidos
  ['AssertionError: expected [Function] to throw SyntaxError but got Error', 'behavioral'],
  ['E   ImportError: cannot import name \'X\' from \'Y\'', 'behavioral'],
  // Furo 8 — famílias novas, uma por linguagem exigida (.NET, Java, Go, Rust) + bônus
  ['Xunit.Sdk.EqualException: Assert.Equal() Failure\nExpected: 4\nActual: 3', 'behavioral'],
  ['org.opentest4j.AssertionFailedError: expected: <4> but was: <3>', 'behavioral'],
  ['org.junit.ComparisonFailure: expected:<3> but was:<4>', 'behavioral'],
  ['--- FAIL: TestFoo (0.00s)\n    foo_test.go:10: got 3, want 4', 'behavioral'],
  ["thread 'main' panicked at 'assertion `left == right` failed\n  left: 1\n right: 2'", 'behavioral'],
  ['Failure/Error: expect(result).to eq(4)\n\n  expected: 4\n       got: 3', 'behavioral'],
  ['1) MyTest::testFoo\nFailed asserting that 2 matches expected 4.', 'behavioral'],
  // Onda D, item 10 — assinatura pytest ANCORADA: qualquer linha começando com "E " não é mais
  // suficiente (a versão anterior, `^E\s+\S`, classificava prosa arbitrária como comportamental
  // só por começar com "E "). Só "E   assert ..." ou "E   <Algo>Error/<Algo>Exception: ..."
  // contam — texto solto que por acaso começa com "E " não deve classificar como behavioral nem
  // build-error.
  ['E   this is not an assertion or error at all', 'unknown'],
  ['E   Everyone knows this fact', 'unknown'],
];
let fail = 0;
for (const [text, expected] of cases) {
  const got = classify(text);
  if (got !== expected) { console.error(`MISMATCH: ${JSON.stringify(text)} -> ${got} (esperado ${expected})`); fail = 1; }
}
process.exit(fail);
MJS
(cd "$T" && node check-classify.mjs) || { echo "FAIL: red-classify não distinguiu corretamente"; exit 1; }
echo "OK [12]"

echo "[13] Onda E, item 3a — waiver colado à mão em no-test-infra/external-unreproducible SEM deferral real é REPROVADO"
# cmdWaive (via /forge:red waive) sempre abre um deferral de verdade para estes dois motivos —
# mas um waiver colado à mão diretamente no JSON (nunca passou por cmdWaive) podia referenciar
# um deferral_id/ledger_id inventado. evaluateRedFirst agora reaplica a política a CADA check:
# confere que o DEFER-NN declarado existe de verdade em deferrals.json do change.
for reason_id in "no-test-infra:bug-w4b" "external-unreproducible:bug-w4c"; do
  reason="${reason_id%%:*}"; cid="${reason_id##*:}"
  FORGE_ROOT="$T" bash "$SN" "$cid" --type bugfix --scale 1 >/dev/null
  EVX="$T/.forge/specs/active/$cid/evidence/red/red-evidence.json"
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    d.status = "waived";
    d.waiver = { reason: process.argv[2], note: "colado a mao, sem deferral real", deferral_id: "DEFER-999", ledger_id: "LDG-9999" };
    d.waived_at = "2026-01-01T00:00:00.000Z";
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
  ' "$EVX" "$reason"
  set +e
  out="$(FORGE_ROOT="$T" bash "$CR" check "$cid" 2>&1)"; rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL [13/$reason]: check aprovou waiver '$reason' sem deferral real ($out)"; exit 1; }
  echo "$out" | grep -qi "deferral correspondente" || { echo "FAIL [13/$reason]: mensagem não cita a ausência de deferral real ($out)"; exit 1; }
  echo "OK [13/$reason] — check reprova: $out"
done
# controle — os MESMOS dois motivos, gravados pelo caminho real (/forge:red waive via cmdWaive),
# passam sem findings bloqueantes (deferral de verdade existe e casa).
FORGE_ROOT="$T" bash "$SN" bug-w4b-ctrl --type bugfix --scale 1 >/dev/null
out="$(FORGE_ROOT="$T" bash "$CR" waive bug-w4b-ctrl --reason no-test-infra --note "sem suite de testes" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [13/ctrl]: waive real de no-test-infra falhou ($out)"; exit 1; }
out="$(FORGE_ROOT="$T" bash "$CR" check bug-w4b-ctrl 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [13/ctrl]: check reprovou waiver no-test-infra gravado pelo caminho real ($out)"; exit 1; }
echo "OK [13]"

echo "[14] Onda E, item 3a — waiver 'hotfix-under-incident' exige deferral com blocks:[archive]"
FORGE_ROOT="$T" bash "$SN" bug-w4d --type bugfix --scale 1 >/dev/null
DIR_W4D="$T/.forge/specs/active/bug-w4d"
EV_W4D="$DIR_W4D/evidence/red/red-evidence.json"
out_def="$(FORGE_ROOT="$T" bash "$T/.forge/scripts/deferral-ops.sh" raise bug-w4d --reason "hotfix sem blocks" 2>&1)"
DEF_NO_BLOCKS="$(echo "$out_def" | grep -oE 'DEFER-[0-9]+')"
[ -n "$DEF_NO_BLOCKS" ] || { echo "FAIL [14]: deferral-ops raise não retornou id ($out_def)"; exit 1; }
node -e '
  const fs = require("fs");
  const p = process.argv[1];
  const d = JSON.parse(fs.readFileSync(p, "utf8"));
  d.status = "waived";
  d.waiver = { reason: "hotfix-under-incident", note: "incidente em produção", deferral_id: process.argv[2], ledger_id: null };
  d.waived_at = "2026-01-01T00:00:00.000Z";
  fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
' "$EV_W4D" "$DEF_NO_BLOCKS"
set +e
out="$(FORGE_ROOT="$T" bash "$CR" check bug-w4d 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [14a]: check aprovou hotfix-under-incident com deferral SEM blocks:[archive] ($out)"; exit 1; }
echo "$out" | grep -q 'blocks:\[archive\]' || { echo "FAIL [14a]: mensagem não cita blocks:[archive] ($out)"; exit 1; }
echo "OK [14a] — check reprova deferral sem blocks:[archive]: $out"

out_def2="$(FORGE_ROOT="$T" bash "$T/.forge/scripts/deferral-ops.sh" raise bug-w4d --reason "hotfix com blocks" --blocks archive 2>&1)"
DEF_WITH_BLOCKS="$(echo "$out_def2" | grep -oE 'DEFER-[0-9]+')"
[ -n "$DEF_WITH_BLOCKS" ] || { echo "FAIL [14b]: deferral-ops raise (com blocks) não retornou id ($out_def2)"; exit 1; }
node -e '
  const fs = require("fs");
  const p = process.argv[1];
  const d = JSON.parse(fs.readFileSync(p, "utf8"));
  d.waiver.deferral_id = process.argv[2];
  fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
' "$EV_W4D" "$DEF_WITH_BLOCKS"
set +e
out="$(FORGE_ROOT="$T" bash "$CR" check bug-w4d 2>&1)"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL [14b]: check reprovou hotfix-under-incident com deferral de verdade e blocks:[archive] ($out)"; exit 1; }
echo "OK [14b] — check aceita deferral real com blocks:[archive]: $out"
echo "OK [14]"

echo "[15] Onda E, item 3c — grafo ausente é REGENERADO antes de decidir o waiver non-behavioral (nunca permite em silêncio)"
mkdir -p "$T/src-graphregen"
printf 'export function regenProbe() { return 1; }\n' > "$T/src-graphregen/probe.mjs"
# arquivo NÃO commitado (untracked) — realDiffPaths sempre enxerga untracked via
# `git status --porcelain`, independente de onde HEAD está nesta árvore com dezenas de commits
# de fixture acumulados pelos passos anteriores.
FORGE_ROOT="$T" bash "$SN" bug-graphregen --type bugfix --scale 1 >/dev/null
GRAPH_BACKUP="$T/.forge/graph/graph.json.bak-w106"
cp "$T/.forge/graph/graph.json" "$GRAPH_BACKUP"
rm -f "$T/.forge/graph/graph.json"
set +e
out="$(FORGE_ROOT="$T" bash "$CR" waive bug-graphregen --reason non-behavioral --note "so documentacao" 2>&1)"; rc=$?
set -e
[ -f "$T/.forge/graph/graph.json" ] || { echo "FAIL [15]: grafo não foi regenerado (graph.sh update deveria ter rodado antes de decidir)"; exit 1; }
[ "$rc" -ne 0 ] || { echo "FAIL [15]: waiver non-behavioral deveria ser recusado — probe.mjs é código real, presente no grafo recém-regenerado ($out)"; exit 1; }
echo "$out" | grep -qi "recusad" || { echo "FAIL [15]: mensagem não indica recusa ($out)"; exit 1; }
cp "$GRAPH_BACKUP" "$T/.forge/graph/graph.json"
rm -f "$GRAPH_BACKUP" "$T/src-graphregen/probe.mjs"
rmdir "$T/src-graphregen" 2>/dev/null || true
echo "OK [15] — grafo regenerado automaticamente e waiver recusado (arquivo real detectado após regen)"

echo "[16] Onda E, item 3c — grafo continua indisponível após a tentativa de regeneração é REPROVADO (nunca permite em silêncio)"
# fixture ISOLADA sem .forge/scripts/graph.sh — a tentativa de regeneração não tem como
# funcionar (script ausente), e o resultado tem que ser 'não pôde ser verificado', não 'permitido'.
T16="$(mktemp -d /tmp/forge-w106-nograph.XXXXXX)"
cp -R "$WS/template/.forge" "$T16/.forge"
rm -f "$T16/.forge/scripts/graph.sh"
git -C "$T16" init -q -b main
git -C "$T16" config user.email t@t; git -C "$T16" config user.name t; git -C "$T16" config commit.gpgsign false
mkdir -p "$T16/src16"
printf 'export function probe16() { return 1; }\n' > "$T16/src16/probe.mjs"
git -C "$T16" add -A
git -C "$T16" commit -qm "chore: init sem graph.sh (fixture item 3c, regen impossível)" >/dev/null
FORGE_ROOT="$T16" bash "$T16/.forge/scripts/spec-new.sh" bug-nograph --type bugfix --scale 1 >/dev/null
echo "mais um toque" >> "$T16/src16/probe.mjs"
set +e
out="$(FORGE_ROOT="$T16" bash "$T16/.forge/scripts/check-red-first.sh" waive bug-nograph --reason non-behavioral --note "so documentacao" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [16]: waiver non-behavioral aceito sem conseguir verificar o grafo (graph.sh ausente) ($out)"; rm -rf "$T16"; exit 1; }
echo "$out" | grep -qi "recusad" || { echo "FAIL [16]: mensagem não indica recusa ($out)"; rm -rf "$T16"; exit 1; }
rm -rf "$T16"
echo "OK [16] — grafo indisponível após tentativa de regen é reprovado, não permitido em silêncio"

echo "[17] Onda E, item 3d — mudar type após evidência gravada emite WARN (não trava, deixa rastro)"
FORGE_ROOT="$T" bash "$SN" bug-typechange --type bugfix --scale 1 >/dev/null
DIR_TC="$T/.forge/specs/active/bug-typechange"
FORGE_ROOT="$T" bash "$RE" record bug-typechange --test-path tests/bug-a.test.mjs --test-id bug-a-regression --command "node --test tests/bug-a.test.mjs" --fix-files src/bug-a-calc.mjs --failure-pattern AssertionError >/dev/null
perl -pi -e 's/^type: .*/type: refactor/' "$DIR_TC/manifest.yaml"
out="$(FORGE_ROOT="$T" bash "$CR" check bug-typechange 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [17]: mudar type não deveria travar o check (n/a — apenas WARN) ($out)"; exit 1; }
echo "$out" | grep -q "WARN" || { echo "FAIL [17]: saída sem WARN após mudança de type com evidência gravada ($out)"; exit 1; }
echo "$out" | grep -qi "type mudou" || { echo "FAIL [17]: mensagem não cita a mudança de type ($out)"; exit 1; }
echo "OK [17a] — WARN emitido quando type muda após /forge:red record"
# controle — mudar type ANTES de qualquer /forge:red record (só o scaffold trivial de spec-new,
# status:pending, recorded_at:null) não gera warning nenhum — recategorizar antes de qualquer
# trabalho de red-first não é sinal de nada.
FORGE_ROOT="$T" bash "$SN" bug-typechange-early --type bugfix --scale 1 >/dev/null
perl -pi -e 's/^type: .*/type: feature/' "$T/.forge/specs/active/bug-typechange-early/manifest.yaml"
out="$(FORGE_ROOT="$T" bash "$CR" check bug-typechange-early 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [17b]: check falhou para type mudado antes de qualquer record ($out)"; exit 1; }
echo "$out" | grep -q "WARN" && { echo "FAIL [17b]: WARN inesperado — scaffold trivial nunca foi 'gravado' de verdade ($out)"; exit 1; }
echo "OK [17b] — sem WARN quando a mudança de type precede qualquer /forge:red record (scaffold trivial)"
echo "OK [17]"

echo "PASS w106-red-first-gate"
