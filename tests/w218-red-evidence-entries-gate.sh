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
#
# Achados da revisão adversarial (correção da #139), cobertos a partir daqui:
#  [10] LOW — legado real ESCRITO À MÃO (w106/w144), sem `recorded_at` e com `status:pending`
#       (nunca passou pelo `record` da CLI), mas com campos escalares preenchidos, continua
#       classificado como legado real (não como scaffold) e é preservado em `entries[0]`
#  [11] MEDIUM — `record --id` sem valor utilizável (`--id` como último token, ou seguido de
#       outra flag) é recusado, em vez de degradar em silêncio para o caminho sem `--id` e
#       sobrescrever a entrada errada (a própria quimera que a recusa de [2] existe para evitar)
#  [12] MEDIUM — o validador rejeita `entries[].id` vazio (`""`) e ids duplicados
#  [13] HIGH — `replay` (via `persistReplayResult`) escreve o veredito na ENTRADA (não só no
#       topo): um `record --id B` posterior preserva status/base_commit/classification/excerpt
#       da entrada já observada por outro `record`+`replay` anterior
#  [14] HIGH — `check-red-first.mjs waive` escreve o waiver na ENTRADA (não só no topo): um
#       `record --id B` posterior preserva o waiver da entrada já dispensada
#  [15] HIGH — com 2+ entradas registradas, `replay`/`ensure`/`waive` RECUSAM operar (fail-closed
#       — nenhum dos três tem `--id` hoje, então não há como saber qual entrada resolvem) em vez
#       de escrever no topo e deixar o próximo `record` apagar o resultado em silêncio; o arquivo
#       fica byte-a-byte intacto nos três casos
#  [16] PROPRIEDADE PBT — para sequências geradas intercalando `record --id <k>` com uma
#       observação (`replay` simulado) ou uma dispensa (`waive` simulado) sobre a entrada única
#       corrente, nenhuma entrada já observada/dispensada é revertida para pending por um
#       `record` posterior em OUTRO id
#  [17] MUTAÇÃO (sandbox) — trocar a escrita em entries[] pela atribuição no topo faz [1] falhar
#  [18] MUTAÇÃO (sandbox) — remover a recusa sem --id faz [2] (quimera) sair rc 0
#  [19] MUTAÇÃO (sandbox) — voltar a escrita do replay para só o topo (ignorando
#       `upsertSingleEntry`) faz [13] falhar
#
# Achado MEDIUM da correção: as mutações [17]-[19] rodam inteiramente dentro de uma árvore
# SANDBOX (`mk_root` num `mktemp -d` novo) — nunca sobre `template/.forge/scripts/lib/*.mjs` do
# worktree real. `red-evidence.sh` resolve sua própria lib por `SCRIPT_DIR` (a pasta do próprio
# script invocado, não uma constante), então mutar a cópia dentro do sandbox e invocar os
# scripts DAQUELE sandbox exercita a mutação sem jamais tocar o arquivo rastreado do
# repositório — elimina o risco (sob `set -euo pipefail`) de uma falha entre mutação e restore
# deixar a árvore real mutada. Cada mutação ainda restaura byte a byte (`cmp -s`) dentro do
# próprio sandbox antes do recontrole, para que a evidência prevista pelo protocolo (controle +
# recontrole por `cmp -s`) continue presente mesmo sem tocar a árvore real.
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

echo "[10] legado real escrito à mão (sem recorded_at, status pending) preservado como entries[0]"
FORGE_ROOT="$T" bash "$SN" bug-legacy-handwritten --type bugfix --scale 1 >/dev/null
DIR10="$T/.forge/specs/active/bug-legacy-handwritten"
EV10L="$DIR10/evidence/red/red-evidence.json"
node -e '
const fs = require("fs");
const p = process.argv[1];
const d = JSON.parse(fs.readFileSync(p, "utf8"));
// w106/w144 style: campos escalares preenchidos, mas NUNCA passou por record() da CLI —
// recorded_at continua null e status continua pending (o próprio predicado que a correção
// da #139 amplia: recorded_at/status sozinhos não bastam para reconhecer legado real).
d.test_path = "tests/handwritten.test.mjs"; d.test_id = "handwritten-case";
d.command = "node --test tests/handwritten.test.mjs"; d.failure_pattern = "AssertionError";
d.fix_files = ["src/handwritten.sh"];
fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
' "$EV10L"
FORGE_ROOT="$T" bash "$RE" record bug-legacy-handwritten --id NovoDefeito10 --test-path tests/novo10.test.mjs --test-id novo10-case --command "node --test tests/novo10.test.mjs" --fix-files src/novo10.sh --failure-pattern PN10 >/dev/null
node -e "
const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
if (d.entries.length !== 2) { console.error('esperava 2 entradas (legado preservado + nova), achou ' + d.entries.length + ': ' + JSON.stringify(d.entries)); process.exit(1); }
const legacy = d.entries[0];
if (legacy.test_path !== 'tests/handwritten.test.mjs' || legacy.command !== 'node --test tests/handwritten.test.mjs') {
  console.error('legado escrito à mão não preservado: ' + JSON.stringify(legacy)); process.exit(1);
}
" "$EV10L" || { echo "FAIL [10]: legado real (sem recorded_at/status) tratado como scaffold vazio"; exit 1; }
echo "OK [10]"

