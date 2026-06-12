#!/usr/bin/env node
// forge graph deps — dependências agregadas MÓDULO→MÓDULO a partir do code graph
// (inspirado no "module dependencies / path finder" do Understand-Anything, mas
// determinista e zero-dep). Agrega as arestas arquivo→arquivo por boundary
// (service/package/app), reporta fan-out/fan-in e detecta CICLOS entre módulos
// (smell arquitetural). Zero tokens.
//
// Uso: graph-deps.mjs <forge-root> [--module <prefixo>] [--json]
import { readFileSync, existsSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const root = resolve(process.argv[2] || '.');
const moduleArg = (() => { const i = process.argv.indexOf('--module'); return i >= 0 ? process.argv[i + 1] : null; })();
const asJson = process.argv.includes('--json');
const graphPath = join(root, '.forge/graph/graph.json');
if (!existsSync(graphPath)) { console.log('FAIL (no graph — run: graph.sh build)'); process.exit(1); }
const g = JSON.parse(readFileSync(graphPath, 'utf8'));

// boundary = mesma convenção do C4: <root>/<group> para src/services/apps/packages/...
const BOUNDARY_ROOTS = new Set(['src', 'services', 'apps', 'packages', 'modules', 'libs', 'backend', 'frontend']);
function boundaryOf(id) {
  const p = id.split('/');
  if (BOUNDARY_ROOTS.has(p[0]) && p.length > 1) return `${p[0]}/${p[1]}`;
  return p.length > 1 ? p[0] : '(root)';
}

// adjacência módulo→módulo (com contagem de arestas) a partir das arestas resolvidas
const out = new Map();   // m -> Map(target -> count)
const modules = new Set();
for (const n of g.nodes) modules.add(boundaryOf(n.id));
for (const e of g.edges) {
  if (!e.resolved) continue;
  const a = boundaryOf(e.from), b = boundaryOf(e.to);
  if (a === b) continue;
  if (!out.has(a)) out.set(a, new Map());
  out.get(a).set(b, (out.get(a).get(b) || 0) + 1);
}
const inDeg = new Map();
for (const [a, tg] of out) for (const [b, c] of tg) inDeg.set(b, (inDeg.get(b) || 0) + c);

// detecção de ciclos entre módulos (DFS, lista os ciclos simples encontrados)
const cycles = [];
{
  const WHITE = 0, GRAY = 1, BLACK = 2;
  const color = new Map([...modules].map((m) => [m, WHITE]));
  const stack = [];
  const adj = (m) => [...(out.get(m)?.keys() || [])].sort();
  const dfs = (m) => {
    color.set(m, GRAY); stack.push(m);
    for (const nx of adj(m)) {
      if (!modules.has(nx)) continue;
      if (color.get(nx) === GRAY) {
        const i = stack.indexOf(nx);
        if (i >= 0) cycles.push([...stack.slice(i), nx]);
      } else if (color.get(nx) === WHITE) dfs(nx);
    }
    stack.pop(); color.set(m, BLACK);
  };
  for (const m of [...modules].sort()) if (color.get(m) === WHITE) dfs(m);
}

if (asJson) {
  const data = {
    modules: [...modules].sort(),
    edges: [...out].flatMap(([a, tg]) => [...tg].map(([b, c]) => ({ from: a, to: b, count: c }))),
    cycles,
  };
  writeFileSync(join(root, '.forge/graph/module-deps.json'), JSON.stringify(data, null, 2) + '\n');
  console.log(`OK module-deps.json (${modules.size} módulos, ${data.edges.length} dependências, ${cycles.length} ciclo(s))`);
  process.exit(0);
}

// relatório legível
const list = moduleArg ? [...modules].filter((m) => m.includes(moduleArg)).sort() : [...modules].sort();
const fmt = (tg) => [...(tg || new Map())].sort((x, y) => y[1] - x[1]).map(([b, c]) => `${b} (${c})`).join(', ') || '—';
console.log(`# Dependências módulo→módulo (${modules.size} módulos, ${[...out.values()].reduce((s, m) => s + m.size, 0)} arestas inter-módulo)\n`);
for (const m of list) {
  const fanOut = out.get(m);
  const depBy = [...out].filter(([, tg]) => tg.has(m)).map(([a, tg]) => `${a} (${tg.get(m)})`).sort();
  console.log(`## ${m}`);
  console.log(`  depende de (fan-out ${fanOut ? fanOut.size : 0}): ${fmt(fanOut)}`);
  console.log(`  usado por  (fan-in ${depBy.length}): ${depBy.join(', ') || '—'}\n`);
}
if (cycles.length) {
  console.log('## ⚠ Ciclos entre módulos (smell arquitetural)');
  for (const c of cycles) console.log(`  - ${c.join(' → ')}`);
} else {
  console.log('## Ciclos entre módulos: nenhum ✓');
}
