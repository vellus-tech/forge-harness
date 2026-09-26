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
# Achados da revisão adversarial (correção da #139, iteração 2), cobertos a partir do [37]:
#  [37] HIGH — `cmdEnsure`, com 0/1 entrada, replayava sempre o TOPO (`data`), nunca a entrada de
#       `entries[]`. Com `entries[]` presente (já passou por `record` desta Onda), uma forja
#       isolada em `entries[0]` (declarando um teste que nunca falha) sobrevivia: `ensure`
#       reexecutava o teste genuíno declarado no TOPO (ainda intacto), gravava o veredito
#       'observed' NA ENTRADA forjada via `upsertSingleEntry`, e a projeção seguinte também
#       curava o topo para bater com a entrada — o próximo `check` lia a mentira como prova
#       válida (rc 0), lavando exatamente a adulteração que o item 4 existe para bloquear.
#       Correção: com `Array.isArray(data.entries)`, `ensure` replaya sempre
#       `projectEntryToFlat(entries[0])` (a própria declaração da entrada) e persiste
#       endereçando por `{ id: entries[0].id }`; o topo bruto como vetor de replay fica
#       exclusivo do legado sem `entries[]` (onde não há outra fonte).
#  [38] MUTAÇÃO (sandbox) — desfazer a correção do [37] (voltar `cmdEnsure` a replayar o topo
#       quando `entries[]` está presente) faz [37] deixar de bloquear a forja isolada
#  [39] MEDIUM — `topMatchesProjection` comparava `data.fix_files ?? null` contra a projeção
#       (sempre `[]`, nunca `null`, para uma entrada só): um `red-evidence.json` legado
#       ESCRITO À MÃO (sem `entries[]` e sem a chave `fix_files`) virava "adulterado"
#       permanentemente — inclusive depois de um `/forge:red waive` genuinamente válido, porque
#       nem `waive` nem `ensure` gravam `fix_files` no caminho legado. Correção: sem
#       `entries[]` no arquivo bruto, o topo É a única fonte (não há segunda fonte para
#       divergir) — `topMatchesProjection` devolve `true` sem comparar.
#  [40] MUTAÇÃO (sandbox) — remover a guarda "sem entries[] bruto, nada a comparar" de
#       `topMatchesProjection` faz [39] voltar a bloquear o legado sem `fix_files` mesmo depois
#       do waive válido
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
if (legacy.id !== 'legado') { console.error('entries[0].id deveria ser o id fixo de migração \'legado\', achou ' + legacy.id); process.exit(1); }
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
import { deriveTopStatus } from '$LIB/red-evidence.mjs';
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
import { applyRecord } from '$LIB/red-evidence-ops.mjs';
import { deriveTopStatus } from '$LIB/red-evidence.mjs';
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
    if (entry.id === 'legado') continue; // a entrada migrada de legado não segue o padrão tests/<id>
    if (entry.test_path && !entry.test_path.includes(entry.id)) {
      console.error('run ' + run + ': entrada ' + entry.id + ' tem test_path de outro id: ' + entry.test_path + ' (seed ' + SEED + ')');
      failures++;
    }
  }

  // propriedade 4: legado nunca perdido — se começou legado, entries[0] é o legado intacto, com
  // o id fixo de migração ('legado', nunca null — redesenho de causa raiz da #139, 4ª rodada)
  if (hadLegacy) {
    const first = data.entries[0];
    if (first.id !== 'legado' || first.test_path !== 'tests/legacy.test.mjs' || first.excerpt !== 'boom') {
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
import { applyRecord, upsertSingleEntry } from '$LIB/red-evidence-ops.mjs';
import { deriveTopStatus } from '$LIB/red-evidence.mjs';
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

run_mutation() { # run_mutation <label> <perl-script> <scenario-fn> [target-basename]
  local label="$1" perl_expr="$2" scenario_fn="$3" target="${4:-red-evidence-ops.mjs}"
  local MT; MT="$(mktemp -d /tmp/forge-w218-mut.XXXXXX)"
  mk_root "$MT"
  local OPSM="$MT/.forge/scripts/lib/$target"
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
run_mutation "17" 's/doc\.entries = entries;/doc.entries = [entries[entries.length - 1]];/' scenario_multi_preserved "red-evidence.mjs"

echo "[18] MUTAÇÃO (sandbox) — remover a recusa sem --id faz [2] (quimera) sair rc 0"
# padrão específico à mensagem de 2+ entradas ("este change já tem N entradas") — desde a 4ª
# rodada de correção há DUAS mensagens "--id é obrigatório..." em applyRecord (a de 1 entrada já
# nomeada e a de 2+ entradas); um padrão genérico casaria a primeira (ordem de declaração no
# arquivo) e deixaria a checagem de 2+ intacta, mascarando a mutação.
run_mutation "18" 's/throw new Error\(`--id é obrigatório — este change já tem[^`]*`\);/idx = entries.length - 1;/s' scenario_chimera_refused

echo "[19] MUTAÇÃO (sandbox) — voltar a escrita do replay para só o topo faz [13] falhar"
run_mutation "19" 's/const upsert = upsertSingleEntry\(data, data\.change_id, \(entry\) => \(\{ \.\.\.entry, \.\.\.patch \}\), opts\);\n  if \(upsert\.refused\) return \{ refused: true, count: upsert\.count, reason: upsert\.reason \};\n  const updated = upsert\.legacy \? \{ \.\.\.data, \.\.\.patch \} : upsert\.data;/const updated = { ...data, ...patch };/s' scenario_replay_preserved

# ── achados da correção da #139, iteração 3 (revisão adversarial sobre a iteração 2) ───────────
#
#  [20] HIGH-2 — `replay --id`/`waive --id` resolvem entradas INDIVIDUAIS de um change com 2+
#       registradas: check-red-first sai de CONFLICT (bloqueado) para OK depois das duas
#       resolvidas por id — sem isso, um change com 2+ defeitos nunca chegava a verified/archived
#  [21] contrafactual — `replay --id`/`waive --id` com um id INEXISTENTE recusam, arquivo intacto
#  [23] LOW — `record` sem --id com 2+ entradas é recusado mesmo quando TODOS os campos
#       obrigatórios estão presentes — isola a recusa fail-closed da checagem de campos
#       obrigatórios (achado da revisão: [2] sozinho não distinguia as duas causas)
#  [24] MUTAÇÃO (sandbox) — ignorar `--id` em `resolveTargetEntry` (usado por `replay`) faz o
#       cenário de endereçamento por id de [20] falhar
#
# ── 4ª rodada de correção — redesenho de causa raiz ─────────────────────────────────────────────
#
# Três rodadas anteriores de conserto pontual abriram casos novos, todos com a mesma raiz: duas
# representações da evidência (escalares do topo × entries[]) e entradas com id nulo. Esta rodada
# ataca a causa raiz por construção — ver o cabeçalho de `lib/red-evidence.mjs` para o modelo
# completo (entries[] como única fonte, id nunca nulo, projeção pura, avaliação por entrada) — e
# REMOVE `--rename-null`: como toda entrada já nasce com id (auto-gerado ou explícito), nunca há
# uma entrada sem nome para renomear.
#
#  [25] HIGH end-to-end — record sem --id (auto-nomeia 'd1') → record --id B → replay --id d1 →
#       waive --id B → ensure → check rc 0. Prova que toda entrada, mesmo auto-nomeada, é sempre
#       endereçável — nenhuma fica "presa" sem nome depois que uma segunda é declarada.
#  [26] MUTAÇÃO (sandbox) — `nextAutoId` sempre devolvendo `null` faz [25] falhar (replay --id d1
#       não encontra entrada nenhuma — a causa raiz do HIGH-1/HIGH-2 original)
#  [27] HIGH end-to-end — mesmo fluxo de [25] partindo de um `red-evidence.json` LEGADO (formato
#       de entrada única, sem `entries[]`, status já `pending` com dado real, como os hoje em voo
#       em consumidores): a leitura migra a entrada para `id: 'legado'`, e o restante do fluxo
#       (record --id B, replay/waive por id, ensure, check) sai rc 0 do mesmo jeito.
#  [28] MUTAÇÃO (sandbox) — desligar a migração de legado (a entrada continua com `id: null`) faz
#       [27] falhar (`replay --id legado` não encontra nada)
#  [29] HIGH end-to-end — uma FORJA numa entrada de um change com 2+ entradas (a entrada com id
#       migrado de `null`, exatamente o vetor do achado HIGH-2 medido na revisão adversarial) é
#       pega por `ensure`+`check` — nunca sobrevive silenciosamente porque a entrada não tem mais
#       como ficar sem nome e ser pulada pelo laço de iteração.
#  [30] MUTAÇÃO (sandbox) — reintroduzir `entry.id != null ? {id} : undefined` em `cmdEnsure` (a
#       condição de antes desta rodada) faz [29] falhar: com um `id: null` bruto no arquivo (que a
#       migração já teria corrigido antes de chegar ao laço, então esta mutação simula a REGRESSÃO
#       de remover a migração e a guarda antiga ao mesmo tempo) a entrada volta a ser pulada.
#  [31] HIGH end-to-end — 1ª entrada DISPENSADA (`waive`) e 2ª OBSERVADA (`replay` real): `check`
#       sai `rc 0` — a mistura não trava mais em CONFLICT permanente por causa da entrada[0] sem
#       excerpt/base_commit (o topo, projeção de entries[0], nunca é a fonte da avaliação).
#  [32] MUTAÇÃO (sandbox) — avaliar os itens 2-4 só sobre `entries[0]` (a projeção do topo, em vez
#       de cada entrada `observed`) faz [31] falhar — CONFLICT permanente reaparece.
#  [33] MEDIUM (achado da revisão, teste ausente) — `record --id A` (uma única entrada, já NOMEADA
#       explicitamente) seguido de `record` SEM `--id` é recusado (fail-closed, arquivo intacto) —
#       isola esse caso do de 2+ entradas, que [2] já cobria.
#  [34] MUTAÇÃO (sandbox) — remover a distinção `id_explicit` em `applyRecord` (tratando toda
#       entrada única como auto-atualizável) faz [33] sair rc 0 (a quimera original, disfarçada)
#  [35] item 4 do redesenho — um `red-evidence.json` com o topo adulterado (escalares que não
#       batem com a projeção fresca de `entries[]`) é um achado BLOQUEANTE de `check` — a saída é
#       `/forge:red ensure`, que recalcula o topo a partir de `entries[]` e o restaura.
#  [36] MUTAÇÃO (sandbox) — `topMatchesProjection` sempre devolvendo `true` faz [35] deixar de
#       detectar a adulteração (check sai OK em vez de CONFLICT)

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

# ── 4ª rodada de correção — cenários ponta a ponta da causa raiz (com motor de replay real) ─────

echo "[25] HIGH end-to-end — record sem --id (auto 'd1') → record --id B → replay --id d1 → waive --id B → ensure → check rc 0"
mkdir -p "$T/src25" "$T/tests25"
cat > "$T/src25/calc.mjs" <<'JS'
export function calc(a, b) { return a - b; }
JS
git -C "$T" add src25/calc.mjs
git -C "$T" commit -qm "feat: calc25 (com bug)" >/dev/null
cat > "$T/tests25/calc.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calc } from '../src25/calc.mjs';
test('case25', () => { assert.strictEqual(calc(2, 3), 5); });
JS
git -C "$T" add tests25/calc.test.mjs
git -C "$T" commit -qm "test: regressão bug-auto25" >/dev/null
cat > "$T/src25/calc.mjs" <<'JS'
export function calc(a, b) { return a + b; }
JS
git -C "$T" add src25/calc.mjs
git -C "$T" commit -qm "fix: bug-auto25" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-auto25 --type bugfix --scale 1 >/dev/null
EV25="$T/.forge/specs/active/bug-auto25/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-auto25 --test-path tests25/calc.test.mjs --test-id case25 --command "node --test tests25/calc.test.mjs" --fix-files src25/calc.mjs --failure-pattern AssertionError >/dev/null
node -e "const d=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); if (d.entries.length !== 1 || d.entries[0].id !== 'd1' || d.entries[0].id_explicit !== false) { console.error('pré-condição: esperava entrada única auto-nomeada d1, achou ' + JSON.stringify(d.entries)); process.exit(1); }" "$EV25" || exit 1
FORGE_ROOT="$T" bash "$RE" record bug-auto25 --id DefeitoB25 --test-path tests/b25.test.mjs --test-id case-b25 --command "node --test tests/b25.test.mjs" --fix-files src/b25.sh --failure-pattern PB25 >/dev/null

out25r="$(FORGE_ROOT="$T" bash "$RE" replay bug-auto25 --id d1 2>&1)"; rc25r=$?
[ "$rc25r" -eq 0 ] || { echo "FAIL [25]: replay --id d1 (entrada auto-nomeada) deveria observar ($out25r)"; exit 1; }
grep -qi observado <<<"$out25r" || { echo "FAIL [25]: replay --id d1 não confirmou observação ($out25r)"; exit 1; }

out25w="$(FORGE_ROOT="$T" bash "$CR" waive bug-auto25 --id DefeitoB25 --reason no-test-infra --note "w218 [25]" 2>&1)"; rc25w=$?
[ "$rc25w" -eq 0 ] || { echo "FAIL [25]: waive --id DefeitoB25 deveria ter sido aceito ($out25w)"; exit 1; }

out25e="$(FORGE_ROOT="$T" bash "$RE" ensure bug-auto25 2>&1)"; rc25e=$?
[ "$rc25e" -eq 0 ] || { echo "FAIL [25]: ensure deveria sair rc 0 ($out25e)"; exit 1; }

out25c="$(FORGE_ROOT="$T" bash "$CR" check bug-auto25 2>&1)"; rc25c=$?
[ "$rc25c" -eq 0 ] || { echo "FAIL [25]: check deveria sair rc 0 depois do fluxo completo ($out25c)"; exit 1; }
! grep -q "CONFLICT" <<<"$out25c" || { echo "FAIL [25]: check ainda bloqueia ($out25c)"; exit 1; }
echo "OK [25]"

scenario_auto_id_addressable() { # scenario_auto_id_addressable <root> <suffix>
  local root="$1" suffix="$2"
  local id="bug-auto26$suffix"
  mkdir -p "$root/src$suffix" "$root/tests$suffix"
  cat > "$root/src$suffix/calc.mjs" <<JS
export function calc(a, b) { return a - b; }
JS
  git -C "$root" add "src$suffix/calc.mjs"
  git -C "$root" commit -qm "feat: calc$suffix (com bug)" >/dev/null
  cat > "$root/tests$suffix/calc.test.mjs" <<JS
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calc } from '../src$suffix/calc.mjs';
test('case$suffix', () => { assert.strictEqual(calc(2, 3), 5); });
JS
  git -C "$root" add "tests$suffix/calc.test.mjs"
  git -C "$root" commit -qm "test: regressão $id" >/dev/null
  cat > "$root/src$suffix/calc.mjs" <<JS
export function calc(a, b) { return a + b; }
JS
  git -C "$root" add "src$suffix/calc.mjs"
  git -C "$root" commit -qm "fix: $id" >/dev/null

  FORGE_ROOT="$root" bash "$root/.forge/scripts/spec-new.sh" "$id" --type bugfix --scale 1 >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --test-path "tests$suffix/calc.test.mjs" --test-id "case$suffix" --command "node --test tests$suffix/calc.test.mjs" --fix-files "src$suffix/calc.mjs" --failure-pattern AssertionError >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" replay "$id" --id d1 >/dev/null 2>&1
}

echo "[26] MUTAÇÃO (sandbox) — nextAutoId sempre devolvendo null faz [25] falhar (replay --id d1 não encontra nada)"
run_mutation "26" 's/return \`\$\{AUTO_ID_PREFIX\}\$\{n\}\`;/return null;/' scenario_auto_id_addressable "red-evidence.mjs"

echo "[27] HIGH end-to-end — mesmo fluxo de [25] partindo de legado pending (migração atribui 'legado')"
FORGE_ROOT="$T" bash "$SN" bug-legado27 --type bugfix --scale 1 >/dev/null
DIR27="$T/.forge/specs/active/bug-legado27"
EV27="$DIR27/evidence/red/red-evidence.json"
node -e '
const fs = require("fs");
const p = process.argv[1];
const d = JSON.parse(fs.readFileSync(p, "utf8"));
d.status = "pending";
d.test_path = "tests27/legacy.test.mjs";
d.test_id = "legacy27-case";
d.command = "node --test tests27/legacy.test.mjs";
d.failure_pattern = "AssertionError";
d.fix_files = ["src27/legacy.mjs"];
fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
' "$EV27"
mkdir -p "$T/src27" "$T/tests27"
cat > "$T/src27/legacy.mjs" <<'JS'
export function legacyCalc(a, b) { return a - b; }
JS
git -C "$T" add src27/legacy.mjs
git -C "$T" commit -qm "feat: legacy27 (com bug)" >/dev/null
cat > "$T/tests27/legacy.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { legacyCalc } from '../src27/legacy.mjs';
test('legacy27-case', () => { assert.strictEqual(legacyCalc(2, 3), 5); });
JS
git -C "$T" add tests27/legacy.test.mjs
git -C "$T" commit -qm "test: regressão bug-legado27" >/dev/null
cat > "$T/src27/legacy.mjs" <<'JS'
export function legacyCalc(a, b) { return a + b; }
JS
git -C "$T" add src27/legacy.mjs
git -C "$T" commit -qm "fix: bug-legado27" >/dev/null

FORGE_ROOT="$T" bash "$RE" record bug-legado27 --id DefeitoB27 --test-path tests/b27.test.mjs --test-id case-b27 --command "node --test tests/b27.test.mjs" --fix-files src/b27.sh --failure-pattern PB27 >/dev/null
node -e "const d=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); if (d.entries.length !== 2 || d.entries[0].id !== 'legado') { console.error('pré-condição: esperava [legado, DefeitoB27], achou ' + JSON.stringify(d.entries.map((e)=>e.id))); process.exit(1); }" "$EV27" || exit 1

out27r="$(FORGE_ROOT="$T" bash "$RE" replay bug-legado27 --id legado 2>&1)"; rc27r=$?
[ "$rc27r" -eq 0 ] || { echo "FAIL [27]: replay --id legado deveria observar ($out27r)"; exit 1; }
grep -qi observado <<<"$out27r" || { echo "FAIL [27]: replay --id legado não confirmou observação ($out27r)"; exit 1; }
out27w="$(FORGE_ROOT="$T" bash "$CR" waive bug-legado27 --id DefeitoB27 --reason no-test-infra --note "w218 [27]" 2>&1)"; rc27w=$?
[ "$rc27w" -eq 0 ] || { echo "FAIL [27]: waive --id DefeitoB27 deveria ter sido aceito ($out27w)"; exit 1; }
out27e="$(FORGE_ROOT="$T" bash "$RE" ensure bug-legado27 2>&1)"; rc27e=$?
[ "$rc27e" -eq 0 ] || { echo "FAIL [27]: ensure deveria sair rc 0 ($out27e)"; exit 1; }
out27c="$(FORGE_ROOT="$T" bash "$CR" check bug-legado27 2>&1)"; rc27c=$?
[ "$rc27c" -eq 0 ] || { echo "FAIL [27]: check deveria sair rc 0 partindo de legado pending ($out27c)"; exit 1; }
echo "OK [27]"

scenario_legacy_addressable() { # scenario_legacy_addressable <root> <suffix>
  local root="$1" suffix="$2"
  local id="bug-legacy28$suffix"
  FORGE_ROOT="$root" bash "$root/.forge/scripts/spec-new.sh" "$id" --type bugfix --scale 1 >/dev/null 2>&1 || return 1
  local ev="$root/.forge/specs/active/$id/evidence/red/red-evidence.json"
  node -e "
const fs = require('fs');
const p = process.argv[1];
const d = JSON.parse(fs.readFileSync(p, 'utf8'));
d.status = 'pending';
d.test_path = 'tests/legacy.test.mjs';
d.test_id = 'legacy-case';
d.command = 'node --test tests/legacy.test.mjs';
d.failure_pattern = 'AssertionError';
d.fix_files = ['src/legacy.sh'];
fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
" "$ev"
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --id "B$suffix" --test-path "tests/b$suffix.test.mjs" --test-id "case-b$suffix" --command "node --test tests/b$suffix.test.mjs" --fix-files "src/b$suffix.sh" --failure-pattern "PB$suffix" >/dev/null 2>&1 || return 1
  local out
  out="$(FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" replay "$id" --id legado 2>&1)"
  ! grep -qi "não encontrado" <<<"$out"
}

echo "[28] MUTAÇÃO (sandbox) — desligar a migração de legado (entrada continua com id null) faz [27] falhar (replay --id legado não encontra nada)"
run_mutation "28" 's/return \[\{ \.\.\.entries\[0\], id: LEGACY_ID, id_explicit: false \}\];/return entries;/' scenario_legacy_addressable "red-evidence.mjs"

echo "[29] HIGH end-to-end — forja numa entrada (id migrado de null) de um change com 2+ entradas é pega por ensure/check"
mkdir -p "$T/src29" "$T/tests29"
cat > "$T/src29/x.mjs" <<'JS'
export function xfn(a, b) { return a - b; }
JS
git -C "$T" add src29/x.mjs
git -C "$T" commit -qm "feat: x29 (com bug)" >/dev/null
cat > "$T/tests29/x.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { xfn } from '../src29/x.mjs';
test('case29', () => { assert.strictEqual(xfn(2, 3), 5); });
JS
git -C "$T" add tests29/x.test.mjs
git -C "$T" commit -qm "test: regressão bug-forge29" >/dev/null
cat > "$T/src29/x.mjs" <<'JS'
export function xfn(a, b) { return a + b; }
JS
git -C "$T" add src29/x.mjs
git -C "$T" commit -qm "fix: bug-forge29" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-forge29 --type bugfix --scale 1 >/dev/null
EV29="$T/.forge/specs/active/bug-forge29/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-forge29 --test-path tests29/x.test.mjs --test-id case29 --command "node --test tests29/x.test.mjs" --fix-files src29/x.mjs --failure-pattern AssertionError >/dev/null
FORGE_ROOT="$T" bash "$RE" replay bug-forge29 --id d1 >/dev/null
FORGE_ROOT="$T" bash "$RE" record bug-forge29 --id DefeitoReal29 --test-path tests/real29.test.mjs --test-id case-real29 --command "node --test tests/real29.test.mjs" --fix-files src/real29.sh --failure-pattern PREAL29 >/dev/null
FORGE_ROOT="$T" bash "$CR" waive bug-forge29 --id DefeitoReal29 --reason no-test-infra --note "w218 [29]" >/dev/null

# simula um arquivo já gravado por uma versão ANTERIOR desta branch (antes do redesenho): a
# entrada real e observada acima tem o id apagado de volta para null, e o resto forjado por cima —
# o vetor exato do achado HIGH-2 medido na revisão adversarial.
FORJA29_EXCERPT="AssertionError: forjado a mao, nunca rodou de verdade"
FORJA29_HASH="$(node -e "process.stdout.write(require('crypto').createHash('sha256').update(process.argv[1]).digest('hex'))" "$FORJA29_EXCERPT")"
node -e '
const fs = require("fs");
const p = process.argv[1];
const d = JSON.parse(fs.readFileSync(p, "utf8"));
const e = d.entries[0];
e.id = null;
e.status = "observed";
e.test_path = "nao/existe29.test.mjs";
e.test_id = "forjado-case29";
e.command = "node --test nao/existe29.test.mjs";
e.base_commit = "0123456";
e.classification = "behavioral";
e.excerpt = process.argv[2];
e.excerpt_sha256 = process.argv[3];
e.base_result = "failed";
fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
' "$EV29" "$FORJA29_EXCERPT" "$FORJA29_HASH"

out29e="$(FORGE_ROOT="$T" bash "$RE" ensure bug-forge29 2>&1)"; rc29e=$?
[ "$rc29e" -eq 0 ] || { echo "FAIL [29]: ensure nunca deveria sair rc≠0 por veredito desfavorável ($out29e)"; exit 1; }
grep -q '"status": "observed"' "$EV29" && { echo "FAIL [29]: ensure deveria ter sobrescrito a forja (ainda observed)"; exit 1; }

set +e
out29c="$(FORGE_ROOT="$T" bash "$CR" check bug-forge29 2>&1)"; rc29c=$?
set -e
[ "$rc29c" -ne 0 ] || { echo "FAIL [29]: check deveria bloquear depois de ensure reexecutar a forja e reprovar ($out29c)"; exit 1; }
echo "OK [29] — forja na entrada com id migrado de null é pega por ensure (deixa de ser observed) e check bloqueia"

scenario_ensure_iterates_two() { # scenario_ensure_iterates_two <root> <suffix> — controle: ensure
  # SEMPRE examina as 2 entradas de um change com 2+ registradas, sem depender do topo (usado por
  # [30], cujo mutante força ensure a sempre tratar o change como se tivesse ≤1 entrada — o que
  # "lava" a forja da entrada[0] revalidando o topo antigo e intacto, em vez da entrada forjada).
  local root="$1" suffix="$2"
  local id="bug-ens30$suffix"
  mkdir -p "$root/src$suffix" "$root/tests$suffix"
  cat > "$root/src$suffix/x.mjs" <<JS
export function xfn(a, b) { return a - b; }
JS
  git -C "$root" add "src$suffix/x.mjs"
  git -C "$root" commit -qm "feat: x$suffix (com bug)" >/dev/null
  cat > "$root/tests$suffix/x.test.mjs" <<JS
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { xfn } from '../src$suffix/x.mjs';
test('case$suffix', () => { assert.strictEqual(xfn(2, 3), 5); });
JS
  git -C "$root" add "tests$suffix/x.test.mjs"
  git -C "$root" commit -qm "test: regressão $id" >/dev/null
  cat > "$root/src$suffix/x.mjs" <<JS
export function xfn(a, b) { return a + b; }
JS
  git -C "$root" add "src$suffix/x.mjs"
  git -C "$root" commit -qm "fix: $id" >/dev/null

  FORGE_ROOT="$root" bash "$root/.forge/scripts/spec-new.sh" "$id" --type bugfix --scale 1 >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --test-path "tests$suffix/x.test.mjs" --test-id "case$suffix" --command "node --test tests$suffix/x.test.mjs" --fix-files "src$suffix/x.mjs" --failure-pattern AssertionError >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" replay "$id" --id d1 >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --id "Real$suffix" --test-path "tests/real$suffix.test.mjs" --test-id "case-real$suffix" --command "node --test tests/real$suffix.test.mjs" --fix-files "src/real$suffix.sh" --failure-pattern "PREAL$suffix" >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/check-red-first.sh" waive "$id" --id "Real$suffix" --reason no-test-infra --note x >/dev/null 2>&1 || return 1

  local ev="$root/.forge/specs/active/$id/evidence/red/red-evidence.json"
  local excerpt="AssertionError: forjado, nunca rodou de verdade"
  local hash; hash="$(node -e "process.stdout.write(require('crypto').createHash('sha256').update(process.argv[1]).digest('hex'))" "$excerpt")"
  node -e '
const fs = require("fs");
const p = process.argv[1];
const d = JSON.parse(fs.readFileSync(p, "utf8"));
const e = d.entries[0];
e.status = "observed";
e.test_path = "nao/existe.test.mjs";
e.test_id = "forjado-case";
e.command = "node --test nao/existe.test.mjs";
e.base_commit = "0123456";
e.classification = "behavioral";
e.excerpt = process.argv[2];
e.excerpt_sha256 = process.argv[3];
e.base_result = "failed";
fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
' "$ev" "$excerpt" "$hash"

  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" ensure "$id" >/dev/null 2>&1 || return 1
  ! grep -q '"status": "observed"' "$ev"
}

echo "[30] MUTAÇÃO (sandbox) — ensure sempre tratar o change como ≤1 entrada (ignorando 2+) faz [29] falhar: a forja é lavada revalidando o topo antigo intacto, em vez da entrada forjada"
run_mutation "30" 's/if \(entries\.length <= 1\) \{/if (true) {/' scenario_ensure_iterates_two

echo "[31] HIGH end-to-end — 1ª entrada dispensada (waive) e 2ª observada (replay real): check sai rc 0"
mkdir -p "$T/src31" "$T/tests31"
cat > "$T/src31/y.mjs" <<'JS'
export function yfn(a, b) { return a - b; }
JS
git -C "$T" add src31/y.mjs
git -C "$T" commit -qm "feat: y31 (com bug)" >/dev/null
cat > "$T/tests31/y.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { yfn } from '../src31/y.mjs';
test('case31', () => { assert.strictEqual(yfn(2, 3), 5); });
JS
git -C "$T" add tests31/y.test.mjs
git -C "$T" commit -qm "test: regressão bug-mix31 DefeitoB31" >/dev/null
cat > "$T/src31/y.mjs" <<'JS'
export function yfn(a, b) { return a + b; }
JS
git -C "$T" add src31/y.mjs
git -C "$T" commit -qm "fix: bug-mix31 DefeitoB31" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-mix31 --type bugfix --scale 1 >/dev/null
EV31="$T/.forge/specs/active/bug-mix31/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-mix31 --id DefeitoA31 --test-path tests/a31.test.mjs --test-id case-a31 --command "node --test tests/a31.test.mjs" --fix-files src/a31.sh --failure-pattern PA31 >/dev/null
out31w="$(FORGE_ROOT="$T" bash "$CR" waive bug-mix31 --id DefeitoA31 --reason no-test-infra --note "w218 [31]" 2>&1)"; rc31w=$?
[ "$rc31w" -eq 0 ] || { echo "FAIL [31]: waive --id DefeitoA31 (1ª entrada) deveria ter sido aceito ($out31w)"; exit 1; }
FORGE_ROOT="$T" bash "$RE" record bug-mix31 --id DefeitoB31 --test-path tests31/y.test.mjs --test-id case31 --command "node --test tests31/y.test.mjs" --fix-files src31/y.mjs --failure-pattern AssertionError >/dev/null
out31r="$(FORGE_ROOT="$T" bash "$RE" replay bug-mix31 --id DefeitoB31 2>&1)"; rc31r=$?
[ "$rc31r" -eq 0 ] || { echo "FAIL [31]: replay --id DefeitoB31 (2ª entrada) deveria observar ($out31r)"; exit 1; }
node -e "
const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
const a = d.entries.find((e) => e.id === 'DefeitoA31');
const b = d.entries.find((e) => e.id === 'DefeitoB31');
if (!a || a.status !== 'waived') { console.error('DefeitoA31 deveria estar waived: ' + JSON.stringify(a)); process.exit(1); }
if (!b || b.status !== 'observed' || !b.base_commit) { console.error('DefeitoB31 deveria estar observed: ' + JSON.stringify(b)); process.exit(1); }
if (d.status !== 'observed') { console.error('topo deveria ser observed (todas resolvidas, nem todas waived), achou ' + d.status); process.exit(1); }
" "$EV31" || exit 1
set +e
out31c="$(FORGE_ROOT="$T" bash "$CR" check bug-mix31 2>&1)"; rc31c=$?
set -e
[ "$rc31c" -eq 0 ] || { echo "FAIL [31]: check deveria sair rc 0 (a entrada observada é avaliada por ela mesma, não pela projeção do topo, que é a dispensada) ($out31c)"; exit 1; }
! grep -q "CONFLICT" <<<"$out31c" || { echo "FAIL [31]: check ainda bloqueia (CONFLICT) — a mistura waived+observed não deveria travar ($out31c)"; exit 1; }
echo "OK [31]"

scenario_waived_first_observed_second() { # scenario_waived_first_observed_second <root> <suffix>
  local root="$1" suffix="$2"
  local id="bug-mix32$suffix"
  mkdir -p "$root/src$suffix" "$root/tests$suffix"
  cat > "$root/src$suffix/y.mjs" <<JS
export function yfn(a, b) { return a - b; }
JS
  git -C "$root" add "src$suffix/y.mjs"
  git -C "$root" commit -qm "feat: y$suffix (com bug)" >/dev/null
  cat > "$root/tests$suffix/y.test.mjs" <<JS
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { yfn } from '../src$suffix/y.mjs';
test('case$suffix', () => { assert.strictEqual(yfn(2, 3), 5); });
JS
  git -C "$root" add "tests$suffix/y.test.mjs"
  git -C "$root" commit -qm "test: regressão $id" >/dev/null
  cat > "$root/src$suffix/y.mjs" <<JS
export function yfn(a, b) { return a + b; }
JS
  git -C "$root" add "src$suffix/y.mjs"
  git -C "$root" commit -qm "fix: $id" >/dev/null

  FORGE_ROOT="$root" bash "$root/.forge/scripts/spec-new.sh" "$id" --type bugfix --scale 1 >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --id "A$suffix" --test-path "tests/a$suffix.test.mjs" --test-id "case-a$suffix" --command "node --test tests/a$suffix.test.mjs" --fix-files "src/a$suffix.sh" --failure-pattern "PA$suffix" >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/check-red-first.sh" waive "$id" --id "A$suffix" --reason no-test-infra --note x >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --id "B$suffix" --test-path "tests$suffix/y.test.mjs" --test-id "case$suffix" --command "node --test tests$suffix/y.test.mjs" --fix-files "src$suffix/y.mjs" --failure-pattern AssertionError >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" replay "$id" --id "B$suffix" >/dev/null 2>&1 || return 1

  FORGE_ROOT="$root" bash "$root/.forge/scripts/check-red-first.sh" check "$id" >/dev/null 2>&1
}

echo "[32] MUTAÇÃO (sandbox) — avaliar os itens 2-4 só sobre entries[0] (a projeção do topo) em vez de cada entrada observed faz [31] falhar"
run_mutation "32" "s/const observedEntries = entries\\.filter\\(\\(e\\) => e\\.status === 'observed'\\);/const observedEntries = topStatus === 'observed' ? [entries[0]] : [];/" scenario_waived_first_observed_second "check-red-first.mjs"

echo "[33] MEDIUM (achado da revisão) — record --id A (única entrada, NOMEADA) seguido de record sem --id é recusado, arquivo intacto"
FORGE_ROOT="$T" bash "$SN" bug-explicit33 --type bugfix --scale 1 >/dev/null
EV33="$T/.forge/specs/active/bug-explicit33/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-explicit33 --id Explicita33 --test-path tests/e33.test.mjs --test-id case-e33 --command "node --test tests/e33.test.mjs" --fix-files src/e33.sh --failure-pattern PE33 >/dev/null
node -e "const d=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); if (d.entries.length !== 1 || d.entries[0].id !== 'Explicita33' || d.entries[0].id_explicit !== true) { console.error('pré-condição: entrada deveria ser única e id_explicit:true, achou ' + JSON.stringify(d.entries)); process.exit(1); }" "$EV33" || exit 1
cp "$EV33" "$T/ev33-antes.json"
set +e
out33="$(FORGE_ROOT="$T" bash "$RE" record bug-explicit33 --failure-pattern PE33B 2>&1)"; rc33=$?
set -e
[ "$rc33" -ne 0 ] || { echo "FAIL [33]: record sem --id sobre entrada única já NOMEADA foi aceito ($out33)"; exit 1; }
grep -qi -- "--id" <<<"$out33" || { echo "FAIL [33]: mensagem não cita --id ($out33)"; exit 1; }
grep -q "Explicita33" <<<"$out33" || { echo "FAIL [33]: mensagem não nomeia a entrada já declarada ($out33)"; exit 1; }
cmp -s "$EV33" "$T/ev33-antes.json" || { echo "FAIL [33]: arquivo foi tocado apesar da recusa"; exit 1; }
echo "OK [33]"

scenario_explicit_single_refuses() { # scenario_explicit_single_refuses <root> <suffix>
  local root="$1" suffix="$2"
  local id="bug-expl34$suffix"
  FORGE_ROOT="$root" bash "$root/.forge/scripts/spec-new.sh" "$id" --type bugfix --scale 1 >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --id "Nome$suffix" --test-path "tests/e$suffix.test.mjs" --test-id "case-e$suffix" --command "node --test tests/e$suffix.test.mjs" --fix-files "src/e$suffix.sh" --failure-pattern "PE$suffix" >/dev/null 2>&1 || return 1
  set +e
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --failure-pattern "PE${suffix}B" >/dev/null 2>&1
  local rc=$?
  set -e
  [ "$rc" -ne 0 ]
}

echo "[34] MUTAÇÃO (sandbox) — remover a distinção id_explicit em applyRecord (tratando toda entrada única como auto-atualizável) faz [33] sair rc 0 (a quimera original, disfarçada)"
run_mutation "34" 's/entries\.length === 1 && !entries\[0\]\.id_explicit/entries.length === 1/' scenario_explicit_single_refuses

echo "[35] item 4 do redesenho — topo adulterado (diverge da projeção de entries[]) é achado BLOQUEANTE de check, mesmo com a entrada genuinamente observada"
mkdir -p "$T/src35" "$T/tests35"
cat > "$T/src35/t.mjs" <<'JS'
export function tfn(a, b) { return a - b; }
JS
git -C "$T" add src35/t.mjs
git -C "$T" commit -qm "feat: t35 (com bug)" >/dev/null
cat > "$T/tests35/t.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { tfn } from '../src35/t.mjs';
test('case35', () => { assert.strictEqual(tfn(2, 3), 5); });
JS
git -C "$T" add tests35/t.test.mjs
git -C "$T" commit -qm "test: regressão bug-tamper35" >/dev/null
cat > "$T/src35/t.mjs" <<'JS'
export function tfn(a, b) { return a + b; }
JS
git -C "$T" add src35/t.mjs
git -C "$T" commit -qm "fix: bug-tamper35" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-tamper35 --type bugfix --scale 1 >/dev/null
EV35="$T/.forge/specs/active/bug-tamper35/evidence/red/red-evidence.json"
FORGE_ROOT="$T" bash "$RE" record bug-tamper35 --test-path tests35/t.test.mjs --test-id case35 --command "node --test tests35/t.test.mjs" --fix-files src35/t.mjs --failure-pattern AssertionError >/dev/null
FORGE_ROOT="$T" bash "$RE" replay bug-tamper35 --id d1 >/dev/null
node -e "
const fs = require('fs');
const p = process.argv[1];
const d = JSON.parse(fs.readFileSync(p, 'utf8'));
d.failure_pattern = 'ADULTERADO-NAO-BATE-COM-ENTRIES';
fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
" "$EV35"
set +e
out35="$(FORGE_ROOT="$T" bash "$CR" check bug-tamper35 2>&1)"; rc35=$?
set -e
[ "$rc35" -ne 0 ] || { echo "FAIL [35]: check deveria bloquear com topo adulterado, mesmo com entrada genuinamente observada ($out35)"; exit 1; }
grep -qi "adulterado" <<<"$out35" || { echo "FAIL [35]: mensagem não cita adulteração ($out35)"; exit 1; }
echo "OK [35]"

scenario_tamper_detected() { # scenario_tamper_detected <root> <suffix>
  # a entrada precisa estar GENUINAMENTE observada (replay real) antes da adulteração — senão o
  # item 1 (Red ainda não observado) bloqueia por conta própria e a mutação de
  # `topMatchesProjection` fica impossível de isolar (o cenário "passaria" — rc≠0 — mesmo com a
  # detecção de adulteração completamente desligada).
  local root="$1" suffix="$2"
  local id="bug-tamper36$suffix"
  mkdir -p "$root/src$suffix" "$root/tests$suffix"
  cat > "$root/src$suffix/t.mjs" <<JS
export function tfn(a, b) { return a - b; }
JS
  git -C "$root" add "src$suffix/t.mjs"
  git -C "$root" commit -qm "feat: t$suffix (com bug)" >/dev/null
  cat > "$root/tests$suffix/t.test.mjs" <<JS
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { tfn } from '../src$suffix/t.mjs';
test('case$suffix', () => { assert.strictEqual(tfn(2, 3), 5); });
JS
  git -C "$root" add "tests$suffix/t.test.mjs"
  git -C "$root" commit -qm "test: regressão $id" >/dev/null
  cat > "$root/src$suffix/t.mjs" <<JS
export function tfn(a, b) { return a + b; }
JS
  git -C "$root" add "src$suffix/t.mjs"
  git -C "$root" commit -qm "fix: $id" >/dev/null

  FORGE_ROOT="$root" bash "$root/.forge/scripts/spec-new.sh" "$id" --type bugfix --scale 1 >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --test-path "tests$suffix/t.test.mjs" --test-id "case$suffix" --command "node --test tests$suffix/t.test.mjs" --fix-files "src$suffix/t.mjs" --failure-pattern AssertionError >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" replay "$id" --id d1 >/dev/null 2>&1 || return 1

  local ev="$root/.forge/specs/active/$id/evidence/red/red-evidence.json"
  # adultera SÓ o topo (entries[] fica intacto e genuinamente observado) — se
  # topMatchesProjection nunca detectar isso, nenhum outro item bloqueia: entries[0] é observed,
  # com excerpt e failure_pattern reais e coerentes entre si.
  node -e "
const fs = require('fs');
const p = process.argv[1];
const d = JSON.parse(fs.readFileSync(p, 'utf8'));
d.failure_pattern = 'ADULTERADO-NAO-BATE-COM-ENTRIES';
fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
" "$ev"

  set +e
  FORGE_ROOT="$root" bash "$root/.forge/scripts/check-red-first.sh" check "$id" >/dev/null 2>&1
  local rc=$?
  set -e
  [ "$rc" -ne 0 ]
}

echo "[36] MUTAÇÃO (sandbox) — topMatchesProjection sempre devolvendo true faz [35] deixar de detectar a adulteração"
run_mutation "36" 's/return keys\.every\(\(k\) => deepEqual\(data\[k\] \?\? null, projection\[k\] \?\? null\)\);/return true;/' scenario_tamper_detected "red-evidence.mjs"

scenario_ensure_sources_entry() { # scenario_ensure_sources_entry <root> <suffix>
  # HIGH da correção da #139 — forja ISOLADA em entries[0] (o topo continua declarando o teste
  # genuíno) não pode ser lavada por `ensure` reexecutando o topo em vez da própria entrada.
  local root="$1" suffix="$2"
  local id="bug-tamper37$suffix"
  mkdir -p "$root/src$suffix" "$root/tests$suffix"
  cat > "$root/src$suffix/t.mjs" <<JS
export function tfn(a, b) { return a - b; }
JS
  git -C "$root" add "src$suffix/t.mjs"
  git -C "$root" commit -qm "feat: t$suffix (com bug)" >/dev/null
  cat > "$root/tests$suffix/t.test.mjs" <<JS
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { tfn } from '../src$suffix/t.mjs';
test('case$suffix', () => { assert.strictEqual(tfn(2, 3), 5); });
JS
  # fixture forjável: nunca falha, qualquer que seja o estado de src$suffix/t.mjs — é o que a
  # forja de entries[0] aponta, abaixo, para simular uma declaração que não reproduz nada.
  cat > "$root/tests$suffix/no.test.mjs" <<JS
import { test } from 'node:test';
import assert from 'node:assert/strict';
test('caseno$suffix', () => { assert.ok(true); });
JS
  git -C "$root" add "tests$suffix/t.test.mjs" "tests$suffix/no.test.mjs"
  git -C "$root" commit -qm "test: regressão $id + fixture no-op" >/dev/null
  cat > "$root/src$suffix/t.mjs" <<JS
export function tfn(a, b) { return a + b; }
JS
  git -C "$root" add "src$suffix/t.mjs"
  git -C "$root" commit -qm "fix: $id" >/dev/null

  FORGE_ROOT="$root" bash "$root/.forge/scripts/spec-new.sh" "$id" --type bugfix --scale 1 >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" record "$id" --test-path "tests$suffix/t.test.mjs" --test-id "case$suffix" --command "node --test tests$suffix/t.test.mjs" --fix-files "src$suffix/t.mjs" --failure-pattern AssertionError >/dev/null 2>&1 || return 1
  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" replay "$id" --id d1 >/dev/null 2>&1 || return 1

  local ev="$root/.forge/specs/active/$id/evidence/red/red-evidence.json"
  # forja SÓ entries[0] — o topo (ainda intacto) continua declarando tests$suffix/t.test.mjs, o
  # teste genuíno já observado acima.
  node -e "
const fs = require('fs');
const p = process.argv[1];
const d = JSON.parse(fs.readFileSync(p, 'utf8'));
d.entries[0].test_path = 'tests$suffix/no.test.mjs';
d.entries[0].test_id = 'caseno$suffix';
d.entries[0].command = 'node --test tests$suffix/no.test.mjs';
fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
" "$ev"

  FORGE_ROOT="$root" bash "$root/.forge/scripts/red-evidence.sh" ensure "$id" >/dev/null 2>&1 || true

  set +e
  FORGE_ROOT="$root" bash "$root/.forge/scripts/check-red-first.sh" check "$id" >/dev/null 2>&1
  local rc=$?
  set -e
  # com a correção, ensure reexecuta a PRÓPRIA declaração forjada (nunca falha) e persistReplayResult
  # grava 'pending' de volta na entrada — check continua bloqueando (rc != 0). Sem a correção,
  # ensure reexecuta o topo genuíno e a forja é lavada para 'observed' (rc 0).
  [ "$rc" -ne 0 ]
}

echo "[37] HIGH — ensure fonte SEMPRE de entries[0] (nunca do topo) quando entries[] existe; forja isolada na entrada não é lavada por reexecutar o teste genuíno do topo"
if ! scenario_ensure_sources_entry "$T" ""; then
  echo "FAIL [37]: check deveria continuar bloqueando depois de ensure — a entrada forjada (tests/no.test.mjs) nunca reproduz nada e não pode virar 'observed' por reexecutar o topo em vez dela"
  exit 1
fi
EV37="$T/.forge/specs/active/bug-tamper37/evidence/red/red-evidence.json"
status37="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).entries[0].status)" "$EV37")"
[ "$status37" = "pending" ] || { echo "FAIL [37]: entries[0].status deveria voltar a 'pending' depois do ensure reexecutar a própria declaração forjada, achou '$status37'"; exit 1; }
out37="$(FORGE_ROOT="$T" bash "$CR" check bug-tamper37 2>&1)"
grep -qi "adulterado" <<<"$out37" && { echo "FAIL [37]: depois do ensure, topo e entries[0] devem estar em acordo (self-heal) — check não deveria mais citar adulteração; achou: $out37"; exit 1; }
echo "OK [37]"

