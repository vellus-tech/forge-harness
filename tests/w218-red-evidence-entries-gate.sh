#!/usr/bin/env bash
# Gate W218 — `/forge:red record` acumula defeitos em `entries[]` em vez de sobrescrever a
# evidência anterior (issue #139).
#
# Causa raiz medida: `red-evidence-ops.mjs` (cmdRecord) copiava os escalares do TOPO
# (`{ ...ev.data }`), atribuía campo a campo e gravava com `writeJsonAtomic` — um segundo
# `record` apagava o primeiro, e um `record` parcial (só `--failure-pattern`) herdava
# test_path/test_id/command de OUTRO defeito porque esses campos já estavam no topo herdado.
#
#   [1] positivo — `record --id A` seguido de `record --id B` (ids diferentes) preserva as DUAS
#       entradas em `entries[]`; nenhuma sobrescreve a outra
#   [2] contrafactual — `record` SEM `--id` num change que já tem 2+ entradas é recusado
#       (rc≠0, fail-closed contra quimera) e o arquivo fica byte-a-byte intacto
#   [3] retrocompatível — `record` sem `--id` num change com UMA entrada (o fluxo comum,
#       defeito único) continua atualizando essa mesma entrada, sem crescer para 2
#   [4] legado (J-14) — um `red-evidence.json` de formato antigo (populado, sem `entries[]`,
#       em voo em centenas de changes de consumidores) tem seu conteúdo preservado
#       verbatim como a PRIMEIRA entrada quando `record --id` é usado pela primeira vez; a
#       nova declaração vira uma entrada adicional; o topo continua projetando o legado
#   [5] scaffold vazio (J-14) — um `red-evidence.json` nunca gravado (`recorded_at: null`,
#       `status: pending`) não deixa entrada fantasma: `record --id` cria só a entrada nova
#   [6] status do topo é DERIVADO — observed só quando TODAS as entradas estão
#       observed|waived; uma entrada pendente mantém o topo pending mesmo com outra observed
#   [7] schema/validador aceitam um arquivo legado (sem `entries`) e um arquivo com `entries[]`
#       populado — a propriedade é aditiva, não quebra leitor nem escritor antigo
#   [8] check-red-first.mjs status lê `entries[]` para informar quantas estão resolvidas, sem
#       mudar o veredito OK/PENDING (que continua vindo do status do topo já derivado)
#   [9] PROPRIEDADE PBT — para estados iniciais gerados entre vazio e legado, seguidos de
#       sequências geradas de `record --id <k>` com campos aleatórios: cada id aparece
#       exatamente uma vez em entries, a última declaração por id vence, nenhum campo de um id
#       aparece na entrada de outro, e o topo é igual à projeção da primeira entrada
#  [10] MUTAÇÃO — trocar a escrita em entries[] pela atribuição no topo (como antes da correção)
#       faz o cenário [1] falhar (DefeitoA some, contagem 0); recontrole restaura rc 0
#  [11] MUTAÇÃO — remover a recusa sem --id faz o cenário [2] (quimera) sair rc 0; recontrole
#       restaura a recusa
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
T="$(mktemp -d /tmp/forge-w218.XXXXXX)"
trap 'rm -rf "$T"' EXIT

mk_root() { # mk_root <dir>
  local dir="$1"
  cp -R "$WS/template/.forge" "$dir/.forge"
  git -C "$dir" init -q
  git -C "$dir" config user.email t@t; git -C "$dir" config user.name t; git -C "$dir" config commit.gpgsign false
  git -C "$dir" add -A && git -C "$dir" commit -qm init >/dev/null
}

mk_root "$T"
RE="$T/.forge/scripts/red-evidence.sh"
SN="$T/.forge/scripts/spec-new.sh"
CR="$T/.forge/scripts/check-red-first.sh"

