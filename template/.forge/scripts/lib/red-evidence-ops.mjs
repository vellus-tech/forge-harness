#!/usr/bin/env node
// lib/red-evidence-ops.mjs — orquestração dos subcomandos `record` e `replay` de
// red-evidence.sh (Onda C). `status` e `waive` NÃO vivem aqui: são delegados por
// red-evidence.sh direto a check-red-first.sh (Onda B) — mesma política, uma fonte só.
//
//   record <change-dir> --test-path <p> --command <c> --failure-pattern <p> [--test-id <id>]
//          [--fix-files a,b,c] [--setup-command <c>] [--reproduces <txt>] [--excerpt <txt>]
//     Declara a intenção (test_path/command/failure_pattern/fix_files/...). NUNCA marca
//     status:'observed' — essa transição só acontece via `replay` bem-sucedido (é o ponto
//     central da Onda C: sem replay, a evidência é só uma declaração que o agente pode
//     fabricar). Sempre grava status:'pending' e limpa replayed_at/replay_head (uma nova
//     declaração invalida qualquer replay anterior). failure_pattern é OBRIGATÓRIO (Furo 10 —
//     sem ele, o item 4 da rule nunca é avaliável; opcional era o mesmo que ausente).
//
//   replay <change-dir> [--timeout <segundos>]
//     Chama lib/red-replay.mjs sobre os dados já declarados. Três desfechos:
//       observed     -> grava status/base_commit/base_strategy/classification/excerpt/
//                        excerpt_sha256/base_result/replayed_at/replay_head (Furo 1 — replay_head
//                        é o sha do HEAD no momento do replay; metadado informativo, NENHUM
//                        caminho de decisão o lê — ver Onda E abaixo).
//       fail         -> NUNCA deixa um status:'observed' falso: volta para 'pending' (com o
//                        excerpt/classification da tentativa, para diagnóstico) e imprime o
//                        item da rule que falhou. exit 1.
//       not-possible -> grava status:'not-possible' (não conta como resolvido — check-red-first
//                        Onda B continua bloqueando até /forge:red waive). exit 1.
//
// Onda E (decisão do orquestrador) — elimina o cache local de replay (lib/red-replay-cache.mjs,
// removido): duas rodadas de auditoria mostraram que qualquer atalho de custo baseado em estado
// local (campo do artefato, depois cache local) vira, cedo ou tarde, o alvo que os próprios
// gates passam a exigir para aprovar — inclusive evidência fabricada. A partir desta Onda,
// `ensure` executa o replay SEMPRE, sem cache-check algum: o único atalho é `status: 'waived'`
// (política própria, não observação de Red pendente — ver cmdEnsure). Isso tem custo real (mede
// no comentário de cmdEnsure abaixo) — aceito deliberadamente em troca de eliminar (a) o furo do
// cache versionável em projetos que instalaram o harness antes do patch do .gitignore e (b) o
// livelock relatado quando o cache invalidava por motivo alheio ao conteúdo do teste/correção.
import { readFileSync, existsSync, writeFileSync, renameSync, realpathSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseYamlSubset } from './yaml-lite.mjs';
import { loadRedEvidence, REL_PATH, ENTRY_SCALAR_FIELDS } from './red-evidence.mjs';
import { replay as runReplay } from './red-replay.mjs';

const root = resolve(process.env.FORGE_ROOT || '.');

function readManifest(changeDir) {
  const p = join(resolve(changeDir), 'manifest.yaml');
  if (!existsSync(p)) return null;
  try { return parseYamlSubset(readFileSync(p, 'utf8')); } catch { return null; }
}

function writeJsonAtomic(path, obj) {
  const tmp = `${path}.${process.pid}.tmp`;
  writeFileSync(tmp, JSON.stringify(obj, null, 2) + '\n');
  renameSync(tmp, path);
}

function nowIso() { return new Date().toISOString(); }

function sha256(s) { return createHash('sha256').update(String(s)).digest('hex'); }

function truncate(s, max = 6000) {
  const text = String(s || '');
  return text.length <= max ? text : `…(truncado — ${text.length} chars)…\n${text.slice(-max)}`;
}

