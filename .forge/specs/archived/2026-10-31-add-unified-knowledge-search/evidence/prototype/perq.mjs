import { readFileSync } from 'node:fs'; import { execFileSync } from 'node:child_process';
const qs = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const rank = (args, q) => { const o = JSON.parse(execFileSync('bash', ['template/.forge/scripts/kb.sh', 'query', q.q, '--json', '--top', '50', ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })); const p = o.results.findIndex((r) => q.gold.some((g) => r.doc.toLowerCase().includes(g.toLowerCase()))); return [p < 0 ? '-' : p + 1, o.mode]; };
for (const q of qs) { const a = rank(['--no-rerank'], q), b = rank([], q), c = rank(['--lexical'], q); if (a[0] !== b[0] || c[0] !== a[0]) console.log(`lex=${c[0]} sem=${a[0]} rr=${b[0]} ${a[1]}/${b[1]} :: ${q.q}`); }
