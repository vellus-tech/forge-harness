#!/usr/bin/env node
// forge c4 generate (§16.5, W4.3). Zero-dependency. Derives C4 Mermaid diagrams
// from the code graph (deterministic, zero tokens beyond curation). Output is Markdown
// (.md) wrapping a ```mermaid fenced block, so it renders in any Markdown previewer
// (VS Code, GitHub) instead of showing raw Mermaid like a bare .mmd:
//   c1-context.md   — system + grouped external dependencies
//   c2-container.md  — boundaries (services/packages/apps/src groups) + relations
//   c3-component-<module>.md — files within each multi-file boundary + internal edges
// Convention (§16.5): NO dots and NO em-dash inside Mermaid labels — sanitized here.
// Usage: c4-gen.mjs <forge-root>
import { readFileSync, writeFileSync, existsSync, mkdirSync, readdirSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';

const root = resolve(process.argv[2] || '.');
const graphPath = join(root, '.forge/graph/graph.json');
if (!existsSync(graphPath)) { console.log('FAIL (no graph — run /forge:graph build first)'); process.exit(1); }
const g = JSON.parse(readFileSync(graphPath, 'utf8'));
const c4Dir = join(root, '.forge/graph/c4');
mkdirSync(c4Dir, { recursive: true });

// label sanitizer: strip dots and em/en-dash from label text (Mermaid convention)
const san = (s) => String(s).replace(/[—–]/g, '-').replace(/\./g, ' ').replace(/\s+/g, ' ').trim();

// Write a diagram as Markdown with a fenced ```mermaid block (human-renderable).
function writeDiagram(base, title, mermaid) {
  const md = `# ${title}\n\n` +
    '> Gerado por `/forge:c4` a partir do code graph. Renderiza como diagrama em qualquer\n' +
    '> previewer de Markdown com suporte a Mermaid (VS Code, GitHub).\n\n' +
    '```mermaid\n' + mermaid + '\n```\n';
  writeFileSync(join(c4Dir, `${base}.md`), md);
}

const BOUNDARY_ROOTS = ['src', 'services', 'apps', 'packages', 'modules', 'libs'];
function boundaryOf(id) {
  const p = id.split('/');
  if (BOUNDARY_ROOTS.includes(p[0]) && p.length > 1) return `${p[0]}/${p[1]}`;
  return p.length > 1 ? p[0] : '(root)';
}

// project name from FORGE.md frontmatter (display), fallback to dir name
let system = 'System';
try {
  const fm = readFileSync(join(root, '.forge/FORGE.md'), 'utf8').match(/^---\n([\s\S]*?)\n---/);
  const disp = fm && fm[1].match(/^\s*display:\s*(.+)$/m);
  const name = fm && fm[1].match(/^\s*name:\s*(.+)$/m);
  if (disp) system = disp[1].trim(); else if (name) system = name[1].trim();
} catch { /* keep default */ }

// ── C1 context ────────────────────────────────────────────────────────────────
const externals = new Set();
for (const e of g.edges) if (!e.resolved && /^[a-z@]/.test(e.to) && !e.to.startsWith('.')) externals.add(e.to.split('/')[0]);
const c1 = ['flowchart TD', `  sys["${san(system)}"]`];
if (externals.size) {
  c1.push('  ext["External dependencies"]', '  sys --> ext');
}
writeDiagram('c1-context', 'C1 — Contexto do Sistema', c1.join('\n'));

// ── C2 container ──────────────────────────────────────────────────────────────
const containers = new Map(); // boundary -> {files}
for (const n of g.nodes) {
  const b = boundaryOf(n.id);
  if (!containers.has(b)) containers.set(b, 0);
  containers.set(b, containers.get(b) + 1);
}
const idOf = new Map([...containers.keys()].sort().map((b, i) => [b, `c${i}`]));
const c2 = ['flowchart TD'];
for (const [b, count] of [...containers.entries()].sort()) c2.push(`  ${idOf.get(b)}["${san(b)} (${count})"]`);
const seenRel = new Set();
for (const e of g.edges) {
  if (!e.resolved) continue;
  const ba = boundaryOf(e.from), bb = boundaryOf(e.to);
  if (ba === bb) continue;
  const key = `${ba}>${bb}`;
  if (seenRel.has(key)) continue;
  seenRel.add(key);
  c2.push(`  ${idOf.get(ba)} --> ${idOf.get(bb)}`);
}
writeDiagram('c2-container', 'C2 — Containers', c2.join('\n'));

// ── C3 component (per multi-file boundary) ───────────────────────────────────
const byBoundary = new Map();
for (const n of g.nodes) {
  const b = boundaryOf(n.id);
  if (!byBoundary.has(b)) byBoundary.set(b, []);
  byBoundary.get(b).push(n.id);
}
let c3count = 0;
for (const [b, files] of [...byBoundary.entries()].sort()) {
  if (files.length < 2) continue;
  const slug = b.replace(/[^a-zA-Z0-9]+/g, '-').replace(/^-|-$/g, '').toLowerCase();
  const nid = new Map(files.sort().map((f, i) => [f, `f${i}`]));
  const lines = ['flowchart TD', `  %% component view: ${san(b)}`];
  for (const f of files.sort()) lines.push(`  ${nid.get(f)}["${san(f.split('/').pop())}"]`);
  for (const e of g.edges) {
    if (!e.resolved) continue;
    if (nid.has(e.from) && nid.has(e.to)) lines.push(`  ${nid.get(e.from)} --> ${nid.get(e.to)}`);
  }
  writeDiagram(`c3-component-${slug}`, `C3 — Componentes: ${san(b)}`, lines.join('\n'));
  c3count++;
}

// clean stale c3 files from previous runs that no longer correspond to a boundary,
// plus any legacy .mmd files from versions that emitted bare Mermaid.
const wanted = new Set([...byBoundary.entries()].filter(([, f]) => f.length >= 2)
  .map(([b]) => `c3-component-${b.replace(/[^a-zA-Z0-9]+/g, '-').replace(/^-|-$/g, '').toLowerCase()}.md`));
for (const f of readdirSync(c4Dir)) {
  if (f.endsWith('.mmd')) { rmSync(join(c4Dir, f)); continue; }
  if (f.startsWith('c3-component-') && f.endsWith('.md') && !wanted.has(f)) rmSync(join(c4Dir, f));
}

console.log(`OK c4: c1-context, c2-container (${containers.size} containers), ${c3count} component view(s)`);
