#!/usr/bin/env node
// cost.mjs — soma o custo medido (cost.tsv) por artefato e por papel, a partir das notificações dos subagentes.
// Uso: node cost.mjs [--json <arquivo>]   Ambiente: REEXEC_SCRATCH.
// Conta execuções descartadas (discarded-map.tsv) e regrades (gradings descartados) como custo, porque foram pagos.
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const S = process.env.REEXEC_SCRATCH;
const rows = (f) => (existsSync(join(S, f)) ? readFileSync(join(S, f), 'utf8').trim().split('\n').filter(Boolean).map((l) => l.split('\t')) : []);
const owner = new Map([...rows('map.tsv'), ...rows('discarded-map.tsv')].map((r) => [r[0], r[2]]));
const agg = {};
const add = (k, role, tok, ms) => { const a = (agg[k] ||= {}); const c = (a[role] ||= { n: 0, tokens: 0, ms: 0 }); c.n++; c.tokens += tok; c.ms += ms; };
for (const [role, id, tok, , ms] of rows('cost.tsv')) {
  const name = owner.get(id) || (role === 'analyze' ? id.replace(/-(json|2)$/, '') : 'desconhecido');
  add(name, role, Number(tok), Number(ms)); add('TOTAL', role, Number(tok), Number(ms));
}
const out = [];
for (const [k, v] of Object.entries(agg)) {
  const t = Object.values(v).reduce((s, c) => ({ n: s.n + c.n, tokens: s.tokens + c.tokens, ms: s.ms + c.ms }), { n: 0, tokens: 0, ms: 0 });
  out.push({ artifact: k, ...Object.fromEntries(Object.entries(v).map(([r, c]) => [r, { n: c.n, tokens: c.tokens, minutes: Math.round(c.ms / 600) / 100 }])), total: { n: t.n, tokens: t.tokens, minutes: Math.round(t.ms / 600) / 100 } });
}
const ji = process.argv.indexOf('--json');
if (ji > 0) writeFileSync(process.argv[ji + 1], JSON.stringify(out, null, 2) + '\n');
for (const o of out) console.log(`${o.artifact}\t${o.total.n} subagentes\t${o.total.tokens} tokens\t${o.total.minutes} min` + (o.exec ? `\texec ${o.exec.n}×${Math.round(o.exec.tokens / o.exec.n)} tok, ${Math.round(o.exec.minutes * 60 / o.exec.n)} s` : ''));