echo "[1] record --id A e --id B preservam as duas entradas"
FORGE_ROOT="$T" bash "$SN" bug-multi --type bugfix --scale 1 >/dev/null
DIR1="$T/.forge/specs/active/bug-multi"
EV1="$DIR1/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-multi --id DefeitoA --test-path tests/a.test.mjs --test-id case-a --command "node --test tests/a.test.mjs" --fix-files src/a.sh --failure-pattern PA >/dev/null
FORGE_ROOT="$T" bash "$RE" record bug-multi --id DefeitoB --test-path tests/b.test.mjs --test-id case-b --command "node --test tests/b.test.mjs" --fix-files src/b.sh --failure-pattern PB >/dev/null
n_a="$(grep -c DefeitoA "$EV1" || true)"
[ "$n_a" -ge 1 ] || { echo "FAIL [1]: DefeitoA desapareceu do arquivo depois do record de DefeitoB ($EV1)"; exit 1; }
n_entries="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).entries.length)" "$EV1")"
[ "$n_entries" -eq 2 ] || { echo "FAIL [1]: esperado 2 entradas, achou $n_entries"; exit 1; }
echo "OK [1]"

echo "[2] record sem --id com 2+ entradas é recusado, arquivo intacto"
cp "$EV1" "$T/ev1-antes.json"
set +e
out="$(FORGE_ROOT="$T" bash "$RE" record bug-multi --failure-pattern PC 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [2]: record ambíguo (sem --id, 2 entradas) foi aceito ($out)"; exit 1; }
grep -qi -- "--id" <<<"$out" || { echo "FAIL [2]: mensagem não cita --id ($out)"; exit 1; }
cmp -s "$EV1" "$T/ev1-antes.json" || { echo "FAIL [2]: arquivo foi tocado apesar da recusa"; exit 1; }
echo "OK [2]"

echo "[3] record sem --id com 1 entrada atualiza a MESMA entrada (fluxo comum, retrocompatível)"
FORGE_ROOT="$T" bash "$SN" bug-single --type bugfix --scale 1 >/dev/null
EV3="$T/.forge/specs/active/bug-single/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-single --test-path tests/s.test.mjs --test-id case-s --command "node --test tests/s.test.mjs" --fix-files src/s.sh --failure-pattern PS1 >/dev/null
FORGE_ROOT="$T" bash "$RE" record bug-single --failure-pattern PS2 >/dev/null
n3="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).entries.length)" "$EV3")"
[ "$n3" -eq 1 ] || { echo "FAIL [3]: change de defeito único cresceu para $n3 entradas"; exit 1; }
pat3="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).failure_pattern)" "$EV3")"
[ "$pat3" = "PS2" ] || { echo "FAIL [3]: segundo record não atualizou a entrada única (failure_pattern=$pat3)"; exit 1; }
echo "OK [3]"

echo "[4] legado (sem entries) preservado verbatim como entries[0] no primeiro record --id"
FORGE_ROOT="$T" bash "$SN" bug-legacy --type bugfix --scale 1 >/dev/null
DIR4="$T/.forge/specs/active/bug-legacy"
EV4="$DIR4/evidence/red/red-evidence.json"
node -e '
const fs = require("fs");
const p = process.argv[1];
const d = JSON.parse(fs.readFileSync(p, "utf8"));
d.status = "observed"; d.test_path = "tests/legacy.test.mjs"; d.test_id = "legacy-case";
d.command = "node --test tests/legacy.test.mjs"; d.failure_pattern = "AssertionError";
d.excerpt = "AssertionError: legado"; d.excerpt_sha256 = require("crypto").createHash("sha256").update(d.excerpt).digest("hex");
d.classification = "behavioral"; d.base_result = "failed"; d.fix_files = ["src/legacy.sh"];
d.recorded_at = "2026-01-01T00:00:00.000Z"; d.replayed_at = "2026-01-01T00:00:01.000Z";
fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
' "$EV4"
LEGACY_BEFORE="$(node -e "const d=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); delete d.status; delete d.entries; console.log(JSON.stringify(d))" "$EV4")"
FORGE_ROOT="$T" bash "$RE" record bug-legacy --id NovoDefeito --test-path tests/novo.test.mjs --test-id novo-case --command "node --test tests/novo.test.mjs" --fix-files src/novo.sh --failure-pattern PN >/dev/null
node -e "
const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
if (d.entries.length !== 2) { console.error('esperava 2 entradas, achou ' + d.entries.length); process.exit(1); }
const legacy = d.entries[0];
if (legacy.id !== null) { console.error('entries[0].id deveria ser null (legado sem id), achou ' + legacy.id); process.exit(1); }
if (legacy.test_path !== 'tests/legacy.test.mjs' || legacy.excerpt !== 'AssertionError: legado' || legacy.status !== 'observed') {
  console.error('legado não preservado verbatim: ' + JSON.stringify(legacy)); process.exit(1);
}
const novo = d.entries[1];
if (novo.id !== 'NovoDefeito' || novo.test_path !== 'tests/novo.test.mjs') { console.error('nova entrada incorreta: ' + JSON.stringify(novo)); process.exit(1); }
if (d.test_path !== 'tests/legacy.test.mjs') { console.error('topo deveria projetar entries[0] (legado), projetou: ' + d.test_path); process.exit(1); }
" "$EV4" || { echo "FAIL [4]: legado não preservado corretamente"; exit 1; }
echo "OK [4]"