echo "[11] record --id sem valor utilizável é recusado (não degrada em silêncio)"
FORGE_ROOT="$T" bash "$SN" bug-id-guard --type bugfix --scale 1 >/dev/null
EV11="$T/.forge/specs/active/bug-id-guard/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-id-guard --id Base --test-path tests/base.test.mjs --test-id case-base --command "node --test tests/base.test.mjs" --fix-files src/base.sh --failure-pattern PBASE >/dev/null
cp "$EV11" "$T/ev11-antes.json"
# 11a — --id como ÚLTIMO token (sem valor)
set +e
out11a="$(FORGE_ROOT="$T" bash "$RE" record bug-id-guard --test-path tests/x.test.mjs --id 2>&1)"; rc11a=$?
set -e
[ "$rc11a" -ne 0 ] || { echo "FAIL [11a]: --id sem valor (último token) foi aceito ($out11a)"; exit 1; }
cmp -s "$EV11" "$T/ev11-antes.json" || { echo "FAIL [11a]: arquivo foi tocado apesar da recusa"; exit 1; }
# 11b — --id seguido de OUTRA flag (valor engolido é "--test-path")
set +e
out11b="$(FORGE_ROOT="$T" bash "$RE" record bug-id-guard --id --test-path tests/x.test.mjs 2>&1)"; rc11b=$?
set -e
[ "$rc11b" -ne 0 ] || { echo "FAIL [11b]: --id seguido de outra flag foi aceito ($out11b)"; exit 1; }
cmp -s "$EV11" "$T/ev11-antes.json" || { echo "FAIL [11b]: arquivo foi tocado apesar da recusa"; exit 1; }
# 11c — --id "" (string vazia)
set +e
out11c="$(FORGE_ROOT="$T" bash "$RE" record bug-id-guard --id "" --test-path tests/x.test.mjs --test-id x --command "node --test tests/x.test.mjs" --fix-files src/x.sh --failure-pattern PX 2>&1)"; rc11c=$?
set -e
[ "$rc11c" -ne 0 ] || { echo "FAIL [11c]: --id vazio foi aceito ($out11c)"; exit 1; }
cmp -s "$EV11" "$T/ev11-antes.json" || { echo "FAIL [11c]: arquivo foi tocado apesar da recusa"; exit 1; }
echo "OK [11]"

echo "[12] validador rejeita entries[].id vazio e ids duplicados"
node --input-type=module -e "
import { validateRedEvidence } from '$LIB/red-evidence.mjs';
const base = { schema: 'red-evidence/v1', change_id: 'x', status: 'pending', fix_files: [] };
const emptyId = { ...base, entries: [{ id: '', status: 'pending', fix_files: [] }] };
if (!validateRedEvidence(emptyId).length) { console.error('FAIL [12]: id vazio não foi pego'); process.exit(1); }
const dup = { ...base, entries: [{ id: 'A', status: 'pending', fix_files: [] }, { id: 'A', status: 'observed', fix_files: [] }] };
const errsDup = validateRedEvidence(dup);
if (!errsDup.length || !errsDup.some((e) => e.includes('duplicated'))) { console.error('FAIL [12]: id duplicado não foi pego (' + JSON.stringify(errsDup) + ')'); process.exit(1); }
const okDistinctNulls = { ...base, entries: [{ id: null, status: 'pending', fix_files: [] }, { id: null, status: 'observed', fix_files: [] }] };
if (validateRedEvidence(okDistinctNulls).length) { console.error('FAIL [12]: dois ids null (legado singular, nunca deveria coexistir com outra entrada, mas a regra de duplicidade não é sobre null) foram indevidamente reprovados'); process.exit(1); }
console.log('OK [12]');
" || exit 1

echo "[13] replay preserva a entrada observada quando um record --id B chega depois (HIGH-1a)"
mkdir -p "$T/src13" "$T/tests13"
cat > "$T/src13/sum.mjs" <<'JS'
export function sum(a, b) { return a - b; }
JS
git -C "$T" add src13/sum.mjs
git -C "$T" commit -qm "feat: sum13 (com bug)" >/dev/null
cat > "$T/tests13/sum.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sum } from '../src13/sum.mjs';
test('case13', () => { assert.strictEqual(sum(2, 3), 5); });
JS
git -C "$T" add tests13/sum.test.mjs
git -C "$T" commit -qm "test: regressão bug-replay-preserve" >/dev/null
cat > "$T/src13/sum.mjs" <<'JS'
export function sum(a, b) { return a + b; }
JS
git -C "$T" add src13/sum.mjs
git -C "$T" commit -qm "fix: bug-replay-preserve" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-replay-preserve --type bugfix --scale 1 >/dev/null
DIR13="$T/.forge/specs/active/bug-replay-preserve"
EV13="$DIR13/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-replay-preserve --test-path tests13/sum.test.mjs --test-id case13 --command "node --test tests13/sum.test.mjs" --fix-files src13/sum.mjs --failure-pattern AssertionError >/dev/null
out13="$(FORGE_ROOT="$T" bash "$RE" replay bug-replay-preserve 2>&1)"; rc13=$?
[ "$rc13" -eq 0 ] || { echo "FAIL [13]: replay deveria observar ($out13)"; exit 1; }
grep -qi observado <<<"$out13" || { echo "FAIL [13]: replay não confirmou observação ($out13)"; exit 1; }
node -e "
const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
if (d.entries.length !== 1 || d.entries[0].status !== 'observed' || !d.entries[0].base_commit) { console.error('FAIL [13]: replay não gravou observed na entrada — ' + JSON.stringify(d.entries)); process.exit(1); }
" "$EV13" || exit 1
# agora um SEGUNDO defeito é declarado no mesmo change — a entrada já observada não pode regredir
FORGE_ROOT="$T" bash "$RE" record bug-replay-preserve --id DefeitoB13 --test-path tests/b13.test.mjs --test-id case-b13 --command "node --test tests/b13.test.mjs" --fix-files src/b13.sh --failure-pattern PB13 >/dev/null
node -e "
const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
if (d.entries.length !== 2) { console.error('FAIL [13]: esperava 2 entradas depois do record --id B, achou ' + d.entries.length); process.exit(1); }
const first = d.entries[0];
if (first.status !== 'observed' || !first.base_commit || first.classification !== 'behavioral') {
  console.error('FAIL [13]: entrada já observada regrediu depois do record --id B — ' + JSON.stringify(first)); process.exit(1);
}
const second = d.entries[1];
if (second.id !== 'DefeitoB13' || second.status !== 'pending') { console.error('FAIL [13]: segunda entrada incorreta — ' + JSON.stringify(second)); process.exit(1); }
if (d.status !== 'pending') { console.error('FAIL [13]: topo deveria ser pending (DefeitoB13 ainda não resolvido), achou ' + d.status); process.exit(1); }
" "$EV13" || exit 1
echo "OK [13]"

