#!/usr/bin/env node
// kb-cli — orquestra a busca unificada sobre o conhecimento acumulado (/forge:kb). Chamado por
// kb.sh, que resolve as duas raízes (lib/forge-root.sh) e as passa como argumentos.
//
// Duas camadas, um pipeline. A camada LEXICAL (BM25 + entidades + links, fundidos por RRF) importa
// só `node:*` e módulos do próprio harness, e é o default: funciona sem nada instalado. A camada
// SEMÂNTICA (embeddings densos + re-rank por cross-encoder, locais) é código do harness carregado por
// `import()` dinâmico só quando `.forge/kb/semantic/installed.json` existe e `--lexical` não foi
// pedido; qualquer falha nela vira modo lexical com o motivo na primeira linha, nunca erro.
//
// Saída: resultado em stdout; avisos (reconstrução, vetores faltando, progresso) em stderr.
//
// Uso: kb-cli.mjs <build|query|status|eval|semantic> --doc-root <dir> --state-root <dir> [args]
import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync, realpathSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { collect, fingerprint, quickFingerprint } from './kb-corpus.mjs';
import { createHash } from 'node:crypto';
import { buildIndex, serializeIndex, attachTexts, bm25, entityMatch, toDocRanks, INDEX_FORMAT } from './kb-lexical.mjs';
import { neutralize } from './untrusted-render.mjs';
import { rrf, propagateLinks, combineRerank, WEIGHTS, RRF_K, LINK_ALPHA, LINK_TOP, RERANK_K, RERANK_FORMULA } from './kb-fuse.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const SNIPPET_MAX = 240;
const TOP_DEFAULT = 8;
const TOP_MAX = 50;

const USAGE = `uso: kb.sh build [--lexical]
       kb.sh query "<texto>" [--top N] [--json] [--lexical] [--no-rerank]
       kb.sh status [--json]
       kb.sh eval <arquivo.json> [--json] [--lexical]
       kb.sh semantic install|remove|status`;

class UsageError extends Error {}
const warn = (m) => process.stderr.write(`kb: ${m}\n`);

function parseArgs(argv) {
  const a = { _: [], top: TOP_DEFAULT, json: false, lexical: false, noRerank: false, docRoot: null, stateRoot: null };
  for (let i = 0; i < argv.length; i++) {
    const x = argv[i];
    if (x === '--doc-root') a.docRoot = argv[++i];
    else if (x === '--state-root') a.stateRoot = argv[++i];
    else if (x === '--json') a.json = true;
    else if (x === '--lexical') a.lexical = true;
    else if (x === '--no-rerank') a.noRerank = true;
    else if (x === '--top') {
      const v = argv[++i];
      if (!/^\d+$/.test(v ?? '') || Number(v) < 1 || Number(v) > TOP_MAX) throw new UsageError(`--top exige inteiro entre 1 e ${TOP_MAX} (recebido: ${v ?? 'nada'})`);
      a.top = Number(v);
    } else if (x.startsWith('--')) throw new UsageError(`flag desconhecida: ${x}`);
    else a._.push(x);
  }
  if (!a.docRoot) throw new UsageError('--doc-root ausente (kb.sh resolve a raiz)');
  a.stateRoot = a.stateRoot || a.docRoot;
  return a;
}

const kbDir = (a) => join(a.docRoot, '.forge/kb');
const indexPath = (a) => join(kbDir(a), 'index.json');
const textsPath = (a) => join(kbDir(a), 'texts.bin');
// A camada semântica mora na raiz de ESTADO (checkout principal), compartilhada pelas worktrees:
// runtime e modelos (~420 MB) e o cache de vetores (endereçado pelo conteúdo do trecho) são pagos uma
// vez por máquina. O índice lexical é por branch e mora na raiz de documentos.
const semanticDir = (a) => join(a.stateRoot, '.forge/kb/semantic');

function writeAtomic(p, data) {
  mkdirSync(dirname(p), { recursive: true });
  const tmp = `${p}.tmp-${process.pid}`;
  writeFileSync(tmp, data);
  renameSync(tmp, p);
}

function build(a) {
  const roots = { docRoot: a.docRoot, stateRoot: a.stateRoot };
  const quick = quickFingerprint(roots);
  const { docs, skipped } = collect(roots);
  const { index: idx, texts } = buildIndex(docs, quick);
  writeAtomic(textsPath(a), texts);
  writeAtomic(indexPath(a), serializeIndex(idx));
  return { idx, skipped };
}

