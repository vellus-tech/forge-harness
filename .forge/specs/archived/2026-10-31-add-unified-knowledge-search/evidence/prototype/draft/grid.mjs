import { readFileSync } from 'node:fs';
import { bm25, entityMatch, linkNeighbors, toDocRanks } from './kb-lexical.mjs';
import { rrf } from './kb-fuse.mjs';
import { metrics } from './kb-cli.mjs';
const idx = JSON.parse(readFileSync(process.argv[2] + '/.forge/kb/index.json', 'utf8'));
const Q = JSON.parse(readFileSync(process.argv[3], 'utf8'));
const pre = Q.map((x) => ({ b: new Map([...toDocRanks(idx, bm25(idx, x.q))].map(([d, v]) => [d, v.rank])), e: new Map([...toDocRanks(idx, entityMatch(idx, x.q))].map(([d, v]) => [d, v.rank])) }));
console.log('entity-hit queries', pre.filter((p) => p.e.size).length);
for (const we of [0, 0.2, 0.3, 0.5]) for (const wl of [0, 0.05, 0.1, 0.2]) for (const pool of [10, 20]) {
  const w = { bm25: 1, entities: we, links: wl };
  const R = pre.map(({ b, e }) => { const ch = { bm25: b, entities: e }; const seed = rrf(ch, w).map((r) => r.doc); const p = new Set(seed.slice(0, pool)); ch.links = new Map(linkNeighbors(idx, seed, p).map(([d], i) => [d, i + 1])); return rrf(ch, w).map((r) => r.doc); });
  const m = metrics(Q, R); console.log(`WE=${we} WL=${wl} pool=${pool}`.padEnd(26), Object.entries(m).map(([k, v]) => `${k}=${v.toFixed(3)}`).join(' '));
}