echo "[14] waive preserva a entrada dispensada quando um record --id B chega depois (HIGH-1b)"
FORGE_ROOT="$T" bash "$SN" bug-waive-preserve --type bugfix --scale 1 >/dev/null
DIR14="$T/.forge/specs/active/bug-waive-preserve"
EV14="$DIR14/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-waive-preserve --test-path tests/w14.test.mjs --test-id case-w14 --command "node --test tests/w14.test.mjs" --fix-files src/w14.sh --failure-pattern PW14 >/dev/null
out14="$(FORGE_ROOT="$T" bash "$CR" waive bug-waive-preserve --reason no-test-infra --note "sem suíte utilizável (w218 [14])" 2>&1)"; rc14=$?
[ "$rc14" -eq 0 ] || { echo "FAIL [14]: waive deveria ter sido aceito ($out14)"; exit 1; }
grep -q "OK waive" <<<"$out14" || { echo "FAIL [14]: saída inesperada do waive ($out14)"; exit 1; }
node -e "
const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
if (d.entries.length !== 1 || d.entries[0].status !== 'waived' || !d.entries[0].waiver || d.entries[0].waiver.reason !== 'no-test-infra') {
  console.error('FAIL [14]: waive não gravou o waiver na entrada — ' + JSON.stringify(d.entries)); process.exit(1);
}
" "$EV14" || exit 1
FORGE_ROOT="$T" bash "$RE" record bug-waive-preserve --id DefeitoB14 --test-path tests/b14.test.mjs --test-id case-b14 --command "node --test tests/b14.test.mjs" --fix-files src/b14.sh --failure-pattern PB14 >/dev/null
node -e "
const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
if (d.entries.length !== 2) { console.error('FAIL [14]: esperava 2 entradas depois do record --id B, achou ' + d.entries.length); process.exit(1); }
const first = d.entries[0];
if (first.status !== 'waived' || !first.waiver || first.waiver.reason !== 'no-test-infra') {
  console.error('FAIL [14]: waiver perdido depois do record --id B — ' + JSON.stringify(first)); process.exit(1);
}
const second = d.entries[1];
if (second.id !== 'DefeitoB14' || second.status !== 'pending') { console.error('FAIL [14]: segunda entrada incorreta — ' + JSON.stringify(second)); process.exit(1); }
if (d.status !== 'pending') { console.error('FAIL [14]: topo deveria ser pending (DefeitoB14 ainda não resolvido), achou ' + d.status); process.exit(1); }
" "$EV14" || exit 1
echo "OK [14]"

echo "[15] replay/waive SEM --id recusam (fail-closed) com 2+ entradas; ensure ITERA (achado HIGH-2, iteração 3)"
cp "$EV1" "$T/ev1-antes-15.json"
set +e
out15r="$(FORGE_ROOT="$T" bash "$RE" replay bug-multi 2>&1)"; rc15r=$?
set -e
[ "$rc15r" -ne 0 ] || { echo "FAIL [15-replay]: replay sem --id com 2 entradas deveria recusar ($out15r)"; exit 1; }
grep -qi "recusado" <<<"$out15r" || { echo "FAIL [15-replay]: mensagem não indica recusa ($out15r)"; exit 1; }
grep -qi -- "--id" <<<"$out15r" || { echo "FAIL [15-replay]: mensagem não cita --id ($out15r)"; exit 1; }
cmp -s "$EV1" "$T/ev1-antes-15.json" || { echo "FAIL [15-replay]: arquivo foi tocado apesar da recusa"; exit 1; }

# achado HIGH-2 da correção (iteração 3): ensure é chamado INCONDICIONALMENTE por
# /forge:verify e /forge:archive, sem --id algum (nenhum chamador sabe quais ids existem) — por
# isso ensure não recusa mais com 2+ entradas: ITERA cada uma não dispensada e roda o motor de
# replay sobre ela. bug-multi declara test_path que não existem em HEAD (a.test.mjs/b.test.mjs
# nunca foram criados), então o motor retorna 'fail' (ou diagnóstico) para as duas — ensure
# continua saindo rc 0 (contrato: nunca falha por veredito desfavorável) e o arquivo É TOCADO
# (replayed_at/diagnóstico gravados por entrada), ao contrário do comportamento anterior
# (recusa total, arquivo intacto).
out15e="$(FORGE_ROOT="$T" bash "$RE" ensure bug-multi 2>&1)"; rc15e=$?
[ "$rc15e" -eq 0 ] || { echo "FAIL [15-ensure]: ensure nunca deveria sair rc≠0 (contrato — ver comentário de cmdEnsure) ($out15e)"; exit 1; }
grep -q "2 entrada(s) replayada(s)" <<<"$out15e" || { echo "FAIL [15-ensure]: esperava iterar as 2 entradas (achado HIGH-2) ($out15e)"; exit 1; }
node -e "
const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
if (d.entries.length !== 2) { console.error('esperava continuar com 2 entradas, achou ' + d.entries.length); process.exit(1); }
if (d.entries[0].id !== 'DefeitoA' || d.entries[1].id !== 'DefeitoB') { console.error('ids trocaram de ordem ou se perderam: ' + JSON.stringify(d.entries.map((e) => e.id))); process.exit(1); }
if (d.status !== 'pending') { console.error('topo deveria continuar pending (testes declarados não existem em HEAD — replay falha, nunca observa às cegas), achou ' + d.status); process.exit(1); }
if (!d.entries[0].replayed_at || !d.entries[1].replayed_at) { console.error('ensure deveria ter tentado replay nas DUAS entradas (replayed_at ausente)'); process.exit(1); }
" "$EV1" || { echo "FAIL [15-ensure]: pós-condição de iteração violada"; exit 1; }
echo "OK [15-ensure] — ensure iterou as 2 entradas sem recusar, nenhuma resolvida (testes declarados ausentes), topo continua pending"