echo "[5] scaffold nunca gravado não deixa entrada fantasma"
FORGE_ROOT="$T" bash "$SN" bug-empty --type bugfix --scale 1 >/dev/null
EV5="$T/.forge/specs/active/bug-empty/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-empty --id First --test-path tests/f.test.mjs --test-id f-case --command "node --test tests/f.test.mjs" --fix-files src/f.sh --failure-pattern PF >/dev/null
node -e "
const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
if (d.entries.length !== 1 || d.entries[0].id !== 'First') { console.error('esperava só [First], achou ' + JSON.stringify(d.entries)); process.exit(1); }
" "$EV5" || { echo "FAIL [5]: entrada fantasma criada a partir do scaffold vazio"; exit 1; }
echo "OK [5]"

echo "[6] status do topo é derivado — observed só quando TODAS as entradas resolvem"
# unitário e direto sobre deriveTopStatus (uma única entrada aberta é insuficiente para
# 'observed' MESMO com outra observada; qualquer record que toque uma entrada força seu status
# de volta a 'pending' por desenho — 'record é declaração, não observação' — então testar via
# CLI mediria essa regra, não a derivação; deriveTopStatus é a fonte única de verdade da
# derivação e é exportada exatamente para ser testável desta forma).
node --input-type=module -e "
import { deriveTopStatus } from '$LIB/red-evidence-ops.mjs';
const cases = [
  [[], 'pending'],
  [[{ id: 'a', status: 'pending' }], 'pending'],
  [[{ id: 'a', status: 'observed' }], 'observed'],
  [[{ id: 'a', status: 'not-possible' }], 'not-possible'],
  [[{ id: 'a', status: 'observed' }, { id: 'b', status: 'pending' }], 'pending'],
  [[{ id: 'a', status: 'observed' }, { id: 'b', status: 'observed' }], 'observed'],
  [[{ id: 'a', status: 'observed' }, { id: 'b', status: 'waived' }], 'observed'],
  [[{ id: 'a', status: 'waived' }, { id: 'b', status: 'waived' }], 'waived'],
];
let fail = 0;
for (const [entries, expected] of cases) {
  const got = deriveTopStatus(entries);
  if (got !== expected) { console.error('FAIL [6]: deriveTopStatus(' + JSON.stringify(entries) + ') = ' + got + ', esperado ' + expected); fail = 1; }
}
process.exit(fail);
" || exit 1
echo "OK [6]"

echo "[7] schema/validador aceitam legado (sem entries) e formato novo (com entries)"
node --input-type=module -e "
import { validateRedEvidence } from '$LIB/red-evidence.mjs';
const legacy = { schema: 'red-evidence/v1', change_id: 'x', status: 'pending', fix_files: [] };
const errsLegacy = validateRedEvidence(legacy);
if (errsLegacy.length) { console.error('FAIL [7]: legado sem entries reprovado: ' + JSON.stringify(errsLegacy)); process.exit(1); }
const withEntries = { ...legacy, entries: [{ id: 'A', status: 'pending', fix_files: [] }, { id: null, status: 'observed', fix_files: ['x.js'] }] };
const errsNew = validateRedEvidence(withEntries);
if (errsNew.length) { console.error('FAIL [7]: entries válidas reprovadas: ' + JSON.stringify(errsNew)); process.exit(1); }
const bad = { ...legacy, entries: [{ id: 'A', status: 'not-a-status' }] };
const errsBad = validateRedEvidence(bad);
if (!errsBad.length) { console.error('FAIL [7]: entries[0].status inválido não foi pego'); process.exit(1); }
console.log('OK [7]');
" || exit 1

