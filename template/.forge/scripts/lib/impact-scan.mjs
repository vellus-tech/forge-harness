#!/usr/bin/env node
// forge impact-scan (§16.4, W4.2). Zero-dependency. Given seed files (changed
// files of a diff, or affected_paths of a change), computes the transitive
// IMPACT set via reverse reachability over the resolved graph edges: every node
// that depends (directly or transitively) on a seed. Deterministic.
// Writes <change-dir>/impact.json when --change is given (consumed by archive
// pre-flight) and always prints a one-line summary + the impacted paths.
//
// Usage:
//   impact-scan.mjs --graph <graph.json> --files a.ts,b.ts
//   impact-scan.mjs --graph <graph.json> --change <change-dir>   (reads manifest affected_paths; writes impact.json)
// Output: "OK impact: N seed(s) -> M impacted" + impacted list, or "FAIL (...)".
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { createHash } from 'node:crypto';

const args = process.argv.slice(2);
const opt = (k) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : null; };
const graphPath = opt('--graph');
const filesArg = opt('--files');
const changeDir = opt('--change');

if (!graphPath || !existsSync(graphPath)) { console.log('FAIL (graph.json not found — run /forge:codegraph)'); process.exit(1); }
const g = JSON.parse(readFileSync(graphPath, 'utf8'));

// graph fingerprint: stable hash of all node fingerprints (detects staleness)
const graphFingerprint = createHash('sha256').update(g.nodes.map((n) => n.id + ':' + n.fingerprint).sort().join('\n')).digest('hex');

// seeds
let seeds = [];
let outFile = null;
if (filesArg) {
  seeds = filesArg.split(',').map((s) => s.trim()).filter(Boolean);
} else if (changeDir) {
  const manPath = join(resolve(changeDir), 'manifest.yaml');
  if (!existsSync(manPath)) { console.log(`FAIL (no manifest at ${manPath})`); process.exit(1); }
  // minimal extraction of affected_paths (list of "  - <path>" under affected_paths:)
  const man = readFileSync(manPath, 'utf8');
  const m = man.match(/^affected_paths:\n((?:\s*-\s.*\n?)*)/m);
  if (m && m[1].trim()) seeds = m[1].split('\n').map((l) => l.replace(/^\s*-\s*/, '').trim()).filter(Boolean);
  outFile = join(resolve(changeDir), 'impact.json');
} else {
  console.log('FAIL (usage: --files a,b | --change <dir>)'); process.exit(1);
}

const ids = new Set(g.nodes.map((n) => n.id));
// expand seed directories/prefixes to concrete graph nodes
const seedNodes = new Set();
for (const s of seeds) {
  if (ids.has(s)) seedNodes.add(s);
  else for (const id of ids) if (id === s || id.startsWith(s.endsWith('/') ? s : s + '/')) seedNodes.add(id);
}

// reverse adjacency: to -> [from] (who depends on `to`)
const rev = new Map();
for (const e of g.edges) {
  if (!e.resolved) continue;
  if (!rev.has(e.to)) rev.set(e.to, []);
  rev.get(e.to).push(e.from);
}

// BFS over reverse edges
const impacted = new Set(seedNodes);
const queue = [...seedNodes];
while (queue.length) {
  const cur = queue.shift();
  for (const dep of (rev.get(cur) || [])) if (!impacted.has(dep)) { impacted.add(dep); queue.push(dep); }
}

const impactedList = [...impacted].sort();
const result = {
  schema: 'impact/v0',
  generated_at: new Date().toISOString(),
  graph_fingerprint: graphFingerprint,
  seeds: [...seedNodes].sort(),
  impacted: impactedList,
};

if (outFile) writeFileSync(outFile, JSON.stringify(result, null, 2) + '\n');
console.log(`OK impact: ${seedNodes.size} seed(s) -> ${impactedList.length} impacted`);
for (const p of impactedList) console.log(`  ${p}`);
if (seeds.length && seedNodes.size === 0) { console.log('FAIL (no seed matched a graph node — paths outside the graph or graph stale)'); process.exit(1); }