cp "$EV1" "$T/ev1-antes-15w.json"
DEF_MULTI="$T/.forge/specs/active/bug-multi/deferrals.json"
[ -f "$DEF_MULTI" ] && { echo "FAIL [15-waive]: pré-condição — deferrals.json não deveria existir ainda"; exit 1; }
set +e
out15w="$(FORGE_ROOT="$T" bash "$CR" waive bug-multi --reason no-test-infra --note "x" 2>&1)"; rc15w=$?
set -e
[ "$rc15w" -ne 0 ] || { echo "FAIL [15-waive]: waive sem --id com 2 entradas deveria recusar ($out15w)"; exit 1; }
grep -qi "recusado" <<<"$out15w" || { echo "FAIL [15-waive]: mensagem não indica recusa ($out15w)"; exit 1; }
grep -qi -- "--id" <<<"$out15w" || { echo "FAIL [15-waive]: mensagem não cita --id ($out15w)"; exit 1; }
cmp -s "$EV1" "$T/ev1-antes-15w.json" || { echo "FAIL [15-waive]: arquivo foi tocado apesar da recusa"; exit 1; }
[ -f "$DEF_MULTI" ] && { echo "FAIL [15-waive]: recusa deveria ter acontecido ANTES de criar deferral (efeito colateral órfão)"; exit 1; }
echo "OK [15]"

echo "[16] PBT — record/observe/waive intercalados nunca revertem uma entrada já resolvida (seed 139, 80 casos)"
node --input-type=module -e "
import { applyRecord, upsertSingleEntry, deriveTopStatus } from '$LIB/red-evidence-ops.mjs';
import { makeRandom } from '$LIB/pbt.mjs';

function emptyState() {
  return { schema: 'red-evidence/v1', change_id: 'pbt16', status: 'pending', test_path: null, test_id: null, command: null, failure_pattern: null, recorded_at: null, fix_files: [], waiver: null };
}

const SEED = 139;
const RUNS = 80;
const rnd = makeRandom(SEED);
let failures = 0;

for (let run = 0; run < RUNS; run++) {
  let data = emptyState();
  const ids = ['id-a', 'id-b', 'id-c'];
  const resolved = new Map(); // id -> { status, marker } de entradas já observadas/dispensadas
  const nOps = 2 + rnd.int(0, 6);

  for (let i = 0; i < nOps; i++) {
    const kind = rnd.next();
    if (kind < 0.6) {
      // record --id <k> — declaração nova ou atualização
      const id = ids[rnd.int(0, ids.length - 1)];
      const marker = 'M' + rnd.int(0, 999999);
      try {
        const result = applyRecord(data, 'pbt16', { id, 'test-path': 'tests/' + id + '.test.mjs', 'test-id': 'case-' + id, command: 'node --test tests/' + id + '.test.mjs', 'failure-pattern': marker, 'fix-files': 'src/' + id + '.sh' });
        data = result.data;
      } catch (e) { console.error('run ' + run + ': applyRecord lançou: ' + e.message); failures++; break; }
      // record SEMPRE reabre a entrada tocada para pending — some do conjunto de resolvidas.
      resolved.delete(id);
    } else {
      // observe/waive simulado sobre a entrada única corrente (upsertSingleEntry) — só possível
      // com 0 ou 1 entrada; com 2+, a operação é ambígua e a PROPRIEDADE é 'refused:true'.
      const status = kind < 0.8 ? 'observed' : 'waived';
      const patch = { status, marker: 'R' + rnd.int(0, 999999) };
      const upsert = upsertSingleEntry(data, 'pbt16', (entry) => ({ ...entry, ...patch }));
      if (Array.isArray(data.entries) && data.entries.length >= 2) {
        if (!upsert.refused) { console.error('run ' + run + ': upsertSingleEntry deveria recusar com 2+ entradas (seed ' + SEED + ')'); failures++; break; }
      } else if (!upsert.refused) {
        // upsert.legacy (data.entries ainda não é array — nunca passou por um record) é o
        // MESMO caminho que persistReplayResult/cmdWaive usam em produção: mescla no topo sem
        // introduzir entries[]; upsert.data só existe quando !legacy.
        data = upsert.legacy ? { ...data, ...patch } : upsert.data;
        // com 0/1 entrada ANTES do patch (não depois — 'legacy' pode não ter criado entries[]
        // ainda), só rastreamos por id quando o resultado já tem exatamente 1 entrada.
        if (Array.isArray(data.entries) && data.entries.length === 1) resolved.set(data.entries[0].id, { status, marker: patch.marker });
      }
    }
    if (failures) break;
  }
  if (failures) break;

  // propriedade: toda entrada marcada como resolvida (observed/waived) por um patch ainda
  // carrega esse status e aquele marker específico — um record em OUTRO id nunca a reverte.
  for (const [id, expected] of resolved) {
    const entry = data.entries.find((e) => e.id === id);
    if (!entry || entry.status !== expected.status || entry.marker !== expected.marker) {
      console.error('run ' + run + ': entrada ' + id + ' deveria continuar ' + expected.status + ' com marker ' + expected.marker + ', achou ' + JSON.stringify(entry) + ' (seed ' + SEED + ')');
      failures++;
    }
  }
  // data.entries pode continuar undefined se a sequência nunca chamou record() (só
  // observe/waive sobre estado legado, que nunca introduz entries[] — mesmo caminho de
  // persistReplayResult/cmdWaive em produção); deriveTopStatus só se aplica quando entries[]
  // existe.
  if (Array.isArray(data.entries) && data.status !== deriveTopStatus(data.entries)) {
    console.error('run ' + run + ': status do topo diverge de deriveTopStatus(entries) (seed ' + SEED + ')');
    failures++;
  }
  if (failures) break;
}