echo "[8] check-red-first status lê entries[] (informativo) sem mudar o veredito"
out8="$(FORGE_ROOT="$T" bash "$CR" status bug-multi 2>&1)"
grep -q "entrada(s) resolvida(s)" <<<"$out8" || { echo "FAIL [8]: status não menciona entradas resolvidas para change multi-entrada ($out8)"; exit 1; }
out8single="$(FORGE_ROOT="$T" bash "$CR" status bug-single 2>&1)"
grep -q "entrada(s) resolvida(s)" <<<"$out8single" && { echo "FAIL [8]: status de change com 1 entrada não deveria mencionar contagem ($out8single)"; exit 1; }
echo "OK [8]"

echo "[9] PBT — estados iniciais (vazio|legado) + sequências de record --id, seed 139, 80 casos"
node --input-type=module -e "
import { applyRecord, deriveTopStatus } from '$LIB/red-evidence-ops.mjs';
import { makeRandom } from '$LIB/pbt.mjs';

function randomFlags(rnd, tag) {
  return {
    'test-path': 'tests/' + tag + '.test.mjs',
    'test-id': 'case-' + tag,
    'command': 'node --test tests/' + tag + '.test.mjs',
    'failure-pattern': 'P' + tag + rnd.int(0, 999),
    'fix-files': 'src/' + tag + '.sh',
  };
}

function emptyState() {
  return { schema: 'red-evidence/v1', change_id: 'pbt', status: 'pending', test_path: null, test_id: null, command: null, failure_pattern: null, recorded_at: null, fix_files: [], waiver: null };
}
function legacyState() {
  return { schema: 'red-evidence/v1', change_id: 'pbt', status: 'observed', test_path: 'tests/legacy.test.mjs', test_id: 'legacy-case', command: 'node --test tests/legacy.test.mjs', failure_pattern: 'ASSERT', excerpt: 'boom', excerpt_sha256: null, recorded_at: '2020-01-01T00:00:00.000Z', replayed_at: '2020-01-01T00:00:01.000Z', fix_files: ['src/legacy.sh'], waiver: null };
}

const SEED = 139;
const RUNS = 80;
const rnd = makeRandom(SEED);
let failures = 0;

for (let run = 0; run < RUNS; run++) {
  const startLegacy = rnd.next() < 0.5;
  let data = startLegacy ? legacyState() : emptyState();
  const hadLegacy = startLegacy;
  const nOps = 1 + rnd.int(0, 4);
  const ids = ['id-a', 'id-b', 'id-c'];
  const seenLast = new Map(); // id -> last applied flags snapshot (failure-pattern is enough to distinguish)
  const order = [];
  for (let i = 0; i < nOps; i++) {
    const id = ids[rnd.int(0, ids.length - 1)];
    const flags = randomFlags(rnd, id);
    flags.id = id;
    let result;
    try { result = applyRecord(data, 'pbt', flags); }
    catch (e) { console.error('run ' + run + ': applyRecord lançou inesperadamente: ' + e.message); failures++; break; }
    data = result.data;
    seenLast.set(id, flags['failure-pattern']);
    order.push(id);
  }
  if (failures) break;

  // propriedade 1: cada id aparece exatamente uma vez em entries
  const idsInEntries = data.entries.filter((e) => e.id !== null).map((e) => e.id);
  const uniqueTouched = [...new Set(order)];
  for (const id of uniqueTouched) {
    const count = idsInEntries.filter((x) => x === id).length;
    if (count !== 1) { console.error('run ' + run + ': id ' + id + ' aparece ' + count + ' vez(es) em entries, esperado 1 (seed ' + SEED + ')'); failures++; }
  }

  // propriedade 2: a última declaração por id vence
  for (const [id, expectedPattern] of seenLast) {
    const entry = data.entries.find((e) => e.id === id);
    if (!entry || entry.failure_pattern !== expectedPattern) {
      console.error('run ' + run + ': última declaração de ' + id + ' não venceu — esperado ' + expectedPattern + ', achou ' + (entry && entry.failure_pattern) + ' (seed ' + SEED + ')');
      failures++;
    }
  }

  // propriedade 3: nenhum campo de um id aparece na entrada de outro (test_path é só do próprio id)
  for (const entry of data.entries) {
    if (entry.id === null) continue;
    if (entry.test_path && !entry.test_path.includes(entry.id)) {
      console.error('run ' + run + ': entrada ' + entry.id + ' tem test_path de outro id: ' + entry.test_path + ' (seed ' + SEED + ')');
      failures++;
    }
  }

  // propriedade 4: legado nunca perdido — se começou legado, entries[0] é o legado intacto
  if (hadLegacy) {
    const first = data.entries[0];
    if (first.id !== null || first.test_path !== 'tests/legacy.test.mjs' || first.excerpt !== 'boom') {
      console.error('run ' + run + ': legado perdido/reinterpretado — entries[0] = ' + JSON.stringify(first) + ' (seed ' + SEED + ')');
      failures++;
    }
  }

  // propriedade 5: topo == projeção de entries[0]
  const first0 = data.entries[0];
  if (data.test_path !== first0.test_path || data.failure_pattern !== first0.failure_pattern) {
    console.error('run ' + run + ': topo não é projeção de entries[0] (seed ' + SEED + ')');
    failures++;
  }
  if (data.status !== deriveTopStatus(data.entries)) {
    console.error('run ' + run + ': status do topo diverge de deriveTopStatus(entries) (seed ' + SEED + ')');
    failures++;
  }

  if (failures) break;
}

