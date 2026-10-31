import { readFileSync } from 'node:fs';
const W = process.cwd() + '/template/.forge/scripts/lib/';
const L = await import(W + 'kb-lexical.mjs'); const F = await import(W + 'kb-fuse.mjs');
const idx = L.attachTexts(JSON.parse(readFileSync('.forge/kb/index.json', 'utf8')), readFileSync('.forge/kb/texts.bin'));
for (const file of process.argv.slice(2)) {
  const qs = JSON.parse(readFileSync(file, 'utf8'));
  const acc = { bm25: 0, 'bm25+links': 0, 'bm25+ent': 0, full: 0 };
  const rr = (list, q) => { const p = list.findIndex((d) => q.gold.some((g) => d.toLowerCase().includes(g.toLowerCase()))); return p < 0 ? 0 : 1 / (p + 1); };
  for (const q of qs) {
    const b = L.toDocRanks(idx, L.bm25(idx, q.q)); const e = L.toDocRanks(idx, L.entityMatch(idx, q.q));
    const cb = { bm25: new Map([...b].map(([d, v]) => [d, v.rank])) }; const ce = { ...cb, entities: new Map([...e].map(([d, v]) => [d, v.rank])) };
    acc.bm25 += rr([...b.keys()], q);
    acc['bm25+links'] += rr(F.propagateLinks(F.rrf(cb), idx.links).map((r) => r.doc), q);
    acc['bm25+ent'] += rr(F.rrf(ce).map((r) => r.doc), q);
    acc.full += rr(F.propagateLinks(F.rrf(ce), idx.links).map((r) => r.doc), q);
  }
  console.log(file.split('/').pop(), Object.entries(acc).map(([k, v]) => `${k}=${(v / qs.length).toFixed(3)}`).join(' '));
}
