// Medição informativa do verify: modo semântico (e lexical) COM e SEM a propagação de links, usando
// os módulos de produção e a camada instalada de verdade. Uso: node eval-noprop.mjs <raiz> <consultas.json>
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
const [root, qfile] = process.argv.slice(2);
const lib = join(root, 'template/.forge/scripts/lib');
const { bm25, entityMatch, toDocRanks, attachTexts } = await import(join(lib, 'kb-lexical.mjs'));
const { rrf, propagateLinks, combineRerank, WEIGHTS } = await import(join(lib, 'kb-fuse.mjs'));
const { metrics } = await import(join(lib, 'kb-cli.mjs'));
const { loadSemantic } = await import(join(lib, 'kb-semantic.mjs'));
const idx = attachTexts(JSON.parse(readFileSync(join(root, '.forge/kb/index.json'), 'utf8')), readFileSync(join(root, '.forge/kb/texts.bin')));
const Q = JSON.parse(readFileSync(qfile, 'utf8'));
const L = await loadSemantic(join(root, '.forge/kb/semantic'), join(lib, 'kb-pins'), join(root, '.forge/kb/vectors.bin'));
if (!L.ok) { console.error('camada indisponível:', L.reason); process.exit(1); }
const sem = L.semantic;
const rk = (m) => new Map([...m].map(([d, o]) => [d, o.rank]));
const rows = { 'lexical sem links': [], 'lexical (default)': [], 'semantic sem links': [], 'semantic (default)': [], 'semantic+rerank sem links': [], 'semantic+rerank (default)': [] };
for (const x of Q) {
  const b = toDocRanks(idx, bm25(idx, x.q)), e = toDocRanks(idx, entityMatch(idx, x.q));
  const v = await sem.vectorSearch(idx, x.q);
  const lexF = rrf({ bm25: rk(b), entities: rk(e) }, WEIGHTS);
  rows['lexical sem links'].push(lexF.map((r) => r.doc));
  rows['lexical (default)'].push(propagateLinks(lexF, idx.links).map((r) => r.doc));
  const semF = rrf({ bm25: rk(b), entities: rk(e), vector: rk(v.ranks) }, WEIGHTS);
  for (const [label, fused] of [['sem links', semF], ['(default)', propagateLinks(semF, idx.links)]]) {
    const order = fused.map((r) => r.doc);
    rows[`semantic ${label}`].push(order);
    const best = new Map([...b].map(([d, o]) => [d, o.chunk])); for (const [d, o] of v.ranks) if (!best.has(d)) best.set(d, o.chunk);
    const scores = new Map();
    for (const d of order.slice(0, 10)) scores.set(d, await sem.crossScore(x.q, idx.chunkText(sem.representative(idx, d, x.q, v.queryVector, best.get(d)))));
    rows[`semantic+rerank ${label}`].push(combineRerank(order, scores).map((r) => r.doc));
  }
}
for (const [k, R] of Object.entries(rows)) { const m = metrics(Q, R); console.log(`${k.padEnd(28)} hit@1=${m.hit1.toFixed(3)} hit@5=${m.hit5.toFixed(3)} hit@10=${m.hit10.toFixed(3)} MRR=${m.mrr.toFixed(3)}`); }
