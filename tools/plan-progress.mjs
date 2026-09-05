#!/usr/bin/env node
// plan-progress.mjs — placar MEDIDO do plano de resolução de issues e ledger.
//
// O progresso não é marcado no documento do plano: é derivado do estado real — `gh issue list`
// para as issues e `.forge/ledger/ledger.json` para o ledger. Checklist marcada à mão envelhece e
// passa a descrever a intenção de quem a marcou, não o repositório — que é o defeito que este
// plano encontrou no próprio ledger (um P1 entregue ainda aberto, cinco itens invisíveis).
//
// A primeira versão deste script duvidava do estado dos itens e nunca do documento. A revisão
// adversarial a quebrou em três formas, todas com `rc=0` e sem uma linha de erro:
//
//   · ledger ausente ou vazio imprimia "INTEGRIDADE DO LEDGER ok" — e essa linha É o DoD da Onda
//     0, de modo que apagar o ledger satisfazia o DoD. Verdade vacuosa dentro do instrumento
//     escrito para aplicar a lição da issue #49.
//   · trocar o travessão do cabeçalho `## Onda N —` por um traço visualmente idêntico apagava a
//     onda inteira do relatório: o total caiu de 45 para 40 em silêncio. A guarda de vacuidade só
//     via onda que CASOU o regex e ficou sem item; onda que não casa nunca chega a existir.
//   · duas issues abertas ficaram fora do plano e o placar teria impresso 45/45 com elas abertas.
//
// A correção é RECONCILIAÇÃO BIDIRECIONAL. O plano não é o universo — o repositório é. Todo item
// aberto do universo tem de estar em exatamente uma onda, e todo item do plano tem de existir no
// universo. As três formas de quebra acima passam a reprovar por essa mesma checagem, porque
// qualquer uma delas remove item do lado do plano sem removê-lo do lado do repositório.
//
// Uso:
//   node tools/plan-progress.mjs [--plan <arquivo>] [--ledger <arquivo>] [--wave N]
//                                [--json] [--no-network] [--universe <arquivo.json>]
//
//   --universe  fixa o universo em vez de derivá-lo (issues via `gh`, ledger via ledger.json).
//               Formato: {"issues": ["71","72"], "ledger": ["LDG-0013"]}. Serve a teste e a
//               execução offline auditável.
//
// Exit: 0 relatório produzido e reconciliação ok · 1 reconciliação falhou ou ledger não medido
//       · 2 erro de uso, plano ilegível ou ledger inválido.

import { readFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const REPO = 'vellus-tech/forge-harness';

// `resolved` é trabalho entregue. `wont-fix` e `promoted` encerram o item, mas fechá-los é edição
// de JSON — decisão, não entrega. O placar os separa em balde próprio: colapsá-los com trabalho
// feito permitiria declarar uma onda fechada sem uma linha de código.
const DELIVERED = new Set(['resolved']);
const RECLASSIFIED = new Set(['wont-fix', 'promoted']);

let planPath = join(ROOT, 'docs/plans/2026-09-04-plano-resolucao-issues-e-ledger.md');
let ledgerPath = join(ROOT, '.forge/ledger/ledger.json');
let universePath = null, onlyWave = null, asJson = false, network = true;

const die = (msg, code = 2) => { console.error(`FAIL ${msg}`); process.exit(code); };

for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  const next = () => { const v = process.argv[++i]; if (v === undefined) die(`uso: ${a} exige valor`); return v; };
  if (a === '--plan') planPath = next();
  else if (a === '--ledger') ledgerPath = next();
  else if (a === '--universe') universePath = next();
  else if (a === '--wave') onlyWave = String(next());
  else if (a === '--json') asJson = true;
  else if (a === '--no-network') network = false;
  else if (a === '-h' || a === '--help') {
    console.log('uso: node tools/plan-progress.mjs [--plan f] [--ledger f] [--universe f] [--wave N] [--json] [--no-network]');
    process.exit(0);
  } else die(`uso: argumento desconhecido '${a}'`);
}