if (failures) { console.error('FAIL [9]: ' + failures + ' violação(ões) em ' + RUNS + ' casos (seed ' + SEED + ')'); process.exit(1); }
console.log('OK [9] — ' + RUNS + ' casos, seed ' + SEED + ', 0 violação');
" || exit 1

echo "[10] MUTAÇÃO — reverter entries[] para atribuição no topo faz [1] falhar; recontrole restaura"
OPS="$LIB/red-evidence-ops.mjs"
cp "$OPS" "$T/ops-backup.mjs"
# a mutação simula a causa raiz original: em vez de escrever em entries[], grava só no topo,
# perdendo qualquer entrada anterior (a linha `doc.entries = entries;` é a que fecha o furo).
perl -pi -e 's/doc\.entries = entries;/doc.entries = [entries[entries.length - 1]];/' "$OPS"
if cmp -s "$OPS" "$T/ops-backup.mjs"; then
  echo "FAIL [10]: mutação não alterou o arquivo (perl não casou o padrão)"; exit 1
fi
T10="$(mktemp -d /tmp/forge-w218-mut10.XXXXXX)"
mk_root "$T10"
FORGE_ROOT="$T10" bash "$T10/.forge/scripts/spec-new.sh" bug-mut --type bugfix --scale 1 >/dev/null
FORGE_ROOT="$T10" bash "$T10/.forge/scripts/red-evidence.sh" record bug-mut --id DefeitoA --test-path tests/a.test.mjs --test-id case-a --command "node --test tests/a.test.mjs" --fix-files src/a.sh --failure-pattern PA >/dev/null
FORGE_ROOT="$T10" bash "$T10/.forge/scripts/red-evidence.sh" record bug-mut --id DefeitoB --test-path tests/b.test.mjs --test-id case-b --command "node --test tests/b.test.mjs" --fix-files src/b.sh --failure-pattern PB >/dev/null
EV10="$T10/.forge/specs/active/bug-mut/evidence/red/red-evidence.json"
n10_mut="$(grep -c DefeitoA "$EV10" || true)"
rm -rf "$T10"
cp "$T/ops-backup.mjs" "$OPS"
if ! cmp -s "$OPS" "$T/ops-backup.mjs"; then echo "FAIL [10]: restauração não bateu byte a byte"; exit 1; fi
[ "$n10_mut" -eq 0 ] || { echo "FAIL [10-mut]: mutação deveria fazer o cenário [1] falhar (DefeitoA deveria sumir), mas achou $n10_mut ocorrência(s)"; exit 1; }
echo "OK [10-mut] — mutação faz o cenário [1] falhar como esperado"
# recontrole: com a lib restaurada, o cenário [1] volta a passar
T10R="$(mktemp -d /tmp/forge-w218-mut10r.XXXXXX)"
mk_root "$T10R"
FORGE_ROOT="$T10R" bash "$T10R/.forge/scripts/spec-new.sh" bug-mut --type bugfix --scale 1 >/dev/null
FORGE_ROOT="$T10R" bash "$T10R/.forge/scripts/red-evidence.sh" record bug-mut --id DefeitoA --test-path tests/a.test.mjs --test-id case-a --command "node --test tests/a.test.mjs" --fix-files src/a.sh --failure-pattern PA >/dev/null
FORGE_ROOT="$T10R" bash "$T10R/.forge/scripts/red-evidence.sh" record bug-mut --id DefeitoB --test-path tests/b.test.mjs --test-id case-b --command "node --test tests/b.test.mjs" --fix-files src/b.sh --failure-pattern PB >/dev/null
n10_recontrole="$(grep -c DefeitoA "$T10R/.forge/specs/active/bug-mut/evidence/red/red-evidence.json" || true)"
rm -rf "$T10R"
[ "$n10_recontrole" -ge 1 ] || { echo "FAIL [10-recontrole]: com a lib restaurada, DefeitoA deveria continuar presente"; exit 1; }
echo "OK [10-recontrole]"

