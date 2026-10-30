// Calibração do modo semântico com os rascunhos de produção e a camada instalada de verdade.
// Uso: node grid-sem.mjs <raiz> <queries.json> [--only "<WV>,<prop>,<rep>,<k>,<wce>"]
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { bm25, entityMatch, toDocRanks } from './kb-lexical.mjs';
import { rrf, propagateLinks } from './kb-fuse.mjs';
import { metrics } from './kb-cli.mjs';
import { loadSemantic } from './kb-semantic.mjs';
const HERE = dirname(fileURLToPath(import.meta.url));
const [root, qfile, , only] = process.argv.slice(2);
const idx = JSON.parse(readFileSync(join(root, '.forge/kb/index.json'), 'utf8'));
const Q = JSON.parse(readFileSync(qfile, 'utf8'));
const L = await loadSemantic(join(root, '.forge/kb/semantic'), join(HERE, 'kb-pins'));
if (!L.ok) { console.error('semantic indisponível:', L.reason); process.exit(1); }
const sem = L.semantic;
const pre = [];
for (const x of Q) {
  const b = toDocRanks(idx, bm25(idx, x.q)); const e = toDocRanks(idx, entityMatch(idx, x.q));
  const v = await sem.vectorSearch(idx, x.q);
  pre.push({ q: x.q, b, e, v: v.ranks, qv: v.queryVector, missing: v.missing });
}
console.error('missing vectors (q0):', pre[0].missing);
const rk = (m) => new Map([...m].map(([d, o]) => [d, o.rank]));
const ceCache = new Map();
async function ce(q, ci) { const k = q + '\u0000' + ci; if (!ceCache.has(k)) ceCache.set(k, await sem.crossScore(q, idx.chunks[ci].text)); return ceCache.get(k); }
const fmt = (m) => `hit@1=${m.hit1.toFixed(3)} hit@5=${m.hit5.toFixed(3)} hit@10=${m.hit10.toFixed(3)} MRR=${m.mrr.toFixed(3)}`;
function lexOnly(p, prop) { let f = rrf({ bm25: rk(p.b), entities: rk(p.e) }, { bm25: 1, entities: 0.2 }); if (prop) f = propagateLinks(f, idx.links); return f.map((r) => r.doc); }
function semFused(p, wv, prop) { let f = rrf({ bm25: rk(p.b), entities: rk(p.e), vector: rk(p.v) }, { bm25: 1, entities: 0.2, vector: wv }); if (prop) f = propagateLinks(f, idx.links); return f.map((r) => r.doc); }
async function rerank(p, order, rep, k, wce, K = 10) {
  const top = order.slice(0, K); const sc = new Map();
  for (const d of top) {
    let ci;
    if (rep === 'vector') ci = sem.representative(idx, d, p.q, p.qv, p.b.get(d)?.chunk ?? p.v.get(d)?.chunk);
    else ci = p.b.get(d)?.chunk ?? p.v.get(d)?.chunk ?? idx.chunks.findIndex((c) => c.doc === d);
    sc.set(d, await ce(p.q, ci));
  }
  const ceOrder = [...top].sort((a, b) => sc.get(b) - sc.get(a) || top.indexOf(a) - top.indexOf(b));
  const cr = new Map(ceOrder.map((d, i) => [d, i + 1]));
  const rows = top.map((d, i) => [d, wce / (k + cr.get(d)) + 1 / (k + i + 1), i]);
  rows.sort((a, b) => b[1] - a[1] || a[2] - b[2]);
  return [...rows.map((r) => r[0]), ...order.slice(K)];
}
console.log(`=== ${qfile.split('/').pop()} (${Q.length}) ===`);
console.log('bm25'.padEnd(44), fmt(metrics(Q, pre.map((p) => [...p.b.keys()]))));
console.log('lexical sem links'.padEnd(44), fmt(metrics(Q, pre.map((p) => lexOnly(p, false)))));
console.log('lexical (default)'.padEnd(44), fmt(metrics(Q, pre.map((p) => lexOnly(p, true)))));
console.log('vetor isolado'.padEnd(44), fmt(metrics(Q, pre.map((p) => [...p.v.keys()]))));
const configs = [];
if (only) { const [wv, prop, rep, k, wce] = only.split(','); configs.push({ wv: +wv, prop: prop === '1', rep, k: +k, wce: +wce }); }
else for (const wv of [0.5, 1, 1.5, 2]) for (const prop of [false, true]) configs.push({ wv, prop, rep: null });
for (const c of configs) {
  const fused = pre.map((p) => semFused(p, c.wv, c.prop));
  console.log(`semântico WV=${c.wv} prop=${c.prop ? 1 : 0}`.padEnd(44), fmt(metrics(Q, fused)));
  const reps = only ? [c.rep] : ['vector', 'bm25'];
  const grid = only ? [[c.k, c.wce]] : [[5, 1], [10, 1], [30, 1], [5, 0.5], [10, 0.5], [60, 1]];
  if (!only && !(c.wv === 1 || c.wv === 1.5)) continue;
  for (const rep of reps) for (const [k, wce] of grid) {
    const out = []; for (let i = 0; i < pre.length; i++) out.push(await rerank(pre[i], fused[i], rep, k, wce));
    console.log(`  + re-rank rep=${rep} k=${k} wce=${wce}`.padEnd(44), fmt(metrics(Q, out)));
  }
}