if (failures) { console.error('FAIL [16]: ' + failures + ' violação(ões) em ' + RUNS + ' casos (seed ' + SEED + ')'); process.exit(1); }
console.log('OK [16] — ' + RUNS + ' casos, seed ' + SEED + ', 0 violação');
" || exit 1

# ── mutações (achado MEDIUM — rodam num sandbox descartável, nunca sobre a árvore real) ────────

scenario_multi_preserved() { # scenario_multi_preserved <root> <suffix>
  local root="$1" suffix="$2"
  local id="bug-mut$suffix"
  FORGE_ROOT="$root" bash "$root/.forge/scripts/spec-new.sh" "$id" --type bugfix --scale 1 >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --id DefeitoA --test-path tests/a.test.mjs --test-id case-a --command "node --test tests/a.test.mjs" --fix-files src/a.sh --failure-pattern PA >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --id DefeitoB --test-path tests/b.test.mjs --test-id case-b --command "node --test tests/b.test.mjs" --fix-files src/b.sh --failure-pattern PB >/dev/null 2>&1 || return 1
  local n
  n="$(grep -c DefeitoA "$root/.forge/specs/active/$id/evidence/red/red-evidence.json" 2>/dev/null || true)"
  [ "${n:-0}" -ge 1 ]
}

scenario_chimera_refused() { # scenario_chimera_refused <root> <suffix>
  local root="$1" suffix="$2"
  local id="bug-chi$suffix" rc
  FORGE_ROOT="$root" bash "$root/.forge/scripts/spec-new.sh" "$id" --type bugfix --scale 1 >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --id DefeitoA --test-path tests/a.test.mjs --test-id case-a --command "node --test tests/a.test.mjs" --fix-files src/a.sh --failure-pattern PA >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --id DefeitoB --test-path tests/b.test.mjs --test-id case-b --command "node --test tests/b.test.mjs" --fix-files src/b.sh --failure-pattern PB >/dev/null 2>&1 || return 1
  set +e
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --failure-pattern PC >/dev/null 2>&1
  rc=$?
  set -e
  [ "$rc" -ne 0 ]
}

scenario_replay_preserved() { # scenario_replay_preserved <root> <suffix>
  local root="$1" suffix="$2"
  local id="bug-rep$suffix" out rc
  mkdir -p "$root/src$suffix" "$root/tests$suffix"
  cat > "$root/src$suffix/sum.mjs" <<JS
export function sum(a, b) { return a - b; }
JS
  git -C "$root" add "src$suffix/sum.mjs"
  git -C "$root" commit -qm "feat: sum$suffix (com bug)" >/dev/null
  cat > "$root/tests$suffix/sum.test.mjs" <<JS
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sum } from '../src$suffix/sum.mjs';
test('case$suffix', () => { assert.strictEqual(sum(2, 3), 5); });
JS
  git -C "$root" add "tests$suffix/sum.test.mjs"
  git -C "$root" commit -qm "test: regressão $id" >/dev/null
  cat > "$root/src$suffix/sum.mjs" <<JS
export function sum(a, b) { return a + b; }
JS
  git -C "$root" add "src$suffix/sum.mjs"
  git -C "$root" commit -qm "fix: $id" >/dev/null

  FORGE_ROOT="$root" bash "$root/.forge/scripts/spec-new.sh" "$id" --type bugfix --scale 1 >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --test-path "tests$suffix/sum.test.mjs" --test-id "case$suffix" --command "node --test tests$suffix/sum.test.mjs" --fix-files "src$suffix/sum.mjs" --failure-pattern AssertionError >/dev/null 2>&1 || return 1
  set +e
  out="$(FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" replay "$id" 2>&1)"; rc=$?
  set -e
  [ "$rc" -eq 0 ] || return 1
  grep -qi observado <<<"$out" || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --id "DefeitoB$suffix" --test-path "tests/b$suffix.test.mjs" --test-id "case-b$suffix" --command "node --test tests/b$suffix.test.mjs" --fix-files "src/b$suffix.sh" --failure-pattern "PB$suffix" >/dev/null 2>&1 || return 1
  node -e "
const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
if (d.entries.length !== 2) process.exit(1);
const first = d.entries[0];
if (first.status !== 'observed' || !first.base_commit || first.classification !== 'behavioral') process.exit(1);
process.exit(0);
" "$root/.forge/specs/active/$id/evidence/red/red-evidence.json"
}

