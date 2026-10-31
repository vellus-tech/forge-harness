import { readFileSync } from 'node:fs';
import { bm25, entityMatch, toDocRanks } from './kb-lexical.mjs';
import { rrf } from './kb-fuse.mjs';
import { metrics } from './kb-cli.mjs';
const idx = JSON.parse(readFileSync(process.argv[2] + '/.forge/kb/index.json', 'utf8'));
const Q = JSON.parse(readFileSync(process.argv[3], 'utf8'));
const pre = Q.map((x) => ({ b: new Map([...toDocRanks(idx, bm25(idx, x.q))].map(([d, v]) => [d, v.rank])), e: new Map([...toDocRanks(idx, entityMatch(idx, x.q))].map(([d, v]) => [d, v.rank])) }));
for (const we of [0.2, 0.5]) for (const alpha of [0.05, 0.1, 0.15]) for (const top of [5, 10]) {
  const R = pre.map(({ b, e }) => { const fused = rrf({ bm25: b, entities: e }, { bm25: 1, entities: we }); const sc = new Map(fused.map((r) => [r.doc, r.score])); const T = fused.slice(0, top).map((r) => r.doc);
    const boost = new Map(); for (const s of T) { const nb = idx.links[s] || []; for (const n of nb) boost.set(n, (boost.get(n) || 0) + sc.get(s) / Math.sqrt(nb.length * (idx.links[n] || []).length)); }
    const all = new Map(sc); for (const [d, v] of boost) all.set(d, (all.get(d) || 0) + alpha * v);
    return [...all].sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1)).map(([d]) => d); });
  const m = metrics(Q, R); console.log(`WE=${we} alpha=${alpha} top=${top}`.padEnd(26), Object.entries(m).map(([k, v]) => `${k}=${v.toFixed(3)}`).join(' '));
}