function requireBugfix(changeDir) {
  const man = readManifest(changeDir);
  if (!man) { console.log('FAIL (manifest.yaml ausente/ilegível)'); process.exit(1); }
  if (man.type !== 'bugfix') { console.log(`FAIL (red-evidence só se aplica a change type:bugfix, got: ${man.type})`); process.exit(1); }
  return man;
}

function requireEvidence(changeDir) {
  const ev = loadRedEvidence(changeDir);
  if (!ev.exists) { console.log(`FAIL (${REL_PATH} ausente — se este change já existe, rode 'red-evidence.sh init <change-id>' para escaffoldar; para um change novo, use /forge:spec new --type bugfix)`); process.exit(1); }
  if (ev.errors.length) { console.log(`FAIL (${REL_PATH} inválido: ${ev.errors.join('; ')})`); process.exit(1); }
  return ev;
}

function parseFlags(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) { out[a.slice(2)] = argv[i + 1]; i++; }
  }
  return out;
}

// ── entries[] (Onda #139, issue #139) ───────────────────────────────────────────────────────
//
// Causa raiz original: `record` copiava os escalares do TOPO (`{ ...ev.data }`), atribuía campo
// a campo e gravava — um segundo `record` apagava o primeiro, e um `record` parcial herdava
// campos de outro defeito (o `--failure-pattern` sozinho "funcionava" porque test_path/test_id/
// command do defeito anterior já estavam no topo herdado). A partir desta Onda, `record` opera
// sempre sobre `entries[]` — um registro por defeito, endereçado por `id` estável — e os
// escalares do topo passam a ser só uma PROJEÇÃO de `entries[0]`, mantida para leitores antigos
// (check-red-first.mjs, validate-spec.mjs, doctor.sh) que só conhecem o formato de entrada única.

function resolvedEntry(e) { return e.status === 'observed' || e.status === 'waived'; }

function emptyEntry(id) {
  const e = { id: id ?? null, status: 'pending', fix_files: [], waiver: null };
  for (const k of ENTRY_SCALAR_FIELDS) e[k] = null;
  return e;
}

// "evidência gravada" — mesmo predicado do item 3d em check-red-first.mjs (exclui o scaffold
// trivial que /forge:spec new grava para TODO change bugfix: status:'pending', recorded_at:null).
function isRealLegacyData(data) {
  return !!(data && (data.recorded_at || (data.status && data.status !== 'pending')));
}

function extractEntryFromTop(data) {
  const e = { id: null, status: data.status || 'pending' };
  for (const k of ENTRY_SCALAR_FIELDS) e[k] = data[k] ?? null;
  e.fix_files = Array.isArray(data.fix_files) ? data.fix_files : [];
  e.waiver = data.waiver ?? null;
  return e;
}

// entriesOf: migração fail-safe. `entries` já presente -> usa como está (normalizando campos
// ausentes por item). Ausente mas com dado real (J-14, legado em voo em centenas de changes de
// consumidores) -> PRESERVA o legado como entries[0], nunca descarta e nunca recomeça
// `entries:[novo]` (esse seria o próprio defeito da issue, aplicado ao caminho de migração).
// Scaffold trivial (nunca gravado) -> entries vazio, nada a preservar.
function entriesOf(data) {
  if (Array.isArray(data.entries)) return data.entries.map((e) => ({ ...emptyEntry(e && e.id), ...e }));
  if (isRealLegacyData(data)) return [extractEntryFromTop(data)];
  return [];
}

export function deriveTopStatus(entries) {
  if (!entries.length) return 'pending';
  if (entries.length === 1) return entries[0].status;
  if (entries.every(resolvedEntry)) return entries.every((e) => e.status === 'waived') ? 'waived' : 'observed';
  return 'pending';
}