run_mutation() { # run_mutation <label> <perl-script> <scenario-fn>
  local label="$1" perl_expr="$2" scenario_fn="$3"
  local MT; MT="$(mktemp -d /tmp/forge-w218-mut.XXXXXX)"
  mk_root "$MT"
  local OPSM="$MT/.forge/scripts/lib/red-evidence-ops.mjs"
  cp "$OPSM" "$MT/ops-pristine.mjs"
  perl -0pi -e "$perl_expr" "$OPSM"
  if cmp -s "$OPSM" "$MT/ops-pristine.mjs"; then
    rm -rf "$MT"
    echo "FAIL [$label]: mutação não alterou o arquivo (perl não casou o padrão)"; exit 1
  fi

  if "$scenario_fn" "$MT" "-a"; then
    rm -rf "$MT"
    echo "FAIL [$label-mut]: cenário deveria falhar com a mutação, mas passou"; exit 1
  fi
  echo "OK [$label-mut] — mutação faz o cenário falhar como esperado"

  cp "$MT/ops-pristine.mjs" "$OPSM"
  cmp -s "$OPSM" "$MT/ops-pristine.mjs" || { rm -rf "$MT"; echo "FAIL [$label]: restauração (sandbox) não bateu byte a byte"; exit 1; }

  if ! "$scenario_fn" "$MT" "-b"; then
    rm -rf "$MT"
    echo "FAIL [$label-recontrole]: com a lib restaurada, o cenário deveria voltar a passar"; exit 1
  fi
  echo "OK [$label-recontrole]"
  rm -rf "$MT"
}

echo "[17] MUTAÇÃO (sandbox) — trocar entries[] pela atribuição no topo faz [1] falhar"
run_mutation "17" 's/doc\.entries = entries;/doc.entries = [entries[entries.length - 1]];/' scenario_multi_preserved

echo "[18] MUTAÇÃO (sandbox) — remover a recusa sem --id faz [2] (quimera) sair rc 0"
run_mutation "18" 's/throw new Error\(`--id é obrigatório[^`]*`\);/idx = entries.length - 1;/s' scenario_chimera_refused

echo "[19] MUTAÇÃO (sandbox) — voltar a escrita do replay para só o topo faz [13] falhar"
run_mutation "19" 's/const upsert = upsertSingleEntry\(data, data\.change_id, \(entry\) => \(\{ \.\.\.entry, \.\.\.patch \}\), opts\);\n  if \(upsert\.refused\) return \{ refused: true, count: upsert\.count, reason: upsert\.reason \};\n  const updated = upsert\.legacy \? \{ \.\.\.data, \.\.\.patch \} : upsert\.data;/const updated = { ...data, ...patch };/s' scenario_replay_preserved

# ── achados da correção da #139, iteração 3 (revisão adversarial sobre a iteração 2) ───────────
#
#  [20] HIGH-2 — `replay --id`/`waive --id` resolvem entradas INDIVIDUAIS de um change com 2+
#       registradas: check-red-first sai de CONFLICT (bloqueado) para OK depois das duas
#       resolvidas por id — sem isso, um change com 2+ defeitos nunca chegava a verified/archived
#  [21] contrafactual — `replay --id`/`waive --id` com um id INEXISTENTE recusam, arquivo intacto
#  [22] MEDIUM — `record --rename-null <id>` nomeia a entrada sem id (única) — positiva e dois
#       contrafactuais (recusa com 2+ entradas; recusa quando a única entrada já tem id)
#  [23] LOW — `record` sem --id com 2+ entradas é recusado mesmo quando TODOS os campos
#       obrigatórios estão presentes — isola a recusa fail-closed da checagem de campos
#       obrigatórios (achado da revisão: [2] sozinho não distinguia as duas causas)
#  [24] MUTAÇÃO (sandbox) — ignorar `--id` em `resolveTargetEntry` (usado por `replay`) faz o
#       cenário de endereçamento por id de [20] falhar

echo "[20] replay --id / waive --id resolvem entradas individuais (HIGH-2); check sai de CONFLICT para OK"
mkdir -p "$T/src20" "$T/tests20"
cat > "$T/src20/mul.mjs" <<'JS'
export function mul(a, b) { return a + b; }
JS
git -C "$T" add src20/mul.mjs
git -C "$T" commit -qm "feat: mul20 (com bug)" >/dev/null
cat > "$T/tests20/mul.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mul } from '../src20/mul.mjs';
test('case20a', () => { assert.strictEqual(mul(3, 4), 12); });
JS
git -C "$T" add tests20/mul.test.mjs
git -C "$T" commit -qm "test: regressão bug-two-real DefeitoA20" >/dev/null
cat > "$T/src20/mul.mjs" <<'JS'
export function mul(a, b) { return a * b; }
JS
git -C "$T" add src20/mul.mjs
git -C "$T" commit -qm "fix: bug-two-real DefeitoA20" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-two-real --type bugfix --scale 1 >/dev/null
DIR20="$T/.forge/specs/active/bug-two-real"
EV20="$DIR20/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-two-real --id DefeitoA20 --test-path tests20/mul.test.mjs --test-id case20a --command "node --test tests20/mul.test.mjs" --fix-files src20/mul.mjs --failure-pattern AssertionError >/dev/null
FORGE_ROOT="$T" bash "$RE" record bug-two-real --id DefeitoB20 --test-path tests/b20.test.mjs --test-id case-b20 --command "node --test tests/b20.test.mjs" --fix-files src/b20.sh --failure-pattern PB20 >/dev/null