echo "[38] MUTAÇÃO (sandbox) — desfazer a correção do [37] (ensure volta a replayar o topo com entries[] presente) faz [37] deixar de bloquear a forja isolada"
run_mutation "38" 's/if \(Array\.isArray\(data\.entries\)\) \{\n    const entry = entries\[0\];\n    const view = projectEntryToFlat\(data\.change_id, entry\);\n    const result = await runReplay\(\{ root, evidence: view, timeoutS \}\);\n    const persisted = persistReplayResult\(ev, data, result, \{ id: entry\.id \}\);\n    console\.log\(`OK ensure — replay executado \(verdict: \$\{result\.verdict\}, status: \$\{persisted\.data\.status\}\)`\);\n    return;\n  \}\n\n  \/\/ legado de verdade \(sem `entries\[\]` no arquivo bruto\): o topo é a ÚNICA fonte\.\n  const result = await runReplay\(\{ root, evidence: data, timeoutS \}\);\n  const persisted = persistReplayResult\(ev, data, result\);/const result = await runReplay({ root, evidence: data, timeoutS }); const persisted = persistReplayResult(ev, data, result);/s' scenario_ensure_sources_entry

scenario_legacy_no_fixfiles_waivable() { # scenario_legacy_no_fixfiles_waivable <root> <suffix>
  # MEDIUM da correção da #139 — legado ESCRITO À MÃO, sem `entries[]` e sem a chave `fix_files`,
  # não pode ser "adulterado" para sempre por um falso positivo de topMatchesProjection
  # (`null` do topo ausente vs `[]` normalizado da projeção). Um waive válido tem de destravar.
  local root="$1" suffix="$2"
  local id="bug-legacy-nofix$suffix"
  FORGE_ROOT="$root" bash "$root/.forge/scripts/spec-new.sh" "$id" --type bugfix --scale 1 >/dev/null 2>&1 || return 1
  local ev="$root/.forge/specs/active/$id/evidence/red/red-evidence.json"
  node -e "
const fs = require('fs');
const d = {
  schema: 'red-evidence/v1',
  change_id: '$id',
  status: 'pending',
  test_path: 'tests/legacy$suffix.test.mjs',
  test_id: 'legacy-case$suffix',
  command: 'node --test tests/legacy$suffix.test.mjs',
  failure_pattern: 'AssertionError'
};
fs.writeFileSync(process.argv[1], JSON.stringify(d, null, 2) + '\n');
" "$ev"

  set +e
  local out1 rc1
  out1="$(FORGE_ROOT="$root" bash "$root/.forge/scripts/check-red-first.sh" check "$id" 2>&1)"; rc1=$?
  set -e
  [ "$rc1" -ne 0 ] || return 1
  grep -qi "adulterado" <<<"$out1" && return 1

  FORGE_ROOT="$root" bash "$root/.forge/scripts/check-red-first.sh" waive "$id" --reason external-unreproducible >/dev/null 2>&1 || return 1

  set +e
  local out2 rc2
  out2="$(FORGE_ROOT="$root" bash "$root/.forge/scripts/check-red-first.sh" check "$id" 2>&1)"; rc2=$?
  set -e
  [ "$rc2" -eq 0 ]
}

echo "[39] MEDIUM — legado sem fix_files não é falso-adulterado; waive válido chega a check rc 0"
if ! scenario_legacy_no_fixfiles_waivable "$T" ""; then
  echo "FAIL [39]: legado sem entries[]/fix_files deveria ser PENDING normal (não adulterado) e, depois de um waive válido, check deveria sair rc 0"
  exit 1
fi
echo "OK [39]"

echo "[40] MUTAÇÃO (sandbox) — remover a guarda '!Array.isArray(data.entries) -> sem 2ª fonte' de topMatchesProjection faz [39] voltar a bloquear o legado sem fix_files mesmo depois do waive válido"
run_mutation "40" 's/export function topMatchesProjection\(data, entries\) \{\n  if \(!entries\.length\) return true;\n  if \(!Array\.isArray\(data\.entries\)\) return true;/export function topMatchesProjection(data, entries) {\n  if (!entries.length) return true;/s' scenario_legacy_no_fixfiles_waivable "red-evidence.mjs"

echo "OK"