// buildDocument: os escalares do topo são SEMPRE a projeção de entries[0] (a primeira entrada
// declarada — legado migrado, ou o primeiro `record` de um change novo), nunca da entrada
// tocada por último. Isso é o que mantém um leitor antigo (que só lê o topo) vendo exatamente o
// que via antes desta Onda quando o change tem uma única entrada, e vendo de forma estável (não
// "saltando" a cada record de outro defeito) quando o change tem várias.
function buildDocument(changeId, entries) {
  const first = entries[0] || emptyEntry(null);
  const doc = { schema: 'red-evidence/v1', change_id: changeId, status: deriveTopStatus(entries) };
  for (const k of ENTRY_SCALAR_FIELDS) doc[k] = first[k] ?? null;
  doc.fix_files = Array.isArray(first.fix_files) ? first.fix_files : [];
  doc.waiver = first.waiver ?? null;
  doc.entries = entries;
  return doc;
}

// applyRecord: pura (sem I/O) — usada por cmdRecord e pelo PBT do gate w218. Lança Error com a
// mensagem de FAIL em vez de decidir exit code (isso é responsabilidade do caller).
export function applyRecord(prevData, changeId, flags) {
  const entries = entriesOf(prevData || {});
  const hasId = flags.id !== undefined;
  const id = hasId ? flags.id : undefined;

  let idx;
  if (hasId) {
    idx = entries.findIndex((e) => e.id === id);
  } else if (entries.length >= 2) {
    // fail-closed contra quimera: com 2+ entradas já declaradas, um record sem --id é ambíguo —
    // ANTES desta Onda, ele herdava os campos obrigatórios da última entrada gravada e parecia
    // "funcionar" atualizando só o campo passado (o próprio defeito da issue).
    const ids = entries.map((e) => e.id ?? '(sem id)').join(', ');
    throw new Error(`--id é obrigatório — este change já tem ${entries.length} entradas registradas (${ids}); declare a qual defeito este record se refere`);
  } else {
    idx = entries.length === 1 ? 0 : -1;
  }

  const target = idx >= 0 ? { ...entries[idx] } : emptyEntry(hasId ? id : null);

  if (flags['test-path']) target.test_path = flags['test-path'];
  if (flags['test-id']) target.test_id = flags['test-id'];
  if (flags['command']) target.command = flags['command'];
  if (flags['fix-files']) target.fix_files = flags['fix-files'].split(',').map((s) => s.trim()).filter(Boolean);
  if (flags['failure-pattern']) target.failure_pattern = flags['failure-pattern'];
  if (flags['setup-command']) target.setup_command = flags['setup-command'];
  if (flags['reproduces']) target.reproduces = flags['reproduces'];
  if (flags['excerpt']) {
    target.excerpt = flags['excerpt'];
    target.excerpt_sha256 = sha256(flags['excerpt']);
  }

  // Furo 10 — failure_pattern obrigatório: sem ele o item 4 da rule nunca é avaliável (a
  // ausência do campo desliga o gate silenciosamente, indistinguível de "não se aplica").
  // Onda D, item 3 — test_id agora TAMBÉM obrigatório: sem ele, a derivação de base (ancestry)
  // volta a ancorar na criação do ARQUIVO de teste (não do CASO), e os guardas
  // caseExistsInContent/outputMentionsCase do motor de replay (Furo 2) passam por vacuidade —
  // "sem test_id declarado, nada a exigir" deixa de ser uma degradação aceitável quando test_id
  // é obrigatório por contrato.
  if (!target.test_path || !target.test_id || !target.command || !target.failure_pattern) {
    throw new Error('--test-path, --test-id, --command e --failure-pattern são obrigatórios para record');
  }
  if (!Array.isArray(target.fix_files)) target.fix_files = [];

  // record é DECLARAÇÃO, não observação — o replay é quem prova. Uma nova declaração invalida
  // qualquer replay anterior (o teste/comando declarado pode ter mudado).
  target.status = 'pending';
  target.replayed_at = null;
  target.replay_head = null;
  target.recorded_at = nowIso();

  const nextEntries = entries.slice();
  if (idx >= 0) nextEntries[idx] = target; else nextEntries.push(target);

  return { data: buildDocument(changeId, nextEntries), entry: target };
}

