import { readFileSync } from 'node:fs';
import { bm25, entityMatch, toDocRanks } from './kb-lexical.mjs';
import { rrf } from './kb-fuse.mjs';
import { metrics } from './kb-cli.mjs';
const idx = JSON.parse(readFileSync(process.argv[2] + '/.forge/kb/index.json', 'utf8'));
for (const f of process.argv.slice(3)) {
const Q = JSON.parse(readFileSync(f, 'utf8'));
const pre = Q.map((x) => ({ b: new Map([...toDocRanks(idx, bm25(idx, x.q))].map(([d, v]) => [d, v.rank])), e: new Map([...toDocRanks(idx, entityMatch(idx, x.q))].map(([d, v]) => [d, v.rank])) }));
console.log(f.split('/').pop());
for (const alpha of [0, 0.05, 0.1, 0.2, 0.4]) for (const top of [10, 30]) {
  const R = pre.map(({ b, e }) => { const fused = rrf({ bm25: b, entities: e }, { bm25: 1, entities: 0.2 }); const sc = new Map(fused.map((r) => [r.doc, r.score])); const T = new Set(fused.slice(0, top).map((r) => r.doc));
    const out = fused.map((r) => { let s = r.score; const nb = idx.links[r.doc] || []; let add = 0; for (const n of nb) if (T.has(n)) add += sc.get(n) / Math.sqrt(nb.length * (idx.links[n] || []).length); return [r.doc, s + alpha * add]; });
    return out.sort((a, b) => b[1] - a[1]).map(([d]) => d); });
  const m = metrics(Q, R); console.log(`alpha=${alpha} top=${top}`.padEnd(20), Object.entries(m).map(([k, v]) => `${k}=${v.toFixed(3)}`).join(' '));
}}