set +e
out20pre="$(FORGE_ROOT="$T" bash "$CR" check bug-two-real 2>&1)"; rc20pre=$?
set -e
[ "$rc20pre" -ne 0 ] || { echo "FAIL [20]: pré-condição — check deveria bloquear com 2 entradas pendentes ($out20pre)"; exit 1; }
grep -q "CONFLICT" <<<"$out20pre" || { echo "FAIL [20]: pré-condição — esperava CONFLICT ($out20pre)"; exit 1; }

out20r="$(FORGE_ROOT="$T" bash "$RE" replay bug-two-real --id DefeitoA20 2>&1)"; rc20r=$?
[ "$rc20r" -eq 0 ] || { echo "FAIL [20]: replay --id DefeitoA20 deveria observar ($out20r)"; exit 1; }
grep -qi observado <<<"$out20r" || { echo "FAIL [20]: replay --id não confirmou observação ($out20r)"; exit 1; }

out20w="$(FORGE_ROOT="$T" bash "$CR" waive bug-two-real --id DefeitoB20 --reason no-test-infra --note "w218 [20]" 2>&1)"; rc20w=$?
[ "$rc20w" -eq 0 ] || { echo "FAIL [20]: waive --id DefeitoB20 deveria ter sido aceito ($out20w)"; exit 1; }
grep -q "OK waive" <<<"$out20w" || { echo "FAIL [20]: saída inesperada do waive --id ($out20w)"; exit 1; }

node -e "
const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
if (d.entries.length !== 2) { console.error('esperava 2 entradas, achou ' + d.entries.length); process.exit(1); }
const a = d.entries.find((e) => e.id === 'DefeitoA20');
const b = d.entries.find((e) => e.id === 'DefeitoB20');
if (!a || a.status !== 'observed' || !a.base_commit) { console.error('DefeitoA20 deveria estar observed: ' + JSON.stringify(a)); process.exit(1); }
if (!b || b.status !== 'waived' || !b.waiver || b.waiver.reason !== 'no-test-infra') { console.error('DefeitoB20 deveria estar waived: ' + JSON.stringify(b)); process.exit(1); }
if (d.status !== 'observed') { console.error('topo deveria ser observed (todas resolvidas, nem todas waived), achou ' + d.status); process.exit(1); }
" "$EV20" || exit 1

out20post="$(FORGE_ROOT="$T" bash "$CR" check bug-two-real 2>&1)"; rc20post=$?
[ "$rc20post" -eq 0 ] || { echo "FAIL [20]: check deveria sair OK (rc 0) depois de resolver as 2 entradas por id ($out20post)"; exit 1; }
! grep -q "CONFLICT" <<<"$out20post" || { echo "FAIL [20]: check ainda bloqueia (CONFLICT) depois de resolver as 2 entradas por id ($out20post)"; exit 1; }
echo "OK [20] — replay --id e waive --id resolvem entradas individuais; check sai de CONFLICT (rc≠0) para não-bloqueante (rc 0)"

echo "[21] replay --id / waive --id com id inexistente recusam, arquivo intacto"
cp "$EV20" "$T/ev20-antes-21.json"
set +e
out21r="$(FORGE_ROOT="$T" bash "$RE" replay bug-two-real --id NaoExiste21 2>&1)"; rc21r=$?
set -e
[ "$rc21r" -ne 0 ] || { echo "FAIL [21-replay]: --id inexistente deveria recusar ($out21r)"; exit 1; }
grep -qi "não encontrado" <<<"$out21r" || { echo "FAIL [21-replay]: mensagem não nomeia o id ausente ($out21r)"; exit 1; }
cmp -s "$EV20" "$T/ev20-antes-21.json" || { echo "FAIL [21-replay]: arquivo foi tocado apesar da recusa"; exit 1; }
set +e
out21w="$(FORGE_ROOT="$T" bash "$CR" waive bug-two-real --id NaoExiste21 --reason no-test-infra --note x 2>&1)"; rc21w=$?
set -e
[ "$rc21w" -ne 0 ] || { echo "FAIL [21-waive]: --id inexistente deveria recusar ($out21w)"; exit 1; }
grep -qi "não encontrado" <<<"$out21w" || { echo "FAIL [21-waive]: mensagem não nomeia o id ausente ($out21w)"; exit 1; }
cmp -s "$EV20" "$T/ev20-antes-21.json" || { echo "FAIL [21-waive]: arquivo foi tocado apesar da recusa"; exit 1; }
echo "OK [21]"

