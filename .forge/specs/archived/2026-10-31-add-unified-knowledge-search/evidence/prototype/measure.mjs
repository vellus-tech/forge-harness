// Medição descartável: corpus, BM25/entidades/links/RRF, embeddings (potion pure-JS, e5 via ORT-web WASM) e re-rank (cross-encoder WASM).
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative } from 'node:path';
import { createRequire } from 'node:module';

const ROOT = process.argv[2];
const MODELS = process.argv[3];
const MODE = process.argv[4] || 'all';
const t0 = Date.now();
const lap = (m) => console.error(`[${((Date.now() - t0) / 1000).toFixed(1)}s] ${m}`);

// ---------- corpus ----------
function walk(d, acc = []) { if (!existsSync(d)) return acc; for (const e of readdirSync(d, { withFileTypes: true })) { const p = join(d, e.name); if (e.isDirectory()) walk(p, acc); else if (/\.(md|ya?ml|txt)$/.test(e.name)) acc.push(p); } return acc; }
const docs = [];
const files = [...walk(join(ROOT, '.forge/product/current')), ...walk(join(ROOT, '.forge/specs/archived')), ...walk(join(ROOT, 'docs/plans')), join(ROOT, 'CHANGELOG.md')];
for (const f of files) docs.push({ id: relative(ROOT, f), text: readFileSync(f, 'utf8') });
const ledger = JSON.parse(readFileSync(join(ROOT, '.forge/ledger/ledger.json'), 'utf8')).entries;
for (const e of ledger) docs.push({ id: `ledger:${e.id}`, text: `${e.id} ${e.title}\n${JSON.stringify(Object.fromEntries(Object.entries(e).filter(([k]) => !['id', 'title'].includes(k))))}` });
for (const l of readFileSync(join(ROOT, '.forge/liaison/forge-harness/log/forge-harness.jsonl'), 'utf8').split('\n').filter(Boolean)) { const m = JSON.parse(l); if (m.trust === 'self') docs.push({ id: `liaison:${m.msg_id}`, text: `${m.subject}\n${m.body || ''}` }); }
lap(`docs=${docs.length} bytes=${docs.reduce((a, d) => a + d.text.length, 0)}`);