// loadIndex: reconstrói se ausente, ilegível, de outro formato ou defasado em relação às fontes. A
// impressão rápida (stat) evita reler o corpus a cada consulta; se ela divergir, a de conteúdo decide.
export function indexState(a, idx) {
  if (!idx || idx.format !== INDEX_FORMAT) return idx ? 'defasado' : 'ausente';
  const roots = { docRoot: a.docRoot, stateRoot: a.stateRoot };
  if (idx.quick_fingerprint && idx.quick_fingerprint === quickFingerprint(roots)) return 'atual';
  return idx.fingerprint === fingerprint(collect(roots).docs) ? 'atual-conteudo' : 'defasado';
}
function readIndex(a) {
  let idx; try { idx = JSON.parse(readFileSync(indexPath(a), 'utf8')); } catch { return null; }
  let texts; try { texts = readFileSync(textsPath(a)); } catch { return null; }
  if (createHash('sha256').update(texts).digest('hex') !== idx.texts_sha256) return null;
  return attachTexts(idx, texts);
}
function loadIndex(a) {
  const idx = readIndex(a);
  const st = indexState(a, idx);
  if (st === 'atual') return { idx, rebuilt: false };
  if (st === 'atual-conteudo') {
    // fontes iguais em conteúdo, só o stat mudou (ex.: git checkout): regrava a impressão rápida para a
    // próxima consulta voltar ao caminho barato.
    idx.quick_fingerprint = quickFingerprint({ docRoot: a.docRoot, stateRoot: a.stateRoot });
    try { writeAtomic(indexPath(a), serializeIndex(idx)); } catch { /* otimização */ }
    return { idx, rebuilt: false };
  }
  warn(st === 'ausente' ? 'índice ausente — construindo o índice lexical' : 'índice defasado em relação às fontes — reconstruindo o índice lexical');
  return { idx: build(a).idx, rebuilt: true };
}

// Camada semântica: nunca lança para fora. Devolve {sem} ou {reason}.
async function loadSemantic(a) {
  if (a.lexical) return { reason: 'desativada por --lexical' };
  if (!existsSync(join(semanticDir(a), 'installed.json'))) return { reason: 'camada semântica não instalada' };
  try {
    const mod = await import(pathToFileURL(join(HERE, 'kb-semantic.mjs')).href);
    const r = await mod.loadSemantic(semanticDir(a), join(HERE, 'kb-pins'), join(kbDir(a), 'vectors.bin'));
    return r.ok ? { sem: r.semantic } : { reason: `falha ao carregar: ${r.reason}` };
  } catch (e) {
    return { reason: `falha ao carregar: ${firstLine(e)}` };
  }
}
const firstLine = (e) => String(e && e.message ? e.message : e).split('\n')[0];

const docOrder = (fusedRows) => fusedRows.map((r) => r.doc);

// search: devolve {mode, mode_reason, results:[...]} — results com explicação por canal.
async function search(a, idx, q, semState) {
  const ch = {};
  const best = new Map();
  const note = (name, m) => { ch[name] = new Map([...m].map(([d, v]) => [d, v.rank])); for (const [d, v] of m) if (!best.has(d) || name === 'bm25') best.set(d, v.chunk); };
  note('bm25', toDocRanks(idx, bm25(idx, q)));
  note('entities', toDocRanks(idx, entityMatch(idx, q)));
  const mode = 'lexical'; const reason = semState.reason || null;
  const fused = propagateLinks(rrf(ch), idx.links);
  const rerank = null;
  const finalFused = fused;
  const byDoc = new Map(finalFused.map((r) => [r.doc, r]));
  const order = rerank ? rerank : finalFused.map((r, i) => ({ doc: r.doc, score: null, fusion_rank: i + 1, ce_rank: null, ce_score: null }));
  const results = order.slice(0, a.top).map((o, i) => {
    const f = byDoc.get(o.doc);
    const ci = best.get(o.doc) ?? idx.chunks.findIndex((c) => c.doc === o.doc);
    const c = idx.chunks[ci] || { heading: '', line: 1 };
    return {
      rank: i + 1,
      doc: o.doc,
      heading: c.heading,
      line: c.line,
      score: f.score,
      channels: f.channels,
      rerank: rerank ? { ce_score: o.ce_score, ce_rank: o.ce_rank, fusion_rank: o.fusion_rank, final_score: o.score } : null,
      snippet: snippet(ci >= 0 ? idx.chunkText(ci) : ''),
    };
  });
  return { mode, mode_reason: mode === 'semantic' ? null : reason, rerank_applied: !!rerank, results };
}

// Trecho exibido como dado: neutralize() de lib/untrusted-render.mjs (crases triplas trocadas e linhas
// com forma de comando `/<palavra>:` prefixadas — prefixar, nunca apagar), uma linha só, ≤ SNIPPET_MAX.
export function snippet(text) {
  let s = neutralize(text);
  s = s.replace(/[ \t]*\n[ \t]*/g, ' ⏎ ').replace(/\s+/g, ' ').trim();
  return s.length > SNIPPET_MAX ? `${s.slice(0, SNIPPET_MAX - 1)}…` : s;
}

