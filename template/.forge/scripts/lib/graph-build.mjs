#!/usr/bin/env node
// forge graph build (engine: native, ADR 0001 — W4.1). Zero-dependency (Node >= 20).
// Builds .forge/graph/graph.json deterministically: nodes = source files
// (lang/loc/structural fingerprint/layer); edges = internal import/reference
// relations. LLM never runs here — summaries are carried over from the cache by
// fingerprint, so a cosmetic change (comment/whitespace) keeps the fingerprint,
// keeps the cached summary, and costs ZERO tokens (§16.2).
//
// Usage: graph-build.mjs <repo-root> [--out <dir>]
// Output: "OK .forge/graph/graph.json (N nodes, M edges; S summaries stale)" or "FAIL (...)".
import { readFileSync, writeFileSync, existsSync, readdirSync, mkdirSync } from 'node:fs';
import { join, resolve, relative, extname, dirname } from 'node:path';
import { createHash } from 'node:crypto';

const root = resolve(process.argv[2] || '.');
const outArg = process.argv.indexOf('--out');
const outDir = outArg >= 0 ? resolve(process.argv[outArg + 1]) : join(root, '.forge/graph');
const cacheDir = join(outDir, 'cache');

const SKIP_DIRS = new Set(['node_modules', '.git', 'dist', 'build', 'out', 'bin', 'obj', '.forge', 'coverage', '.next', 'vendor']);
const LANG = { '.js': 'js', '.mjs': 'js', '.cjs': 'js', '.jsx': 'js', '.ts': 'ts', '.tsx': 'ts', '.cs': 'csharp', '.go': 'go', '.py': 'python', '.kt': 'kotlin', '.kts': 'kotlin' };

function walk(dir, acc = []) {
  let entries;
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return acc; }
  for (const e of entries) {
    if (e.name.startsWith('.') && e.name !== '.') continue;
    const p = join(dir, e.name);
    if (e.isDirectory()) { if (!SKIP_DIRS.has(e.name)) walk(p, acc); }
    else if (LANG[extname(e.name)]) acc.push(p);
  }
  return acc;
}