// chunk: by markdown heading, cap ~1500 chars
const chunks = [];
for (const d of docs) {
  const parts = d.text.split(/\n(?=#{1,3} )/);
  for (const p of parts) for (let i = 0; i < p.length; i += 1500) { const t = p.slice(i, i + 1500).trim(); if (t.length > 20) chunks.push({ doc: d.id, text: t }); }
}
lap(`chunks=${chunks.length}`);

// ---------- BM25 ----------
const STOP = new Set('a o os as de da do das dos e em no na nos nas um uma para por com que se nao não ao à é the of and to in for is on it be as by or this that with from are'.split(' '));
const norm = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
const stem = (w) => w.length > 5 ? w.replace(/(coes|cao|mente|idade|ados|adas|ado|ada|ando|endo|ar|er|ir|es|s)$/, '') : w;
const tok = (s) => norm(s).split(/[^a-z0-9]+/).filter((w) => w.length > 1 && !STOP.has(w)).map(stem);
const df = new Map(); const ctoks = chunks.map((c) => { const t = tok(c.doc + ' ' + c.text); for (const w of new Set(t)) df.set(w, (df.get(w) || 0) + 1); return t; });
const avgdl = ctoks.reduce((a, t) => a + t.length, 0) / ctoks.length; const N = chunks.length;
const tf = ctoks.map((t) => { const m = new Map(); for (const w of t) m.set(w, (m.get(w) || 0) + 1); return m; });
function bm25(q) { const qt = [...new Set(tok(q))]; const s = []; for (let i = 0; i < N; i++) { let sc = 0; for (const w of qt) { const f = tf[i].get(w); if (!f) continue; const idf = Math.log(1 + (N - df.get(w) + 0.5) / (df.get(w) + 0.5)); sc += idf * f * 2.2 / (f + 1.2 * (0.25 + 0.75 * ctoks[i].length / avgdl)); } if (sc > 0) s.push([i, sc]); } return s.sort((a, b) => b[1] - a[1]); }
lap('bm25 ready');

// ---------- entities ----------
const ENT = /\b(LDG-\d{4}|ADR-?\d{4}|REQ-[A-Z0-9-]+|TASK-\d+|w\d{2,3}[a-z-]*|[a-z0-9-]+\.(?:sh|mjs|md|ya?ml|json)|\/forge:[a-z-]+|[A-Z]{2,}[A-Z0-9_]*)\b/g;
const ents = (s) => new Set([...s.matchAll(ENT)].map((m) => m[1].toLowerCase()));
const cents = chunks.map((c) => ents(c.text + ' ' + c.doc)); const edf = new Map(); for (const e of cents) for (const x of e) edf.set(x, (edf.get(x) || 0) + 1);
function entityRank(q) { const qe = ents(q); if (!qe.size) return []; const s = []; cents.forEach((e, i) => { let sc = 0; for (const x of qe) if (e.has(x)) sc += Math.log(N / edf.get(x)); if (sc > 0) s.push([i, sc]); }); return s.sort((a, b) => b[1] - a[1]); }

// ---------- links (doc graph) ----------
const docIds = docs.map((d) => d.id); const adj = new Map(docIds.map((d) => [d, new Set()]));
const ldgDoc = new Map(ledger.map((e) => [e.id, `ledger:${e.id}`]));
const baseNames = new Map(); for (const d of docIds) { const b = d.split('/').pop(); if (b && !/^(proposal|design|tasks|requirements|manifest|approvals|verification|analysis|README|CHANGELOG)\./.test(b)) baseNames.set(b, d); }
for (const d of docs) { for (const m of d.text.matchAll(/LDG-\d{4}/g)) { const t = ldgDoc.get(m[0]); if (t && t !== d.id) { adj.get(d.id).add(t); adj.get(t).add(d.id); } } for (const m of d.text.matchAll(/[\w.-]+\.md/g)) { const t = baseNames.get(m[0]); if (t && t !== d.id) { adj.get(d.id).add(t); adj.get(t).add(d.id); } } }
lap(`links edges=${[...adj.values()].reduce((a, s) => a + s.size, 0) / 2}`);

// ---------- fusion helpers ----------
const toDocRank = (chunkRank) => { const seen = new Map(); for (const [i] of chunkRank) { const d = chunks[i].doc; if (!seen.has(d)) seen.set(d, seen.size + 1); } return seen; };
function rrf(rankMaps, k = 60, w = []) { const s = new Map(); rankMaps.forEach((m, mi) => { const wt = w[mi] ?? 1; for (const [d, r] of m) s.set(d, (s.get(d) || 0) + wt / (k + r)); }); return [...s].sort((a, b) => b[1] - a[1]).map(([d]) => d); }
function linkRank(seedDocs, pool = null) { const s = new Map(); seedDocs.slice(0, 10).forEach((d, r) => { const deg = (adj.get(d) || new Set()).size; for (const n of adj.get(d) || []) s.set(n, (s.get(n) || 0) + 1 / ((r + 1) * Math.log(2 + deg) * Math.log(2 + adj.get(n).size))); }); return new Map([...s].filter(([d]) => !pool || pool.has(d)).sort((a, b) => b[1] - a[1]).map(([d], i) => [d, i + 1])); }

// ---------- tokenizers ----------
function unigram(tokPath) {
  const j = JSON.parse(readFileSync(tokPath, 'utf8')); const vocab = new Map(); let maxLen = 0;
  j.model.vocab.forEach(([p, sc], id) => { vocab.set(p, [id, sc]); maxLen = Math.max(maxLen, p.length); });
  const unk = j.model.unk_id; const special = Object.fromEntries((j.added_tokens || []).map((t) => [t.content, t.id]));
  return { special, encode(text) { const out = []; for (const w of text.normalize('NFKC').split(/\s+/).filter(Boolean)) { const s = '▁' + w; const n = s.length; const best = new Array(n + 1).fill(-Infinity); const back = new Array(n + 1); best[0] = 0; for (let i = 0; i < n; i++) { if (best[i] === -Infinity) continue; let any = false; for (let L = 1; L <= Math.min(maxLen, n - i); L++) { const v = vocab.get(s.slice(i, i + L)); if (v) { any = true; const sc = best[i] + v[1]; if (sc > best[i + L]) { best[i + L] = sc; back[i + L] = [i, v[0]]; } } } if (!any || best[i + 1] === -Infinity) { const sc = best[i] - 100; if (sc > best[i + 1]) { best[i + 1] = sc; back[i + 1] = [i, unk]; } } } const ids = []; for (let k = n; k > 0; k = back[k][0]) ids.push(back[k][1]); out.push(...ids.reverse()); } return out; } };
}
function wordpiece(tokPath) {
  const j = JSON.parse(readFileSync(tokPath, 'utf8')); const v = j.model.vocab; const unk = v['[UNK]'];
  return { encode(text) { const out = []; for (const w of norm(text).split(/\s+|(?=[^\p{L}\p{N}])|(?<=[^\p{L}\p{N}])/u).filter((x) => x && x.trim())) { let i = 0; const ids = []; while (i < w.length) { let e = w.length, id = null; while (e > i) { const sub = (i ? '##' : '') + w.slice(i, e); if (sub in v) { id = v[sub]; break; } e--; } if (id === null) { ids.length = 0; ids.push(unk); break; } ids.push(id); i = e; } out.push(...ids); } return out; } };
}

// ---------- static (model2vec) embedder: pure JS ----------
function potion(dir, tokType) {
  const buf = readFileSync(join(dir, 'model.safetensors')); const hl = Number(buf.readBigUInt64LE(0)); const h = JSON.parse(buf.slice(8, 8 + hl).toString()); const [V, D] = h.embeddings.shape; const off = 8 + hl + h.embeddings.data_offsets[0];
  const W = new Float32Array(buf.buffer.slice(buf.byteOffset + off, buf.byteOffset + off + V * D * 4));
  const tk = tokType === 'unigram' ? unigram(join(dir, 'tokenizer.json')) : wordpiece(join(dir, 'tokenizer.json'));
  return { D, embed(text) { const ids = tk.encode(text).slice(0, 512); const v = new Float32Array(D); for (const id of ids) for (let k = 0; k < D; k++) v[k] += W[id * D + k]; let n = 0; for (let k = 0; k < D; k++) n += v[k] * v[k]; n = Math.sqrt(n) || 1; for (let k = 0; k < D; k++) v[k] /= n; return v; } };
}
const cos = (a, b) => { let s = 0; for (let k = 0; k < a.length; k++) s += a[k] * b[k]; return s; };

// ---------- ORT-web ----------
const require_ = createRequire(join(process.argv[5] || '.', 'x.js'));
async function ort() { const o = await import(require_.resolve('onnxruntime-web')); o.env.wasm.numThreads = Number(process.env.ORT_THREADS || 4); return o; }
async function e5(dir) {
  const o = await ort(); const sess = await o.InferenceSession.create(join(dir, 'model.onnx'), { executionProviders: ['wasm'] }); const tk = unigram(join(dir, 'tokenizer.json'));
  return { async embed(text, prefix) { const ids = [0, ...tk.encode(prefix + text).slice(0, 254), 2]; const L = ids.length; const feeds = { input_ids: new o.Tensor('int64', BigInt64Array.from(ids.map(BigInt)), [1, L]), attention_mask: new o.Tensor('int64', new BigInt64Array(L).fill(1n), [1, L]) }; if (sess.inputNames.includes('token_type_ids')) feeds.token_type_ids = new o.Tensor('int64', new BigInt64Array(L), [1, L]); const r = await sess.run(feeds); const h = r.last_hidden_state; const D = h.dims[2]; const v = new Float32Array(D); for (let t = 0; t < L; t++) for (let k = 0; k < D; k++) v[k] += h.data[t * D + k]; let n = 0; for (let k = 0; k < D; k++) n += v[k] * v[k]; n = Math.sqrt(n); for (let k = 0; k < D; k++) v[k] /= n; return v; } };
}
async function crossEncoder(dir) {
  const o = await ort(); const sess = await o.InferenceSession.create(join(dir, 'model.onnx'), { executionProviders: ['wasm'] }); const tk = unigram(join(dir, 'tokenizer.json'));
  return { async score(q, p) { const a = tk.encode(q).slice(0, 64); const b = tk.encode(p).slice(0, 380); const ids = [0, ...a, 2, 2, ...b, 2]; const L = ids.length; const feeds = { input_ids: new o.Tensor('int64', BigInt64Array.from(ids.map(BigInt)), [1, L]), attention_mask: new o.Tensor('int64', new BigInt64Array(L).fill(1n), [1, L]) }; if (sess.inputNames.includes('token_type_ids')) feeds.token_type_ids = new o.Tensor('int64', new BigInt64Array(L), [1, L]); const r = await sess.run(feeds); return r[sess.outputNames[0]].data[0]; } };
}

// ---------- eval ----------
const Q = JSON.parse(readFileSync(new URL('./queries.json', import.meta.url), 'utf8'));
const hitAt = (ranked, gold, k) => ranked.slice(0, k).some((d) => gold.some((g) => d.toLowerCase().includes(g.toLowerCase())));
const mrr = (ranked, gold) => { const i = ranked.findIndex((d) => gold.some((g) => d.toLowerCase().includes(g.toLowerCase()))); return i < 0 ? 0 : 1 / (i + 1); };
const report = (name, rankedPerQ) => { const h1 = rankedPerQ.filter((r, i) => hitAt(r, Q[i].gold, 1)).length, h5 = rankedPerQ.filter((r, i) => hitAt(r, Q[i].gold, 5)).length, h10 = rankedPerQ.filter((r, i) => hitAt(r, Q[i].gold, 10)).length; const m = rankedPerQ.reduce((a, r, i) => a + mrr(r, Q[i].gold), 0) / Q.length; console.log(`${name.padEnd(34)} hit@1=${(h1 / Q.length).toFixed(3)} hit@5=${(h5 / Q.length).toFixed(3)} hit@10=${(h10 / Q.length).toFixed(3)} MRR=${m.toFixed(3)}`); return rankedPerQ; };

const LW_E = Number(process.env.WE ?? 0.5), LW_L = Number(process.env.WL ?? 0.25);
const lex = Q.map((q) => { const b = toDocRank(bm25(q.q)); const e = toDocRank(entityRank(q.q)); return { b, e }; });
let tq = Date.now(); const base = Q.map((q, i) => { const { b, e } = lex[i]; const seed = rrf([b, e]); const pool = process.env.POOL ? new Set(seed.slice(0, Number(process.env.POOL))) : null; return rrf([b, e, linkRank(seed, pool)], 60, [1, LW_E, LW_L]); }); lap(`lexical queries avg ${((Date.now() - tq) / Q.length).toFixed(1)}ms`);
report('BM25 only', lex.map(({ b }) => [...b.keys()]));
report('RRF(BM25+entities)', lex.map(({ b, e }) => rrf([b, e], 60, [1, LW_E])));
report('RRF(BM25+entities+links) [default]', base);

async function semantic(name, embedChunk, embedQuery) {
  let t = Date.now(); const V = []; for (const c of chunks) V.push(await embedChunk(c.doc + '\n' + c.text)); lap(`${name}: embedded ${chunks.length} chunks in ${((Date.now() - t) / 1000).toFixed(1)}s`);
  const vecRanks = []; for (const q of Q) { const qv = await embedQuery(q.q); vecRanks.push(toDocRank(V.map((v, i) => [i, cos(v, qv)]).sort((a, b) => b[1] - a[1]).slice(0, 200))); }
  report(`${name} vector only`, vecRanks.map((m) => [...m.keys()]));
  return report(`RRF(default + ${name})`, Q.map((q, i) => { const { b, e } = lex[i]; const seed = rrf([b, e, vecRanks[i]], 60, [1, LW_E, 1]); const pool = process.env.POOL ? new Set(seed.slice(0, Number(process.env.POOL))) : null; return rrf([b, e, vecRanks[i], linkRank(seed, pool)], 60, [1, LW_E, 1, LW_L]); }));
}
const want = (m) => MODE === 'all' || MODE.split(',').includes(m);
let ce = null; if (want('ce')) ce = await crossEncoder(join(MODELS, 'ce'));
async function rerank(name, fused) {
  if (!ce) return; let t = Date.now(); const out = [];
  for (let i = 0; i < Q.length; i++) { const top = fused[i].slice(0, 10); const scored = []; for (const d of top) { const cs = chunks.filter((c) => c.doc === d); const rq = toDocRank(bm25(Q[i].q).filter(([j]) => chunks[j].doc === d)); const best = cs.length ? (rq.size ? chunks[bm25(Q[i].q).find(([j]) => chunks[j].doc === d)[0]] : cs[0]) : null; scored.push([d, best ? await ce.score(Q[i].q, best.text) : -99]); } const ceRank = new Map(scored.sort((a, b) => b[1] - a[1]).map(([d], r) => [d, r + 1])); const fr = new Map(top.map((d, r) => [d, r + 1])); out.push([...rrf([ceRank, fr], 5), ...fused[i].slice(10)]); }
  lap(`${name} rerank avg ${((Date.now() - t) / Q.length).toFixed(0)}ms/query`); report(`${name} + CE rerank`, out);
}
await rerank('default', base);
if (want('p8')) { const m = potion(join(MODELS, 'p8'), 'wordpiece'); const r = await semantic('potion-base-8M', async (t) => m.embed(t), async (t) => m.embed(t)); await rerank('potion-base-8M', r); }
if (want('pm')) { let t = Date.now(); const m = potion(join(MODELS, 'pm'), 'unigram'); lap(`pm load ${Date.now() - t}ms`); const r = await semantic('potion-multilingual-128M', async (x) => m.embed(x), async (x) => m.embed(x)); await rerank('potion-multilingual-128M', r); }
if (want('e5')) { const m = await e5(join(MODELS, 'e5')); const r = await semantic('multilingual-e5-small(int8,wasm)', (x) => m.embed(x, 'passage: '), (x) => m.embed(x, 'query: ')); await rerank('e5', r); }
lap(`rss=${(process.memoryUsage().rss / 1e6).toFixed(0)}MB`);