function cmdRecord(changeDir, argv) {
  requireBugfix(changeDir);
  const ev = requireEvidence(changeDir);
  const f = parseFlags(argv);

  let result;
  try {
    result = applyRecord(ev.data, ev.data.change_id, f);
  } catch (e) {
    console.log(`FAIL (${e.message})`);
    process.exit(1);
  }

  writeJsonAtomic(ev.path, result.data);
  console.log(`OK record — ${result.entry.test_path} declarado (status: pending — rode /forge:red replay para observar)`);
}

// persistReplayResult: único ponto que TRADUZ um veredito do motor de replay (lib/red-replay.mjs)
// em escrita do red-evidence.json, usado tanto por `replay` (explícito) quanto por `ensure`
// (chamado incondicionalmente por spec-verify.sh/archive-spec.sh/validate-spec.mjs). Fonte
// única — sem isso, os dois caminhos podiam divergir em como gravam status/campos, reabrindo o
// furo de duas fontes de verdade que a Onda C já tinha fechado uma vez.
function persistReplayResult(ev, data, result) {
  // base_strategy/revert_patch são resetados aqui e só voltam a ser gravados no ramo 'observed'
  // abaixo — sem isso, um replay que falha DEPOIS de um replay 'observed' anterior deixaria
  // base_strategy/revert_patch de uma tentativa antiga (e potencialmente inválida) lingerindo na
  // evidência, confundindo quem ler o JSON. replayed_at/replay_head permanecem como metadado
  // INFORMATIVO (quando o último replay rodou, sobre qual HEAD) — nenhum caminho de decisão em
  // check-red-first.mjs lê esses dois campos para concluir 'observed' (Onda D: a prova mora na
  // execução — cache local ou o próprio replay ao vivo — não no artefato).
  // graft_from acompanha base_strategy no reset: é o par que explica de onde veio a árvore base,
  // e um graft_from remanescente de uma tentativa anterior descreveria uma base que não é a desta.
  const updated = { ...data, replayed_at: nowIso(), replay_head: result.replay_head || null, base_strategy: null, revert_patch: null, graft_from: null };

  if (result.verdict === 'observed') {
    updated.status = 'observed';
    updated.base_commit = result.base_commit || null;
    updated.base_strategy = result.base_strategy || null;
    updated.classification = result.classification || null;
    updated.excerpt = truncate(result.excerpt);
    updated.excerpt_sha256 = sha256(updated.excerpt);
    updated.base_result = result.base_result || 'failed';
    updated.revert_patch = result.revert_patch || null;
    updated.graft_from = result.graft_from || null;
  } else if (result.verdict === 'not-possible') {
    updated.status = 'not-possible';
    if (result.diagnostic) {
      updated.excerpt = truncate(result.diagnostic.excerpt);
      updated.excerpt_sha256 = sha256(updated.excerpt);
      updated.classification = result.diagnostic.classification || null;
    }
  } else {
    // fail — nunca deixa um status:'observed' falso na árvore; volta para pending com o
    // diagnóstico da tentativa anexado (útil para o próximo replay).
    updated.status = 'pending';
    updated.base_result = result.base_result || null;
    if (result.base) updated.base_strategy = result.base.strategy || null;
    if (result.diagnostic) {
      updated.excerpt = truncate(result.diagnostic.excerpt);
      updated.excerpt_sha256 = sha256(updated.excerpt);
      updated.classification = result.diagnostic.classification || null;
    }
  }
  writeJsonAtomic(ev.path, updated);
  return updated;
}

