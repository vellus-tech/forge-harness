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

// hasFlagWithValue: distingue "--id não foi passado" de "--id foi passado sem valor utilizável"
// (achado MEDIUM da correção da #139) — `parseFlags` sozinho não faz essa distinção: com `--id`
// como último token, ou seguido de outra flag (`--id --test-path ...`), `flags.id` vira
// `undefined` OU o texto da flag seguinte, e o chamador degradava em silêncio para o caminho
// "sem --id" (record atualiza a entrada errada) em vez de recusar. Vazio (`--id ""`) é o mesmo
// buraco com outro sintoma (cria uma entrada com id vazio).
function hasFlagWithValue(argv, name, value) {
  if (!argv.includes(`--${name}`)) return true; // flag ausente — nada a validar aqui
  return typeof value === 'string' && value.length > 0 && !value.startsWith('--');
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
// Achado LOW da correção da #139: `recorded_at`/`status` sozinhos não bastam — um artefato
// legado escrito à mão (w106/w144, plano L5 §6.4) pode ter test_path/test_id/command/
// failure_pattern/fix_files preenchidos com `recorded_at:null` e `status:'pending'` (nunca
// passou pelo `record` da CLI, que sempre carimba `recorded_at`), e o predicado antigo tratava
// esse conteúdo real como scaffold vazio, descartando-o no primeiro `record --id`.
// LEGACY_SIGNAL_FIELDS — subconjunto de ENTRY_SCALAR_FIELDS que só um `record` de verdade (CLI
// ou escrito à mão, w106/w144) preenche. Exclui deliberadamente 'reproduces': o scaffold do
// `templates/bugfix/red-evidence.json` já grava `"reproduces": "bugfix.md §1"` como default
// ESTÁTICO em todo change bugfix novo, então esse campo sozinho não distingue "nunca gravado" de
// "gravado" — usá-lo aqui faria todo scaffold recém-criado, mesmo sem nenhum record, parecer
// legado real (regressão do próprio cenário [5], scaffold vazio).
const LEGACY_SIGNAL_FIELDS = ENTRY_SCALAR_FIELDS.filter((k) => k !== 'reproduces');

function isRealLegacyData(data) {
  if (!data) return false;
  if (data.recorded_at || (data.status && data.status !== 'pending')) return true;
  if (Array.isArray(data.fix_files) && data.fix_files.length) return true;
  return LEGACY_SIGNAL_FIELDS.some((k) => data[k] !== undefined && data[k] !== null && data[k] !== '');
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

// upsertSingleEntry: mesma regra de endereçamento do `record` sem `--id`, reaproveitada por
// `replay`/`ensure`/`waive` (achados HIGH da correção da #139) para o caso 0/1 entrada — sem
// `opts.id`, só podem operar sem ambiguidade quando o change tem 0 ou 1 entrada; com 2+, ESCOLHER
// uma (a primeira, a última) seria o mesmo tipo de furo que a quimera do `record` sem `--id`: um
// replay/waive que parece ter resolvido "o" defeito na verdade escreveu em cima de uma entrada
// que pode não ser a que a rule está cobrando — por isso `refused:true` em vez de adivinhar.
// Enquanto o arquivo não tiver `entries[]` (JSON legado, formato de entrada única, em voo em
// centenas de changes de consumidores — nunca migrado por um `record` desta Onda), devolve
// `legacy:true` e o CALLER mantém o caminho de escrita no topo tal como antes desta Onda:
// `ensure`/`waive` não introduzem `entries[]` em arquivo legado só por rodar — isso seria uma
// migração de formato silenciosa disparada por toda chamada de rotina de /forge:verify e
// /forge:archive, fora do escopo desta issue (o escopo dela é consertar `record`).
//
// opts.id (achado HIGH-2 da correção da #139, iteração 3): quando declarado, endereça QUALQUER
// entrada por id, inclusive com 2+ registradas — usado por `cmdReplay`/`cmdWaive` (endereçamento
// explícito do usuário) e por `cmdEnsure` (endereçamento por iteração própria, um id de cada
// vez). Sem `opts` (ou `opts.id` ausente/null), o comportamento é EXATAMENTE o de antes desta
// correção (0/1 entrada, recusa com 2+) — retrocompatível com todo chamador existente.
export function upsertSingleEntry(prevData, changeId, patchEntry, opts) {
  const data = prevData || {};
  if (!Array.isArray(data.entries)) return { legacy: true, refused: false };
  const entries = data.entries.map((e) => ({ ...emptyEntry(e && e.id), ...e }));
  const wantId = opts && opts.id != null ? opts.id : undefined;
  let idx;
  if (wantId !== undefined) {
    idx = entries.findIndex((e) => e.id === wantId);
    if (idx < 0) {
      const ids = entries.map((e) => e.id ?? '(sem id)').join(', ') || '(nenhuma)';
      return { legacy: false, refused: true, reason: `id não encontrado: ${wantId} (entradas: ${ids})`, count: entries.length };
    }
  } else if (entries.length >= 2) {
    const ids = entries.map((e) => e.id ?? '(sem id)').join(', ');
    return { legacy: false, refused: true, reason: `${entries.length} entradas registradas (${ids})`, count: entries.length };
  } else {
    idx = entries.length === 1 ? 0 : -1;
  }
  const target = idx >= 0 ? { ...entries[idx] } : emptyEntry(null);
  const merged = patchEntry(target);
  const nextEntries = entries.slice();
  if (idx >= 0) nextEntries[idx] = merged; else nextEntries.push(merged);
  return { legacy: false, refused: false, data: buildDocument(changeId, nextEntries) };
}

// resolveTargetEntry: endereçamento COMPARTILHADO por replay/ensure/waive (achado HIGH-2 da
// correção da #139, iteração 3) — decide, ANTES de qualquer efeito colateral (rodar o motor de
// replay, criar deferral/ledger), qual entrada de entries[] um comando explícito (replay/waive;
// ensure resolve por ITERAÇÃO própria, não por isto) afeta: por --id quando declarado, ou a
// única entrada quando o change tem 0/1 (fluxo retrocompatível, sem --id). Nunca cria entrada —
// isso é exclusivo de `record`. `legacy:true` sinaliza arquivo sem entries[] (nunca migrado por
// um record desta Onda) — o caller mantém o caminho de escrita no topo tal como antes desta Onda.
function resolveTargetEntry(data, flags) {
  if (!Array.isArray(data.entries)) return { legacy: true };
  const entries = entriesOf(data);
  const hasId = flags.id !== undefined;
  if (hasId) {
    const idx = entries.findIndex((e) => e.id === flags.id);
    if (idx < 0) {
      const ids = entries.map((e) => e.id ?? '(sem id)').join(', ') || '(nenhuma)';
      return { refused: true, reason: `id não encontrado: ${flags.id} (entradas: ${ids})` };
    }
    return { entry: entries[idx] };
  }
  if (entries.length >= 2) {
    const ids = entries.map((e) => e.id ?? '(sem id)').join(', ');
    return { refused: true, reason: `--id é obrigatório — este change tem ${entries.length} entradas registradas (${ids}); declare a qual defeito este comando se refere` };
  }
  if (entries.length === 1) return { entry: entries[0] };
  return { refused: true, reason: 'nenhuma entrada registrada — rode /forge:red record antes' };
}

// projectEntryToFlat: projeta UMA entrada de entries[] no formato "achatado" que
// lib/red-replay.mjs consome (os mesmos campos que hoje moram no topo) — permite rodar o motor
// de replay sobre uma entrada ESPECÍFICA (não só sobre a projeção de entries[0] que o topo
// sempre mostra), condição necessária para replay/ensure por entrada (achado HIGH-2).
function projectEntryToFlat(changeId, entry) {
  const doc = { schema: 'red-evidence/v1', change_id: changeId, status: entry.status };
  for (const k of ENTRY_SCALAR_FIELDS) doc[k] = entry[k] ?? null;
  doc.fix_files = Array.isArray(entry.fix_files) ? entry.fix_files : [];
  doc.waiver = entry.waiver ?? null;
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
  } else if (entries.length === 1 && entries[0].id != null) {
    // achado HIGH da correção da #139 (iteração 3): com 1 ÚNICA entrada, mas já NOMEADA (tem
    // id declarado), record sem --id era tão ambíguo quanto com 2+ e sobrescrevia em silêncio —
    // o mesmo sintoma da issue original, disfarçado por só precisar de uma entrada anterior com
    // id em vez de duas. O desenho do plano ("record sobre id já declarado sem --id explícito
    // recusa") vale a partir de 1 entrada nomeada, não só a partir de 2.
    throw new Error(`--id é obrigatório — a entrada registrada já tem id declarado (${entries[0].id}); use --id ${entries[0].id} para atualizá-la, ou um --id novo para declarar outro defeito`);
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

// applyRenameNull: achado MEDIUM da correção da #139 (iteração 3) — depois que uma segunda
// entrada é declarada (`record --id B`), a PRIMEIRA (sem id — legado migrado, ou o fluxo comum
// "primeiro record sem --id, segundo com --id") fica permanentemente inendereçável: nenhum
// comando aceita `--id null` para se referir a ela. A correção NÃO bloqueia a criação da segunda
// entrada enquanto a primeira não tiver nome (isso quebraria o próprio fluxo de migração de
// legado do cenário [4] — o legado tem que poder ganhar uma SEGUNDA entrada nomeada mantendo a
// primeira como id:null) — em vez disso, oferece uma operação dedicada e aditiva para nomear a
// entrada sem id, sempre que ela for a ÚNICA do change (nomear com 2+ entradas já presentes seria
// ambíguo por natureza — qual delas é "a" sem id, se mais de uma puder ficar sem id).
export function applyRenameNull(prevData, changeId, newId) {
  const entries = entriesOf(prevData || {});
  if (entries.length !== 1 || entries[0].id !== null) {
    throw new Error(`--rename-null só se aplica quando o change tem exatamente 1 entrada e ela não tem id declarado (achou ${entries.length} entrada(s)${entries.length === 1 ? `, id já declarado: ${entries[0].id}` : ''})`);
  }
  const renamed = { ...entries[0], id: newId };
  return { data: buildDocument(changeId, [renamed]), entry: renamed };
}

function cmdRecord(changeDir, argv) {
  requireBugfix(changeDir);
  const ev = requireEvidence(changeDir);
  const f = parseFlags(argv);

  if (argv.includes('--rename-null')) {
    if (!hasFlagWithValue(argv, 'rename-null', f['rename-null'])) {
      console.log('FAIL (--rename-null exige um valor não vazio e que não comece com "--")');
      process.exit(1);
    }
    let renameResult;
    try {
      renameResult = applyRenameNull(ev.data, ev.data.change_id, f['rename-null']);
    } catch (e) {
      console.log(`FAIL (${e.message})`);
      process.exit(1);
    }
    writeJsonAtomic(ev.path, renameResult.data);
    console.log(`OK rename-null — a entrada sem id agora é ${renameResult.entry.id}`);
    return;
  }

  if (!hasFlagWithValue(argv, 'id', f.id)) {
    console.log('FAIL (--id exige um valor não vazio e que não comece com "--" — sem isso o record degradaria em silêncio para o caminho sem --id)');
    process.exit(1);
  }

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
//
// Achado HIGH da correção da #139: até aqui a escrita ia sempre para o TOPO (`{ ...data, ... }`),
// nunca para `entries[]`. Isso "funcionava" enquanto o topo era a única fonte, mas desde que
// `record` passou a projetar o topo a partir de `entries[0]` (`buildDocument`), um replay
// observado ficava só no topo — e o PRÓXIMO `record` (em qualquer id) reconstrói o topo a partir
// de `entries[0]`, que nunca foi tocado, apagando em silêncio o que o replay acabara de gravar
// (base_commit, classification, excerpt, o replay inteiro). A correção usa `upsertSingleEntry`
// para escrever na ENTRADA (0 ou 1 entrada: a mesma regra de endereçamento do `record` sem
// `--id`) e reconstrói o documento com `buildDocument`, para que o topo seja sempre a projeção —
// nunca uma escrita paralela que `entries[]` desconhece. Com 2+ entradas e SEM opts.id, devolve
// `{ refused:true }` (fail-closed) — ver `upsertSingleEntry`; o caller decide a mensagem. Achado
// HIGH-2 da correção da #139 (iteração 3): `opts.id`, quando declarado por `cmdReplay`/`cmdEnsure`
// (endereçamento explícito ou por iteração), permite gravar em QUALQUER entrada, não só na
// única de um change com 0/1.
function persistReplayResult(ev, data, result, opts) {
  // base_strategy/revert_patch são resetados aqui e só voltam a ser gravados no ramo 'observed'
  // abaixo — sem isso, um replay que falha DEPOIS de um replay 'observed' anterior deixaria
  // base_strategy/revert_patch de uma tentativa antiga (e potencialmente inválida) lingerindo na
  // evidência, confundindo quem ler o JSON. replayed_at/replay_head permanecem como metadado
  // INFORMATIVO (quando o último replay rodou, sobre qual HEAD) — nenhum caminho de decisão em
  // check-red-first.mjs lê esses dois campos para concluir 'observed' (Onda D: a prova mora na
  // execução — cache local ou o próprio replay ao vivo — não no artefato).
  // graft_from acompanha base_strategy no reset: é o par que explica de onde veio a árvore base,
  // e um graft_from remanescente de uma tentativa anterior descreveria uma base que não é a desta.
  const patch = { replayed_at: nowIso(), replay_head: result.replay_head || null, base_strategy: null, revert_patch: null, graft_from: null };

  if (result.verdict === 'observed') {
    patch.status = 'observed';
    patch.base_commit = result.base_commit || null;
    patch.base_strategy = result.base_strategy || null;
    patch.classification = result.classification || null;
    patch.excerpt = truncate(result.excerpt);
    patch.excerpt_sha256 = sha256(patch.excerpt);
    patch.base_result = result.base_result || 'failed';
    patch.revert_patch = result.revert_patch || null;
    patch.graft_from = result.graft_from || null;
  } else if (result.verdict === 'not-possible') {
    patch.status = 'not-possible';
    if (result.diagnostic) {
      patch.excerpt = truncate(result.diagnostic.excerpt);
      patch.excerpt_sha256 = sha256(patch.excerpt);
      patch.classification = result.diagnostic.classification || null;
    }
  } else {
    // fail — nunca deixa um status:'observed' falso na árvore; volta para pending com o
    // diagnóstico da tentativa anexado (útil para o próximo replay).
    patch.status = 'pending';
    patch.base_result = result.base_result || null;
    if (result.base) patch.base_strategy = result.base.strategy || null;
    if (result.diagnostic) {
      patch.excerpt = truncate(result.diagnostic.excerpt);
      patch.excerpt_sha256 = sha256(patch.excerpt);
      patch.classification = result.diagnostic.classification || null;
    }
  }

  const upsert = upsertSingleEntry(data, data.change_id, (entry) => ({ ...entry, ...patch }), opts);
  if (upsert.refused) return { refused: true, count: upsert.count, reason: upsert.reason };
  const updated = upsert.legacy ? { ...data, ...patch } : upsert.data;
  writeJsonAtomic(ev.path, updated);
  return { data: updated };
}

// cmdReplay — achado HIGH-2 da correção da #139 (iteração 3): agora aceita `--id <id>` para
// endereçar qual entrada de entries[] este replay observa. Sem --id, só 0/1 entrada é aceitável
// (fluxo retrocompatível, idêntico ao de antes da correção). A resolução (`resolveTargetEntry`)
// roda ANTES de chamar o motor de replay (achado LOW da correção — sem isso, um change
// ambíguo pagava worktree+execução de teste só para descartar o resultado no fim).
async function cmdReplay(changeDir, argv) {
  const man = requireBugfix(changeDir);
  const ev = requireEvidence(changeDir);
  const data = ev.data;
  const f = parseFlags(argv);

  if (!hasFlagWithValue(argv, 'id', f.id)) {
    console.log('FAIL (--id exige um valor não vazio e que não comece com "--")');
    process.exit(1);
  }

  const resolved = resolveTargetEntry(data, f);
  if (resolved.refused) {
    console.log(`FAIL (replay recusado — ${resolved.reason}. Nada foi escrito.)`);
    process.exit(1);
  }
  const legacyMode = !!resolved.legacy;
  const view = legacyMode ? data : projectEntryToFlat(data.change_id, resolved.entry);
  if (!view.test_path || !view.command) {
    console.log('FAIL (test_path/command ausentes — rode /forge:red record antes de replay)');
    process.exit(1);
  }

  const timeoutS = f.timeout ? parseInt(f.timeout, 10) : undefined;
  const result = await runReplay({ root, evidence: view, timeoutS });
  const persisted = persistReplayResult(ev, data, result, legacyMode ? undefined : { id: resolved.entry.id });
  if (persisted.refused) {
    // inalcançável em condições normais — resolveTargetEntry já filtrou a ambiguidade acima;
    // mantido fail-closed (defesa em profundidade) contra uma corrida entre a resolução e a
    // escrita (outro processo alterando entries[] no meio do replay, que é CARO — roda teste
    // de verdade).
    console.log(`FAIL (replay recusado — ${persisted.reason || 'a entrada mudou entre a resolução e a escrita'}. Nada foi escrito.)`);
    process.exit(1);
  }

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
//
// Achado HIGH-2 da correção da #139 (iteração 3): `ensure` é chamado sem nenhum `--id` pelos
// três chamadores acima — nenhum deles sabe quais ids existem. Por isso, com 2+ entradas, ensure
// não recusa mais por ambiguidade: ITERA cada entrada não dispensada (`status !== 'waived'`) e
// roda o motor de replay sobre ELA (projeção própria via `projectEntryToFlat`, nunca sobre o
// topo), persistindo o veredito na própria entrada via `upsertSingleEntry(..., { id })`. Sem
// isto, um change com 2+ defeitos declarados nunca chegava a `verified`/`archived` — /forge:verify
// e /forge:archive chamam só `ensure`, que recusava (fail-closed) por ambiguidade, e a única
// saída documentada (replay/waive por entrada) também recusava: travamento permanente que só um
// editor manual do JSON destravava.
async function cmdEnsure(changeDir, argv) {
  const man = readManifest(changeDir);
  if (!man) { console.log('FAIL (manifest.yaml ausente/ilegível)'); process.exit(1); }
  if (man.type !== 'bugfix') { console.log(`OK ensure (n/a — type: ${man.type})`); return; }

  const ev = loadRedEvidence(changeDir);
  if (!ev.exists) { console.log('OK ensure (evidência ausente — nada a garantir; check-red-first cobre o item 1)'); return; }
  if (ev.errors.length) { console.log(`OK ensure (evidência inválida: ${ev.errors.join('; ')} — check-red-first cobre)`); return; }
  const data = ev.data;

  const f = parseFlags(argv);
  const timeoutS = f.timeout ? parseInt(f.timeout, 10) : undefined;

  // achado da revisão da correção (iteração 3, medido contra o w106 [3-FORJA]): uma forja que
  // edita só os escalares do TOPO (nunca `entries[]` — o vetor de ataque original, anterior à
  // própria #139) deixaria de ser pega se o replay de uma entrada ÚNICA passasse a testar a
  // projeção da entrada em vez do topo — a entrada real (nunca tocada pela forja) continuaria
  // legitimamente 'observed' e o loop reescreveria o topo a partir DELA, mascarando a forja em
  // vez de expor. Por isso, com 0 ou 1 entrada, `ensure` continua testando o TOPO (`data`),
  // exatamente como antes desta correção — idêntico ao caminho legado. Só com 2+ entradas o topo
  // é ambíguo (só reflete entries[0]) e não há alternativa a testar cada entrada pela sua própria
  // projeção.
  if (data.status === 'waived') { console.log('OK ensure — status: waived (nada a replayar)'); return; }
  if (!Array.isArray(data.entries) || data.entries.length <= 1) {
    const result = await runReplay({ root, evidence: data, timeoutS });
    const persisted = persistReplayResult(ev, data, result);
    console.log(`OK ensure — replay executado (verdict: ${result.verdict}, status: ${persisted.data.status})`);
    return;
  }

  const entries = entriesOf(data);

  let current = data;
  let replayed = 0;
  let skippedWaived = 0;
  let skippedIncomplete = 0;
  for (const entry of entries) {
    if (entry.status === 'waived') { skippedWaived++; continue; }
    const view = projectEntryToFlat(current.change_id, entry);
    if (!view.test_path || !view.command) { skippedIncomplete++; continue; }
    // eslint-disable-next-line no-await-in-loop -- cada entrada é UM teste real, deliberadamente
    // sequencial (mesmo espírito do "sem cache" da Onda E: custo proporcional, nunca paralelo
    // demais para o replay efêmero em worktree git que lib/red-replay.mjs já usa).
    const result = await runReplay({ root, evidence: view, timeoutS });
    const idOpt = entry.id != null ? { id: entry.id } : undefined;
    const persisted = persistReplayResult(ev, current, result, idOpt);
    if (persisted.refused) {
      // inalcançável em condições normais (o id vem da própria leitura de entries[] acima) —
      // mantido fail-closed contra uma corrida com outro processo escrevendo entries[] no meio
      // do laço.
      console.log(`OK ensure — entrada ${entry.id ?? '(sem id)'}: replay recusado (${persisted.reason}); nada escrito para ela`);
      continue;
    }
    current = persisted.data;
    replayed++;
  }
  console.log(`OK ensure — ${replayed} entrada(s) replayada(s), ${skippedWaived} dispensada(s), ${skippedIncomplete} incompleta(s) (status do topo: ${current.status})`);
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