echo "[22] record --rename-null nomeia a entrada sem id (MEDIUM); positiva e dois contrafactuais"
FORGE_ROOT="$T" bash "$SN" bug-rename22 --type bugfix --scale 1 >/dev/null
EV22="$T/.forge/specs/active/bug-rename22/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-rename22 --test-path tests/r22.test.mjs --test-id case-r22 --command "node --test tests/r22.test.mjs" --fix-files src/r22.sh --failure-pattern PR22 >/dev/null
node -e "const d=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); if (d.entries[0].id !== null) { console.error('pré-condição: entrada deveria começar sem id'); process.exit(1); }" "$EV22" || exit 1
out22="$(FORGE_ROOT="$T" bash "$RE" record bug-rename22 --rename-null DefeitoR22 2>&1)"; rc22=$?
[ "$rc22" -eq 0 ] || { echo "FAIL [22a]: --rename-null deveria ter sido aceito ($out22)"; exit 1; }
node -e "
const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
if (d.entries.length !== 1 || d.entries[0].id !== 'DefeitoR22') { console.error('rename-null não nomeou a entrada: ' + JSON.stringify(d.entries)); process.exit(1); }
if (d.entries[0].test_path !== 'tests/r22.test.mjs' || d.entries[0].failure_pattern !== 'PR22') { console.error('rename-null alterou outros campos: ' + JSON.stringify(d.entries[0])); process.exit(1); }
" "$EV22" || exit 1
echo "OK [22a]"
# 22b — --rename-null recusa quando já existem 2 entradas (agora nomeadas) — ambiguidade
FORGE_ROOT="$T" bash "$RE" record bug-rename22 --id DefeitoR22b --test-path tests/r22b.test.mjs --test-id case-r22b --command "node --test tests/r22b.test.mjs" --fix-files src/r22b.sh --failure-pattern PR22B >/dev/null
cp "$EV22" "$T/ev22-antes-22b.json"
set +e
out22b="$(FORGE_ROOT="$T" bash "$RE" record bug-rename22 --rename-null Outro22 2>&1)"; rc22b=$?
set -e
[ "$rc22b" -ne 0 ] || { echo "FAIL [22b]: --rename-null com 2 entradas deveria recusar ($out22b)"; exit 1; }
cmp -s "$EV22" "$T/ev22-antes-22b.json" || { echo "FAIL [22b]: arquivo foi tocado apesar da recusa"; exit 1; }
echo "OK [22b]"
# 22c — --rename-null recusa quando a única entrada já tem id declarado
FORGE_ROOT="$T" bash "$SN" bug-rename22c --type bugfix --scale 1 >/dev/null
EV22C="$T/.forge/specs/active/bug-rename22c/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-rename22c --id JaNomeada --test-path tests/r22c.test.mjs --test-id case-r22c --command "node --test tests/r22c.test.mjs" --fix-files src/r22c.sh --failure-pattern PR22C >/dev/null
cp "$EV22C" "$T/ev22c-antes.json"
set +e
out22c="$(FORGE_ROOT="$T" bash "$RE" record bug-rename22c --rename-null Outro22c 2>&1)"; rc22c=$?
set -e
[ "$rc22c" -ne 0 ] || { echo "FAIL [22c]: --rename-null sobre entrada já nomeada deveria recusar ($out22c)"; exit 1; }
cmp -s "$EV22C" "$T/ev22c-antes.json" || { echo "FAIL [22c]: arquivo foi tocado apesar da recusa"; exit 1; }
echo "OK [22]"

echo "[23] record sem --id com 2+ entradas é recusado mesmo com todos os campos obrigatórios presentes"
cp "$EV1" "$T/ev1-antes-23.json"
set +e
out23="$(FORGE_ROOT="$T" bash "$RE" record bug-multi --test-path tests/c23.test.mjs --test-id case-c23 --command "node --test tests/c23.test.mjs" --fix-files src/c23.sh --failure-pattern PC23 2>&1)"; rc23=$?
set -e
[ "$rc23" -ne 0 ] || { echo "FAIL [23]: record sem --id com campos completos e 2+ entradas foi aceito ($out23)"; exit 1; }
grep -qi -- "--id" <<<"$out23" || { echo "FAIL [23]: mensagem não cita --id (pode estar caindo na checagem de campos obrigatórios, não na recusa fail-closed) ($out23)"; exit 1; }
cmp -s "$EV1" "$T/ev1-antes-23.json" || { echo "FAIL [23]: arquivo foi tocado apesar da recusa"; exit 1; }
echo "OK [23]"

scenario_id_resolves_ok() { # scenario_id_resolves_ok <root> <suffix> — happy path completo de [20]
  local root="$1" suffix="$2"
  local id="bug-idr$suffix"
  mkdir -p "$root/src$suffix" "$root/tests$suffix"
  cat > "$root/src$suffix/mul.mjs" <<JS
export function mul(a, b) { return a + b; }
JS
  git -C "$root" add "src$suffix/mul.mjs"
  git -C "$root" commit -qm "feat: mul$suffix (com bug)" >/dev/null
  cat > "$root/tests$suffix/mul.test.mjs" <<JS
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mul } from '../src$suffix/mul.mjs';
test('case$suffix', () => { assert.strictEqual(mul(3, 4), 12); });
JS
  git -C "$root" add "tests$suffix/mul.test.mjs"
  git -C "$root" commit -qm "test: regressão $id" >/dev/null
  cat > "$root/src$suffix/mul.mjs" <<JS
export function mul(a, b) { return a * b; }
JS
  git -C "$root" add "src$suffix/mul.mjs"
  git -C "$root" commit -qm "fix: $id" >/dev/null

  FORGE_ROOT="$root" bash "$root/.forge/scripts/spec-new.sh" "$id" --type bugfix --scale 1 >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --id "DefA$suffix" --test-path "tests$suffix/mul.test.mjs" --test-id "case$suffix" --command "node --test tests$suffix/mul.test.mjs" --fix-files "src$suffix/mul.mjs" --failure-pattern AssertionError >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --id "DefB$suffix" --test-path "tests/b$suffix.test.mjs" --test-id "case-b$suffix" --command "node --test tests/b$suffix.test.mjs" --fix-files "src/b$suffix.sh" --failure-pattern "PB$suffix" >/dev/null 2>&1 || return 1

  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" replay "$id" --id "DefA$suffix" >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/check-red-first.sh" waive "$id" --id "DefB$suffix" --reason no-test-infra --note x >/dev/null 2>&1 || return 1

  FORGE_ROOT="$root" bash "$root/.forge/scripts/check-red-first.sh" check "$id" >/dev/null 2>&1
}

echo "[24] MUTAÇÃO (sandbox) — ignorar --id em resolveTargetEntry (usado por replay) faz [20] falhar"
run_mutation "24" 's/const resolved = resolveTargetEntry\(data, f\);/const resolved = resolveTargetEntry(data, {});/' scenario_id_resolves_ok

echo "OK"