async function cmdReplay(changeDir, argv) {
  const man = requireBugfix(changeDir);
  const ev = requireEvidence(changeDir);
  const data = ev.data;
  if (!data.test_path || !data.command) {
    console.log('FAIL (test_path/command ausentes — rode /forge:red record antes de replay)');
    process.exit(1);
  }
  const f = parseFlags(argv);
  const timeoutS = f.timeout ? parseInt(f.timeout, 10) : undefined;

  const result = await runReplay({ root, evidence: data, timeoutS });
  persistReplayResult(ev, data, result);

  if (result.verdict === 'observed') {
    console.log(`OK replay — Red observado (${result.strategy}, base ${result.base_commit ? String(result.base_commit).slice(0, 7) : '?'}) e Green confirmado em HEAD`);
    return;
  }
  if (result.verdict === 'not-possible') {
    console.log(`NOT-POSSIBLE replay — ${result.reason} (grave /forge:red waive --reason <motivo> para prosseguir)`);
    process.exit(1);
  }
  console.log(`FAIL replay (item ${result.ruleItem}) — ${result.reason}`);
  process.exit(1);
}

// cmdEnsure — chamado INCONDICIONALMENTE por spec-verify.sh, pelo pré-flight de archive-spec.sh
// e por validate-spec.mjs (na transição para verified), para todo change type:bugfix. Onda E —
// SEM cache: `ensure` executa o motor de replay de verdade toda vez que roda (o único atalho que
// resta é `status: waived`, que é política própria, não observação de Red pendente de prova).
// O custo é real e proporcional ao teste declarado (um `npx vitest run <arquivo>`/`node --test
// <arquivo>` típico, não a suíte inteira) — pago a cada /forge:verify e a cada /forge:archive.
// Nunca sai com rc≠0 por um veredito desfavorável — quem decide bloquear é check-red-first.mjs,
// que roda em seguida e lê o que ESTA chamada acabou de gravar. rc≠0 aqui é reservado a erro de
// setup genuíno (manifest ilegível).
async function cmdEnsure(changeDir, argv) {
  const man = readManifest(changeDir);
  if (!man) { console.log('FAIL (manifest.yaml ausente/ilegível)'); process.exit(1); }
  if (man.type !== 'bugfix') { console.log(`OK ensure (n/a — type: ${man.type})`); return; }

  const ev = loadRedEvidence(changeDir);
  if (!ev.exists) { console.log('OK ensure (evidência ausente — nada a garantir; check-red-first cobre o item 1)'); return; }
  if (ev.errors.length) { console.log(`OK ensure (evidência inválida: ${ev.errors.join('; ')} — check-red-first cobre)`); return; }
  const data = ev.data;

  // waived é uma política PRÓPRIA (§ Quando o Red não é possível) — não uma observação de Red
  // pendente de prova. Reaplicar a política do waiver (diff real x grafo) é responsabilidade de
  // check-red-first.mjs, não deste comando.
  if (data.status === 'waived') { console.log('OK ensure — status: waived (nada a replayar)'); return; }

  const f = parseFlags(argv);
  const timeoutS = f.timeout ? parseInt(f.timeout, 10) : undefined;

  const result = await runReplay({ root, evidence: data, timeoutS });
  const updated = persistReplayResult(ev, data, result);
  console.log(`OK ensure — replay executado (verdict: ${result.verdict}, status: ${updated.status})`);
}

// ── main guard (mesmo padrão de sync-adapters.mjs, issue #130/w216) ────────────────────────────
// Sem isto, `import { applyRecord } from './red-evidence-ops.mjs'` (o que o PBT do gate w218 e
// qualquer leitor futuro de `applyRecord`/`deriveTopStatus` precisam fazer) executava o bloco de
// dispatch abaixo como efeito colateral do import — `!cmd` seria verdadeiro (import não passa
// argv de CLI) e o processo importador morria com `process.exit(1)` antes de expor coisa alguma.
function isMainModule() {
  try {
    if (!process.argv[1]) return false;
    return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
}

if (isMainModule()) {
  const [, , cmd, changeDir, ...rest] = process.argv;
  if (!cmd || !changeDir) {
    console.log('FAIL (usage: red-evidence-ops.mjs record|replay|ensure <change-dir> [...])');
    process.exit(1);
  }
  switch (cmd) {
    case 'record': cmdRecord(changeDir, rest); break;
    case 'replay': await cmdReplay(changeDir, rest); break;
    case 'ensure': await cmdEnsure(changeDir, rest); break;
    default: console.log(`FAIL (unknown subcommand: ${cmd})`); process.exit(1);
  }
}