const CH_LABEL = { bm25: 'bm25', entities: 'entidades', links: 'links', vector: 'vetor' };
function printText(out) {
  const lines = [out.mode === 'semantic' ? 'modo: semantic' : `modo: lexical (${out.mode_reason})`];
  if (!out.results.length) lines.push('nenhum resultado');
  for (const r of out.results) {
    lines.push(`${r.rank}. ${r.doc}${r.heading ? ` — ${r.heading}` : ''} (linha ${r.line})  rrf=${r.score.toFixed(4)}`);
    const parts = Object.keys(r.channels).sort().map((k) => (k === 'links' ? `links de ${r.channels.links.from.length} resultado(s) (+${r.channels.links.contribution.toFixed(4)})` : `${CH_LABEL[k] || k} #${r.channels[k].rank} (+${r.channels[k].contribution.toFixed(4)})`));
    if (r.rerank && r.rerank.ce_rank) parts.push(`re-rank ce #${r.rerank.ce_rank} (fusão #${r.rerank.fusion_rank})`);
    lines.push(`   canais: ${parts.join(' · ')}`);
    lines.push('   ```text', `   ${r.snippet}`, '   ```');
  }
  process.stdout.write(lines.join('\n') + '\n');
}

async function cmdQuery(a) {
  const q = a._.join(' ').trim();
  if (!q) throw new UsageError('consulta vazia');
  const { idx, rebuilt } = loadIndex(a);
  const semState = await loadSemantic(a);
  const out = await search(a, idx, q, semState);
  if (a.json) process.stdout.write(JSON.stringify({ format: 1, query: q, mode: out.mode, mode_reason: out.mode_reason, rebuilt, weights: WEIGHTS, rrf_k: RRF_K, links: { alpha: LINK_ALPHA, top: LINK_TOP }, rerank: { applied: out.rerank_applied, k: RERANK_K, formula: RERANK_FORMULA }, results: out.results }) + '\n');
  else printText(out);
}

async function cmdBuild(a) {
  const t = Date.now();
  const { idx, skipped } = build(a);
  const sk = Object.entries(skipped).map(([k, v]) => `${k}=${v}`).join(' ');
  process.stdout.write(`OK índice lexical: ${idx.docs.length} documentos, ${idx.chunks.length} trechos (${((Date.now() - t) / 1000).toFixed(1)}s)${sk ? ` — pulados: ${sk}` : ''}\n`);
  const semState = await loadSemantic(a);
  process.stdout.write(`vetores não calculados: ${semState.reason || 'camada semântica sem cálculo de vetores'}\n`);
}

function cmdStatus(a) {
  const { docs, skipped } = collect({ docRoot: a.docRoot, stateRoot: a.stateRoot });
  const st0 = indexState(a, readIndex(a)); const state = st0 === 'atual-conteudo' ? 'atual' : st0;
  const kinds = {}; for (const d of docs) kinds[d.kind] = (kinds[d.kind] || 0) + 1;
  const semantic = existsSync(join(semanticDir(a), 'installed.json')) ? 'instalada' : 'não instalada';
  if (a.json) { process.stdout.write(JSON.stringify({ format: 1, index: state, docs: docs.length, kinds, skipped, semantic }) + '\n'); return; }
  process.stdout.write(`índice: ${state} — ${docs.length} documentos (${Object.entries(kinds).sort().map(([k, v]) => `${k}=${v}`).join(' ')})\n`);
  if (Object.keys(skipped).length) process.stdout.write(`pulados: ${Object.entries(skipped).map(([k, v]) => `${k}=${v}`).join(' ')}\n`);
  process.stdout.write(`camada semântica: ${semantic}${semantic === 'não instalada' ? ' (opcional; ative com kb.sh semantic install)' : ''}\n`);
}

// eval: métricas em nível de documento, por modo disponível.
export function metrics(queries, rankedLists) {
  const rel = (d, gold) => gold.some((g) => d.toLowerCase().includes(String(g).toLowerCase()));
  const n = queries.length || 1;
  const hit = (k) => rankedLists.filter((r, i) => r.slice(0, k).some((d) => rel(d, queries[i].gold))).length / n;
  const mrr = rankedLists.reduce((acc, r, i) => { const p = r.findIndex((d) => rel(d, queries[i].gold)); return acc + (p < 0 ? 0 : 1 / (p + 1)); }, 0) / n;
  return { hit1: hit(1), hit5: hit(5), hit10: hit(10), mrr };
}

