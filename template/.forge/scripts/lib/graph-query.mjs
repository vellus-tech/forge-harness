#!/usr/bin/env node
// lib/graph-query.mjs — STORY-05 de fix-graph-query-symbols-fusion (TASK-09): migra `graph.sh
// query` do `node -e` inline para módulo próprio.
//
// Contrato herdado (golden pré-mudança, TASK-01/TASK-02): a saída `nodes (N):`/`edges (N):` é
// preservada BYTE A BYTE em relação ao motor antigo. A seção `symbols (N):` é ADITIVA.
//
// Funções de ranking (`rankSymbols`/`tieBreak`) são PURAS e exportadas sem corte de 20 — o corte
// é decisão do CLI (design.md DD-09). `tieBreak` nunca reimplementa `localeCompare` em paralelo:
// reusa `compareSymbolNames`, já exportado por graph-symbols-extract.mjs (STORY-02, DD-04).
//
// Defasagem por {mtime,size} e degradação graciosa (REQ-04/REQ-10) chegam em TASK-10/TASK-11.
//
// Guard de CLI via `realpathSync` dos dois lados (padrão kb-cli.mjs) — NUNCA
// `import.meta.url === 'file://' + process.argv[1]`, que quebra em `/tmp` symlinkado no macOS
// (provado durante o design desta spec).
//
// Uso: graph-query.mjs <graph.json> <forge-root> <termo> [--json]
import { readFileSync, existsSync, realpathSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { compareSymbolNames } from './graph-symbols-extract.mjs';

export function readSymbolsSafely(root) {
  const p = join(root, '.forge/graph/symbols.json');
  if (!existsSync(p)) return { symbols: [], warning: null };
  const raw = readFileSync(p, 'utf8');
  const parsed = JSON.parse(raw);
  const symbols = Array.isArray(parsed && parsed.symbols) ? parsed.symbols : [];
  return { symbols, warning: null };
}

export function tieBreak(a, b) {
  return compareSymbolNames(a, b);
}

function matchTier(name, termLower) {
  const n = String(name).toLowerCase();
  if (n === termLower) return 0;
  if (n.startsWith(termLower)) return 1;
  if (n.includes(termLower)) return 2;
  return -1;
}

export function rankSymbols(symbols, term) {
  const termLower = String(term).toLowerCase();
  return symbols
    .map((s) => ({ s, tier: matchTier(s.name, termLower) }))
    .filter((x) => x.tier >= 0)
    .sort((a, b) => (a.tier - b.tier) || tieBreak(a.s, b.s))
    .map((x) => x.s);
}

async function main() {
  const [graphPath, root, ...rest] = process.argv.slice(2);
  if (!graphPath || !root) {
    console.log('FAIL (usage: graph.sh query <term> [--json])');
    process.exitCode = 1;
    return;
  }

  const asJson = rest.includes('--json');
  const term = rest.find((a) => a !== '--json');
  if (!term) {
    console.log('FAIL (usage: graph.sh query <term> [--json])');
    process.exitCode = 1;
    return;
  }

  const g = JSON.parse(readFileSync(graphPath, 'utf8'));
  const t = term.toLowerCase();
  const n = g.nodes.filter((x) => x.id.toLowerCase().includes(t));
  const e = g.edges.filter((x) => x.from.toLowerCase().includes(t) || x.to.toLowerCase().includes(t));

  const { symbols } = readSymbolsSafely(root);
  const ranked = rankSymbols(symbols, term);
  const displayed = ranked.slice(0, 20);

  if (asJson) {
    const data = {
      nodes: n.slice(0, 20).map((x) => ({ id: x.id, lang: x.lang, layer: x.layer, loc: x.loc })),
      edges: e.slice(0, 20).map((x) => ({ from: x.from, to: x.to, kind: x.kind, resolved: !!x.resolved })),
      symbols: displayed.map((s) => ({ id: s.id, name: s.name, type: s.type, file: s.file, line: s.line, layer: s.layer, stale: false })),
    };
    console.log(JSON.stringify(data, null, 2));
    return;
  }

  console.log(`nodes (${n.length}):`);
  n.slice(0, 20).forEach((x) => console.log(`  ${x.id} [${x.lang}/${x.layer}] loc=${x.loc}`));
  console.log(`edges (${e.length}):`);
  e.slice(0, 20).forEach((x) => console.log(`  ${x.from} -> ${x.to} (${x.kind}${x.resolved ? '' : ' unresolved'})`));
  console.log(`symbols (${ranked.length}):`);
  displayed.forEach((s) => console.log(`  ${s.name} [${s.type}] ${s.file}:${s.line} (${s.layer})`));
}

// Executa só quando chamado como script (nunca quando importado por um teste). Compara caminhos
// REAIS: /tmp e /var/folders são symlinks no macOS, e o argv[1] chega com o caminho lógico —
// `import.meta.url === 'file://' + process.argv[1]` quebra sob symlink (padrão kb-cli.mjs).
const invokedAsScript = (() => { try { return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url)); } catch { return false; } })();
if (invokedAsScript) {
  main().catch((err) => {
    process.stderr.write(`WARN: erro inesperado em graph-query.mjs (${err && err.message ? err.message : err})\n`);
    process.exitCode = 0;
  });
}