if (!existsSync(planPath)) die(`plano não encontrado: ${planPath}`);

// ── 1. ondas e identificadores do plano ──────────────────────────────────────────────────────
// Item rastreado é o identificador em NEGRITO dentro de uma seção `## Onda N`. O negrito separa
// item de menção em prosa — o plano cita PRs e dependências no texto, e a primeira versão contou
// um `PR #68` como item da Onda 0.
const plan = readFileSync(planPath, 'utf8');
const waves = [];
for (const sec of plan.split(/^## /m).slice(1)) {
  const head = sec.split('\n', 1)[0];
  const m = head.match(/^Onda\s+(\d+[a-z]?)\s*[—–-]\s*(.+)$/);
  if (!m) continue;
  const body = sec.slice(head.length);
  waves.push({
    id: m[1], title: m[2].trim(),
    issues: [...new Set([...body.matchAll(/\*\*#(\d{1,4})\*\*/g)].map((x) => x[1]))],
    ledger: [...new Set([...body.matchAll(/\*\*(LDG-\d{4})\*\*/g)].map((x) => x[1]))],
    hasDoD: /\*\*DoD/.test(body),
  });
}
if (waves.length === 0) die('nenhuma seção "## Onda N — título" no plano');

const empty = waves.filter((w) => w.issues.length + w.ledger.length === 0).map((w) => w.id);
if (empty.length) die(`onda(s) sem item extraído: ${empty.join(', ')} — o plano mudou de formato?`);

if (onlyWave !== null && !waves.some((w) => w.id === onlyWave)) {
  die(`onda '${onlyWave}' não existe no plano (existem: ${waves.map((w) => w.id).join(', ')})`);
}

// Item em duas ondas é ambiguidade de plano, não detalhe: o placar contaria duas vezes.
const seen = new Map();
for (const w of waves) for (const id of [...w.issues.map((n) => `#${n}`), ...w.ledger]) {
  if (seen.has(id)) die(`item ${id} aparece em duas ondas (${seen.get(id)} e ${w.id})`);
  seen.set(id, w.id);
}

// ── 2. ledger: status + contador de controle ─────────────────────────────────────────────────
// "Não examinei" e "examinei e estava limpo" não podem terminar no mesmo lugar. Ledger ausente,
// vazio ou ilegível é NÃO MEDIDO — nunca "ok".
const ledgerState = new Map();
let ledgerExamined = 0, ledgerNull = 0, ledgerNoStamp = 0, ledgerMeasured = false, ledgerWhy = '';
if (!existsSync(ledgerPath)) {
  ledgerWhy = `arquivo ausente (${ledgerPath})`;
} else {
  let raw;
  try { raw = JSON.parse(readFileSync(ledgerPath, 'utf8')); }
  catch (e) { die(`ledger ilegível: ${ledgerPath} — ${e.message.split('\n')[0]}`); }
  let entries = raw.entries ?? raw;
  if (!Array.isArray(entries)) entries = Object.values(entries);
  for (const e of entries) {
    if (!e || !e.id) continue;
    ledgerExamined++;
    ledgerState.set(e.id, e.status ?? null);
    if (!e.status) ledgerNull++;
    if (e.status === 'resolved' && !e.resolved_at) ledgerNoStamp++;
  }
  if (ledgerExamined === 0) ledgerWhy = 'zero entradas examinadas (ledger vazio)';
  else ledgerMeasured = true;
}

// ── 3. issues: uma chamada, falha propagada a todas ──────────────────────────────────────────
const issueState = new Map();
let issuesMeasured = false, issueWhy = '--no-network';
if (network) {
  try {
    const out = execFileSync('gh', ['issue', 'list', '--repo', REPO, '--state', 'all', '--limit', '1000',
      '--json', 'number,state'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 60000 });
    for (const i of JSON.parse(out)) issueState.set(String(i.number), i.state);
    issuesMeasured = true;
  } catch (e) { issueWhy = (e.stderr?.toString() || e.message || 'erro desconhecido').split('\n')[0]; }
}

// ── 4. o universo: o repositório, não o documento ────────────────────────────────────────────
let universe = null;
if (universePath) {
  if (!existsSync(universePath)) die(`universo não encontrado: ${universePath}`);
  let u;
  try { u = JSON.parse(readFileSync(universePath, 'utf8')); }
  catch (e) { die(`universo ilegível: ${e.message.split('\n')[0]}`); }
  // Universo FORNECIDO reconcilia, mas nunca afirma. Ele é insumo de teste e de execução
  // offline auditável: um `{"issues":[],"ledger":[]}` reconcilia trivialmente, e imprimir a linha
  // de sucesso ali seria o único caminho do script que desliga a checagem ASSERINDO que ela
  // passou — a mesma família de defeito que este instrumento existe para não cometer.
  universe = {
    issues: new Set((u.issues ?? []).map(String)),
    ledger: new Set(u.ledger ?? []),
    issuesKnown: Array.isArray(u.issues), ledgerKnown: Array.isArray(u.ledger),
    provided: true,
  };
} else {
  universe = {
    issues: new Set([...issueState.entries()].filter(([, s]) => s === 'OPEN').map(([n]) => n)),
    ledger: new Set([...ledgerState.entries()].filter(([, s]) => !DELIVERED.has(s) && !RECLASSIFIED.has(s)).map(([id]) => id)),
    issuesKnown: issuesMeasured, ledgerKnown: ledgerMeasured, provided: false,
  };
}

const planIssues = new Set(waves.flatMap((w) => w.issues));
const planLedger = new Set(waves.flatMap((w) => w.ledger));
const orphans = [];   // aberto no repositório, ausente do plano
const phantoms = [];  // no plano, inexistente no universo
if (universe.issuesKnown) {
  for (const n of universe.issues) if (!planIssues.has(n)) orphans.push(`#${n}`);
  for (const n of planIssues) if (!universe.issues.has(n) && issuesMeasured && !issueState.has(n)) phantoms.push(`#${n}`);
}
if (universe.ledgerKnown) {
  for (const id of universe.ledger) if (!planLedger.has(id)) orphans.push(id);
  for (const id of planLedger) if (!universe.ledger.has(id) && !ledgerState.has(id)) phantoms.push(id);
}

// ── 5. placar ────────────────────────────────────────────────────────────────────────────────
const MARK = { delivered: '✓', reclassified: '~', open: '·', unknown: '?' };
const report = [];
for (const w of waves) {
  if (onlyWave !== null && w.id !== onlyWave) continue;
  const items = [];
  for (const n of w.issues) {
    if (!issuesMeasured) items.push({ id: `#${n}`, state: 'unknown', detail: `não medido (${issueWhy})` });
    else if (!issueState.has(n)) items.push({ id: `#${n}`, state: 'unknown', detail: 'inexistente no repositório' });
    else { const s = issueState.get(n); items.push({ id: `#${n}`, state: s === 'CLOSED' ? 'delivered' : 'open', detail: s.toLowerCase() }); }
  }
  for (const id of w.ledger) {
    if (!ledgerMeasured) items.push({ id, state: 'unknown', detail: `não medido (${ledgerWhy})` });
    else if (!ledgerState.has(id)) items.push({ id, state: 'unknown', detail: 'ausente do ledger.json' });
    else {
      const s = ledgerState.get(id);
      const state = DELIVERED.has(s) ? 'delivered' : RECLASSIFIED.has(s) ? 'reclassified' : 'open';
      items.push({ id, state, detail: s ?? 'STATUS NULO' });
    }
  }
  const count = (k) => items.filter((i) => i.state === k).length;
  report.push({ wave: w.id, title: w.title, hasDoD: w.hasDoD, total: items.length, items,
    delivered: count('delivered'), reclassified: count('reclassified'), unknown: count('unknown') });
}

const reconciled = orphans.length === 0 && phantoms.length === 0;
// `--no-network` é cegueira declarada por quem invoca e sai 0. Falha real de medição, não:
// quem lê o código de saída — hook, CI, portão de release — receberia sucesso de uma execução que
// não reconciliou metade do universo. O lado do ledger já se comportava assim; a assimetria era
// o defeito.
const blindToIssues = network && !issuesMeasured;
const rc = (!ledgerMeasured || !reconciled || blindToIssues) ? 1 : 0;

if (asJson) {
  console.log(JSON.stringify({
    plan: planPath, measured_at: new Date().toISOString().slice(0, 10),
    issues_measured: issuesMeasured, ledger_measured: ledgerMeasured, ledger_examined: ledgerExamined,
    ledger_null_status: ledgerNull, ledger_resolved_without_stamp: ledgerNoStamp,
    reconciled, universe_source: universe.provided ? 'fornecido' : 'derivado',
    orphans, phantoms, waves: report,
  }, null, 2));
  process.exit(rc);
}

let tDeliv = 0, tRecl = 0, tTotal = 0, tUnk = 0;
for (const w of report) {
  tDeliv += w.delivered; tRecl += w.reclassified; tTotal += w.total; tUnk += w.unknown;
  const extra = [w.reclassified ? `${w.reclassified} reclassificado` : '', w.unknown ? `${w.unknown} não medido` : '']
    .filter(Boolean).join(', ');
  console.log(`\nOnda ${w.wave} — ${w.title}   [${w.delivered}/${w.total}${extra ? ` · ${extra}` : ''}]${w.hasDoD ? '' : '   ⚠ sem DoD'}`);
  for (const i of w.items) console.log(`  ${MARK[i.state]} ${i.id.padEnd(9)} ${i.detail}`);
}

console.log('\n' + '─'.repeat(74));
console.log(`TOTAL  ${tDeliv}/${tTotal} entregues` +
  (tRecl ? `  ·  ${tRecl} reclassificados (decisão, não entrega)` : '') +
  (tUnk ? `  ·  ${tUnk} NÃO MEDIDOS (não contam como feitos)` : ''));

console.log(`\nRECONCILIAÇÃO  plano × repositório`);
if (!universe.issuesKnown) console.log('  ? issues: universo não medido — a reconciliação de issues não foi feita');
if (!universe.ledgerKnown) console.log('  ? ledger: universo não medido — a reconciliação de ledger não foi feita');
if (orphans.length) console.log(`  ✗ ${orphans.length} aberto(s) no repositório e FORA do plano: ${orphans.join(', ')}`);
if (phantoms.length) console.log(`  ✗ ${phantoms.length} no plano e inexistente(s): ${phantoms.join(', ')}`);
if (reconciled && universe.issuesKnown && universe.ledgerKnown) {
  if (universe.provided) console.log('  ~ reconciliado contra universo FORNECIDO (--universe), não derivado do repositório');
  else console.log('  ✓ todo item aberto está em exatamente uma onda');
}

console.log(`\nINTEGRIDADE DO LEDGER`);
if (!ledgerMeasured) {
  console.log(`  ? NÃO MEDIDO — ${ledgerWhy}`);
  console.log(`    "não examinei" e "examinei e estava limpo" não podem sair iguais; o DoD da Onda 0 não pode ser declarado por aqui.`);
} else if (ledgerNull || ledgerNoStamp) {
  console.log(`  ✗ ${ledgerExamined} entrada(s) examinada(s)`);
  if (ledgerNull) console.log(`    · ${ledgerNull} com status NULO — invisíveis em 'ledger-ops list --status open'`);
  if (ledgerNoStamp) console.log(`    · ${ledgerNoStamp} 'resolved' sem resolved_at — o defeito da issue #78`);
} else {
  console.log(`  ✓ ${ledgerExamined} entrada(s) examinada(s): sem status nulo, sem resolved sem carimbo`);
}

const noDoD = report.filter((w) => !w.hasDoD).map((w) => w.wave);
if (noDoD.length) console.log(`\n⚠ onda(s) sem DoD declarado: ${noDoD.join(', ')}`);
console.log('\nO placar não substitui a suíte: bash tests/run-all.sh');
process.exit(rc);