// structural fingerprint: drop whole-line comments and blank lines, then collapse
// ALL whitespace (including line breaks) to single spaces and sha256. Stable
// against cosmetic edits — comment lines, blank lines, reindentation and line
// reflow (breaking one statement across lines); changes on structural edits
// (new import/declaration/token). Inline comments (code // foo) are a known
// limitation: they shift the fingerprint conservatively (re-process, never miss).
function structuralFingerprint(src) {
  const norm = src.split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !/^(\/\/|#|\*|\/\*|\*\/)/.test(l))
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();
  return createHash('sha256').update(norm).digest('hex');
}

function layerOf(id) {
  const p = id.toLowerCase();
  if (/(^|\/)(tests?|__tests__|spec)(\/|$)|\.(spec|test)\./.test(p)) return 'test';
  if (/(^|\/)(api|controllers?|presentation|web|app|pages|routes)(\/|$)/.test(p)) return 'api';
  if (/(^|\/)(application|usecases?|handlers?|services?)(\/|$)/.test(p)) return 'application';
  if (/(^|\/)(domain|entities|core|model)(\/|$)/.test(p)) return 'domain';
  if (/(^|\/)(infrastructure|persistence|repositories|data|adapters?)(\/|$)/.test(p)) return 'infrastructure';
  if (/(^|\/)(contracts?|dtos?|schemas?)(\/|$)/.test(p)) return 'contracts';
  if (/\.(config|json|ya?ml)$|(^|\/)config(\/|$)/.test(p)) return 'config';
  return 'unknown';
}

// per-language import extraction → resolved internal edges
const JS_IMPORT = /(?:import\s+(?:[^'"]*?\s+from\s+)?|export\s+[^'"]*?\s+from\s+|require\s*\(\s*|import\s*\(\s*)['"]([^'"]+)['"]/g;
const CS_USING = /^\s*using\s+(?:static\s+)?([A-Za-z_][\w.]*)\s*;/gm;
const CS_NAMESPACE = /^\s*namespace\s+([A-Za-z_][\w.]*)/gm;
const GO_IMPORT = /(?:^\s*import\s+"([^"]+)"|^\s*"([^"]+)"\s*$)/gm;
const PY_IMPORT = /^\s*(?:from\s+([.\w]+)\s+import|import\s+([.\w]+))/gm;

function resolveJsTarget(fromFile, spec, fileSet) {
  if (!spec.startsWith('.')) return null; // external dep
  const base = resolve(dirname(fromFile), spec);
  const cands = [base, base + '.ts', base + '.tsx', base + '.js', base + '.mjs', base + '.jsx',
    join(base, 'index.ts'), join(base, 'index.js'), join(base, 'index.mjs')];
  for (const c of cands) if (fileSet.has(c)) return c;
  return null;
}

const files = walk(root);
const fileSet = new Set(files);
const nodes = [];
const edges = [];
const srcCache = new Map();
const read = (f) => { if (!srcCache.has(f)) srcCache.set(f, readFileSync(f, 'utf8')); return srcCache.get(f); };

// C#: index namespace -> declaring files (for using resolution)
const nsToFiles = new Map();
for (const f of files) {
  if (LANG[extname(f)] !== 'csharp') continue;
  for (const m of read(f).matchAll(CS_NAMESPACE)) {
    const ns = m[1];
    if (!nsToFiles.has(ns)) nsToFiles.set(ns, []);
    nsToFiles.get(ns).push(f);
  }
}

for (const f of files) {
  const src = read(f);
  const lang = LANG[extname(f)];
  const id = relative(root, f);
  nodes.push({ id, lang, loc: src.split('\n').length, fingerprint: structuralFingerprint(src), layer: layerOf(id), summary: null });

  if (lang === 'js' || lang === 'ts') {
    for (const m of src.matchAll(JS_IMPORT)) {
      const target = resolveJsTarget(f, m[1], fileSet);
      if (m[1].startsWith('.')) edges.push({ from: id, to: target ? relative(root, target) : m[1], kind: 'import', resolved: !!target });
    }
  } else if (lang === 'csharp') {
    for (const m of src.matchAll(CS_USING)) {
      const targets = nsToFiles.get(m[1]);
      if (targets) for (const t of targets) { if (t !== f) edges.push({ from: id, to: relative(root, t), kind: 'namespace', resolved: true }); }
    }
  } else if (lang === 'go') {
    for (const m of src.matchAll(GO_IMPORT)) {
      const spec = m[1] || m[2];
      if (spec && spec.includes('/')) edges.push({ from: id, to: spec, kind: 'import', resolved: false });
    }
  } else if (lang === 'python') {
    for (const m of src.matchAll(PY_IMPORT)) {
      const spec = m[1] || m[2];
      if (spec && spec.startsWith('.')) edges.push({ from: id, to: spec, kind: 'import', resolved: false });
    }
  }
}

// carry over cached summaries by fingerprint (zero tokens on cosmetic changes)
let summariesStale = 0;
const prevSummaries = existsSync(join(cacheDir, 'summaries.json'))
  ? JSON.parse(readFileSync(join(cacheDir, 'summaries.json'), 'utf8')) : {};
for (const n of nodes) {
  const cached = prevSummaries[n.id];
  if (cached && cached.fingerprint === n.fingerprint && cached.summary) n.summary = cached.summary;
  else if (n.summary === null) summariesStale++;
}

nodes.sort((a, b) => a.id.localeCompare(b.id));
edges.sort((a, b) => (a.from + a.to + a.kind).localeCompare(b.from + b.to + b.kind));

const langs = [...new Set(nodes.map((n) => n.lang))].sort();
const graph = {
  schema: 'graph/v0',
  generated_at: new Date().toISOString(),
  engine: 'native',
  root,
  stats: { nodes: nodes.length, edges: edges.length, languages: langs, summaries_stale: summariesStale },
  nodes,
  edges,
};

mkdirSync(cacheDir, { recursive: true });
writeFileSync(join(outDir, 'graph.json'), JSON.stringify(graph, null, 2) + '\n');
// fingerprints cache (drives incremental update)
const fp = {}; for (const n of nodes) fp[n.id] = n.fingerprint;
writeFileSync(join(cacheDir, 'fingerprints.json'), JSON.stringify(fp, null, 2) + '\n');
// summaries cache (preserve carried-over)
const sum = {}; for (const n of nodes) if (n.summary) sum[n.id] = { fingerprint: n.fingerprint, summary: n.summary };
writeFileSync(join(cacheDir, 'summaries.json'), JSON.stringify(sum, null, 2) + '\n');
// report.md (human-readable, deterministic)
const byLayer = {};
for (const n of nodes) byLayer[n.layer] = (byLayer[n.layer] || 0) + 1;
const report = [
  `# Code Graph — report`, '',
  `- Engine: native (zero-dep)`,
  `- Nodes: ${nodes.length} · Edges: ${edges.length}`,
  `- Languages: ${langs.join(', ') || '—'}`,
  `- Summaries stale (need LLM curation): ${summariesStale}`, '',
  `## Nodes per layer`, '',
  ...Object.entries(byLayer).sort().map(([l, c]) => `- ${l}: ${c}`), '',
  `## Unresolved edges (external deps or unknown targets)`, '',
  `- ${edges.filter((e) => !e.resolved).length} unresolved`, '',
].join('\n');
writeFileSync(join(outDir, 'report.md'), report + '\n');

console.log(`OK .forge/graph/graph.json (${nodes.length} nodes, ${edges.length} edges; ${summariesStale} summaries stale)`);
