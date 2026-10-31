// Experimento: pool do re-rank = top K do ranking propagado ∪ top N do BM25 ∪ top N do vetor.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
const root = process.argv[2]; const lib = join(root, 'template/.forge/scripts/lib');
const { bm25, entityMatch, toDocRanks, attachTexts } = await import(join(lib, 'kb-lexical.mjs'));
const { rrf, propagateLinks, WEIGHTS } = await import(join(lib, 'kb-fuse.mjs'));
const { metrics } = await import(join(lib, 'kb-cli.mjs'));
const { loadSemantic } = await import(join(lib, 'kb-semantic.mjs'));
const idx = attachTexts(JSON.parse(readFileSync(join(root, '.forge/kb/index.json'), 'utf8')), readFileSync(join(root, '.forge/kb/texts.bin')));
const sem = (await loadSemantic(join(root, '.forge/kb/semantic'), join(lib, 'kb-pins'), join(root, '.forge/kb/vectors.bin'))).semantic;
const rk = (m) => new Map([...m].map(([d, o]) => [d, o.rank]));
const ce = new Map();
for (const f of process.argv.slice(3)) {
  const Q = JSON.parse(readFileSync(f, 'utf8'));
  const res = { lexical: [], 'rr K10': [], 'rr K10+bm3+vec3': [], 'rr K10+bm3': [], 'rr K10+bm1': [] };
  for (const x of Q) {
    const b = toDocRanks(idx, bm25(idx, x.q)), e = toDocRanks(idx, entityMatch(idx, x.q));
    const v = await sem.vectorSearch(idx, x.q);
    res.lexical.push(propagateLinks(rrf({ bm25: rk(b), entities: rk(e) }, WEIGHTS), idx.links).map((r) => r.doc));
    const order = propagateLinks(rrf({ bm25: rk(b), entities: rk(e), vector: rk(v.ranks) }, WEIGHTS), idx.links).map((r) => r.doc);
    const best = new Map([...b].map(([d, o]) => [d, o.chunk])); for (const [d, o] of v.ranks) if (!best.has(d)) best.set(d, o.chunk);
    const score = async (d) => { const k = x.q + '\0' + d; if (!ce.has(k)) ce.set(k, await sem.crossScore(x.q, idx.chunkText(sem.representative(idx, d, x.q, v.queryVector, best.get(d))))); return ce.get(k); };
    const run = async (extra) => {
      const pool = [...new Set([...order.slice(0, 10), ...extra])].sort((a, c) => order.indexOf(a) - order.indexOf(c));
      const sc = new Map(); for (const d of pool) sc.set(d, await score(d));
      const ceOrd = [...pool].sort((a, c) => sc.get(c) - sc.get(a)); const cr = new Map(ceOrd.map((d, i) => [d, i + 1]));
      const rows = pool.map((d) => [d, 1 / (5 + cr.get(d)) + 1 / (5 + order.indexOf(d) + 1), cr.get(d)]).sort((p, q) => q[1] - p[1] || p[2] - q[2]);
      return [...rows.map((r) => r[0]), ...order.filter((d) => !pool.includes(d))];
    };
    const bm = [...b.keys()], vv = [...v.ranks.keys()];
    res['rr K10'].push(await run([]));
    res['rr K10+bm3+vec3'].push(await run([...bm.slice(0, 3), ...vv.slice(0, 3)]));
    res['rr K10+bm3'].push(await run(bm.slice(0, 3)));
    res['rr K10+bm1'].push(await run(bm.slice(0, 1)));
  }
  console.log(`== ${f.split('/').pop()} (${Q.length})`);
  for (const [k, R] of Object.entries(res)) { const m = metrics(Q, R); console.log(`${k.padEnd(18)} hit@1=${m.hit1.toFixed(3)} hit@5=${m.hit5.toFixed(3)} hit@10=${m.hit10.toFixed(3)} MRR=${m.mrr.toFixed(3)}`); }
}