async function cmdEval(a) {
  const file = a._[0];
  if (!file) throw new UsageError('eval exige o arquivo de consultas');
  let queries;
  try { queries = JSON.parse(readFileSync(file, 'utf8')); } catch (e) { throw new UsageError(`arquivo de consultas ilegível: ${firstLine(e)}`); }
  if (!Array.isArray(queries) || !queries.length || queries.some((x) => typeof x?.q !== 'string' || !Array.isArray(x.gold) || !x.gold.length)) throw new UsageError('arquivo de consultas: esperado [{q, gold: [..]}] não vazio');
  const { idx } = loadIndex(a);
  const ids = idx.docs.map((d) => d.id.toLowerCase());
  const orphan = queries.filter((x) => !x.gold.some((g) => ids.some((d) => d.includes(String(g).toLowerCase()))));
  if (orphan.length) { process.stderr.write(`kb: ERRO consulta sem documento relevante no corpus: ${orphan.map((x) => JSON.stringify(x.q)).join(', ')}\n`); process.exitCode = 1; return; }
  const BROAD = 10;
  const fragCounts = queries.map((x) => Object.fromEntries(x.gold.map((g) => [g, ids.filter((d) => d.includes(String(g).toLowerCase())).length])));
  queries.forEach((x, i) => { for (const [g, n] of Object.entries(fragCounts[i])) if (n > BROAD) warn(`fragmento de gold ${JSON.stringify(g)} da consulta ${JSON.stringify(x.q)} casa mais de ${BROAD} documentos (${n}) — rótulo largo infla hit@k`); });
  const runs = {};
  const top = { ...a, top: TOP_MAX };
  runs.bm25 = queries.map((x) => [...toDocRanks(idx, bm25(idx, x.q)).keys()]);
  const lex = []; for (const x of queries) lex.push((await search({ ...top, noRerank: true }, idx, x.q, { reason: 'eval' })).results.map((r) => r.doc));
  runs.lexical = lex;
  const semReason = (await loadSemantic(a)).reason || 'camada semântica sem avaliação';
  const out = Object.fromEntries(Object.entries(runs).map(([k, v]) => [k, metrics(queries, v)]));
  if (a.json) { process.stdout.write(JSON.stringify({ format: 1, queries: queries.length, semantic: semReason ? `indisponível: ${semReason}` : 'avaliada', gold_matches: fragCounts, modes: out }) + '\n'); return; }
  process.stdout.write(`consultas: ${queries.length}${semReason ? ` — camada semântica: ${semReason}` : ''}\n`);
  for (const [k, m] of Object.entries(out)) process.stdout.write(`${k.padEnd(16)} hit@1=${m.hit1.toFixed(3)} hit@5=${m.hit5.toFixed(3)} hit@10=${m.hit10.toFixed(3)} MRR=${m.mrr.toFixed(3)}\n`);
}

async function cmdSemantic(a) {
  const sub = a._[0];
  if (sub === 'install') { const m = await import(pathToFileURL(join(HERE, 'kb-install.mjs')).href); process.exitCode = await m.install(semanticDir(a), join(HERE, 'kb-pins')); return; }
  if (sub === 'remove') {
    const { rmSync } = await import('node:fs');
    rmSync(semanticDir(a), { recursive: true, force: true });
    process.stdout.write('OK camada semântica removida — a busca volta ao modo lexical\n');
    return;
  }
  if (sub === 'status') {
    if (!existsSync(join(semanticDir(a), 'installed.json'))) { process.stdout.write('camada semântica: não instalada\n'); return; }
    const mod = await import(pathToFileURL(join(HERE, 'kb-integrity.mjs')).href);
    const r = mod.status(semanticDir(a), join(HERE, 'kb-pins'));
    process.stdout.write(r.lines.join('\n') + '\n');
    if (!r.ok) process.exitCode = 1;
    return;
  }
  throw new UsageError(`subcomando semantic desconhecido: ${sub ?? '(nenhum)'}`);
}

async function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  try {
    const a = parseArgs(rest);
    if (cmd === 'build') await cmdBuild(a);
    else if (cmd === 'query') await cmdQuery(a);
    else if (cmd === 'status') cmdStatus(a);
    else if (cmd === 'eval') await cmdEval(a);
    else if (cmd === 'semantic') await cmdSemantic(a);
    else throw new UsageError(`subcomando desconhecido: ${cmd ?? '(nenhum)'}`);
  } catch (e) {
    if (e instanceof UsageError) { process.stderr.write(`kb: ${e.message}\n${USAGE}\n`); process.exitCode = 2; return; }
    process.stderr.write(`kb: erro: ${firstLine(e)}\n`); process.exitCode = 1;
  }
}

// Executa só quando chamado como script (não quando importado por um teste). Compara caminhos reais:
// /tmp e /var/folders são symlinks no macOS, e o argv[1] chega com o caminho lógico.
const invokedAsScript = (() => { try { return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url)); } catch { return false; } })();
if (invokedAsScript) await main();