echo "[11] MUTAÇÃO — remover a recusa sem --id faz o cenário [2] (quimera) sair rc 0; recontrole restaura"
cp "$WS/template/.forge/scripts/lib/red-evidence-ops.mjs" "$T/ops-backup2.mjs"
cmp -s "$OPS" "$T/ops-backup2.mjs" || { echo "FAIL [11]: pré-condição — lib deveria estar limpa antes desta mutação"; exit 1; }
perl -0pi -e "s/throw new Error\(\`--id é obrigatório[^\`]*\`\);/idx = entries.length - 1;/s" "$OPS"
if cmp -s "$OPS" "$T/ops-backup2.mjs"; then echo "FAIL [11]: mutação não alterou o arquivo (perl não casou o padrão)"; exit 1; fi
T11="$(mktemp -d /tmp/forge-w218-mut11.XXXXXX)"
mk_root "$T11"
FORGE_ROOT="$T11" bash "$T11/.forge/scripts/spec-new.sh" bug-mut2 --type bugfix --scale 1 >/dev/null
FORGE_ROOT="$T11" bash "$T11/.forge/scripts/red-evidence.sh" record bug-mut2 --id DefeitoA --test-path tests/a.test.mjs --test-id case-a --command "node --test tests/a.test.mjs" --fix-files src/a.sh --failure-pattern PA >/dev/null
FORGE_ROOT="$T11" bash "$T11/.forge/scripts/red-evidence.sh" record bug-mut2 --id DefeitoB --test-path tests/b.test.mjs --test-id case-b --command "node --test tests/b.test.mjs" --fix-files src/b.sh --failure-pattern PB >/dev/null
set +e
out11="$(FORGE_ROOT="$T11" bash "$T11/.forge/scripts/red-evidence.sh" record bug-mut2 --failure-pattern PC 2>&1)"; rc11=$?
set -e
rm -rf "$T11"
cp "$T/ops-backup2.mjs" "$OPS"
if ! cmp -s "$OPS" "$WS/template/.forge/scripts/lib/red-evidence-ops.mjs"; then echo "FAIL [11]: restauração não bateu byte a byte com o arquivo original do worktree"; exit 1; fi
[ "$rc11" -eq 0 ] || { echo "FAIL [11-mut]: mutação deveria aceitar o record ambíguo (rc 0), saiu rc=$rc11 ($out11)"; exit 1; }
echo "OK [11-mut] — mutação aceita a quimera como esperado"
T11R="$(mktemp -d /tmp/forge-w218-mut11r.XXXXXX)"
mk_root "$T11R"
FORGE_ROOT="$T11R" bash "$T11R/.forge/scripts/spec-new.sh" bug-mut2 --type bugfix --scale 1 >/dev/null
FORGE_ROOT="$T11R" bash "$T11R/.forge/scripts/red-evidence.sh" record bug-mut2 --id DefeitoA --test-path tests/a.test.mjs --test-id case-a --command "node --test tests/a.test.mjs" --fix-files src/a.sh --failure-pattern PA >/dev/null
FORGE_ROOT="$T11R" bash "$T11R/.forge/scripts/red-evidence.sh" record bug-mut2 --id DefeitoB --test-path tests/b.test.mjs --test-id case-b --command "node --test tests/b.test.mjs" --fix-files src/b.sh --failure-pattern PB >/dev/null
set +e
out11r="$(FORGE_ROOT="$T11R" bash "$T11R/.forge/scripts/red-evidence.sh" record bug-mut2 --failure-pattern PC 2>&1)"; rc11r=$?
set -e
rm -rf "$T11R"
[ "$rc11r" -ne 0 ] || { echo "FAIL [11-recontrole]: com a lib restaurada, o record ambíguo deveria voltar a ser recusado ($out11r)"; exit 1; }
echo "OK [11-recontrole]"

echo "OK"
