#!/usr/bin/env node
// lib/graph-query.mjs — STORY-05 de fix-graph-query-symbols-fusion (TASK-09/10/11): migra
// `graph.sh query` do `node -e` inline para módulo próprio.
//
// Contrato herdado (golden pré-mudança, TASK-01/TASK-02): a saída `nodes (N):`/`edges (N):` é
// preservada BYTE A BYTE em relação ao motor antigo quando `symbols.json` não existe — esse é o
// cenário de controle [1], o mais crítico desta story. A seção `symbols (N):` é ADITIVA.
//
// Funções de ranking (`rankSymbols`/`tieBreak`) são PURAS e exportadas sem corte de 20 — o corte
// é decisão do CLI (design.md DD-09). `tieBreak` nunca reimplementa `localeCompare` em paralelo:
// reusa `compareSymbolNames`, já exportado por graph-symbols-extract.mjs (STORY-02, DD-04).
//
// Degradação graciosa (REQ-10, design.md DD-07): `readSymbolsSafely()` é o ÚNICO ponto que emite
// `WARN` — sempre em STDERR, nunca em stdout (contaminaria o golden). `query` nunca escreve em
// disco e sempre sai `exit 0`, inclusive com symbols.json ausente/corrompido/legado/órfão.
//
// Guard de CLI via `realpathSync` dos dois lados (padrão kb-cli.mjs) — NUNCA
// `import.meta.url === 'file://' + process.argv[1]`, que quebra em `/tmp` symlinkado no macOS
// (provado durante o design desta spec).
//
// Uso: graph-query.mjs <graph.json> <forge-root> <termo> [--json]
import { readFileSync, statSync, existsSync, realpathSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { compareSymbolNames } from './graph-symbols-extract.mjs';

// Texto canônico de 0-resultados (REQ-05) — mesma string em modo humano e no campo `hint` do
// `--json`, para nunca divergir entre as duas superfícies.
export function zeroResultsHint(term) {
  return `hint: nenhum node/edge/símbolo casou com "${term}". Se symbols.json não existe, rode \`graph.sh build\` para gerar símbolos; se já existe, tente um termo mais genérico (prefixo/substring) ou \`graph.sh symbols\` para conferir o índice.`;
}

// =============================================================================================
// readSymbolsSafely — ÚNICO ponto que emite WARN (sempre em stderr). Nunca lança: symbols.json
// ausente, corrompido ou em formato legado todos degradam para `{ symbols: [], warning }` (ou
// `{ symbols: [...], warning }` quando o parse teve sucesso mas o formato é legado) sem afetar
// nodes/edges (design.md DD-07).
// =============================================================================================
export function readSymbolsSafely(root) {
  const p = join(root, '.forge/graph/symbols.json');
  if (!existsSync(p)) return { symbols: [], warning: null };

  let raw;
  try {
    raw = readFileSync(p, 'utf8');
  } catch (e) {
    return { symbols: [], warning: `WARN: falha ao ler symbols.json (${e && e.message ? e.message : e}) — degradando para nodes/edges-only` };
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return { symbols: [], warning: 'WARN symbols.json inválido — mostrando só nodes/edges; rode graph.sh build', invalid: true };
  }

  const symbols = Array.isArray(parsed && parsed.symbols) ? parsed.symbols : [];

  // Aviso de formato legado/ausência só dispara quando symbols.length > 0 E nenhuma entrada tem
  // mtime — NUNCA quando symbols:[] é vazio por projeto genuinamente sem símbolos extraíveis
  // (ex. só .go), que seria um falso positivo (design.md DD-07, cenário [16b]).
  let warning = null;
  if (symbols.length > 0 && !symbols.some((s) => s && s.mtime != null)) {
    warning = 'WARN: symbols.json em formato legado (sem mtime/size) — defasagem não verificável';
  }

  return { symbols, warning };
}

// =============================================================================================
// tieBreak / rankSymbols — PURAS, sem corte de 20 (design.md DD-09). Desempate determinístico
// (name,file,line) via compareSymbolNames (DD-04) — nunca reimplementado em paralelo.
// =============================================================================================
export function tieBreak(a, b) {
  return compareSymbolNames(a, b);
}

// tier de ranking: 0 = exato, 1 = prefixo, 2 = substring, -1 = sem match (filtrado fora).
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

// =============================================================================================
// staleness por símbolo — stat() SÓ nos resultados efetivamente retornados (≤20, decisão do
// CLI). Nunca consulta o fingerprint estrutural do node em graph.json — mecanismo distinto, que
// não deve marcar stale aqui (cenário [6b]).
// =============================================================================================
export function computeSymbolStatus(sym, root) {
  if (sym.mtime == null || sym.size == null) {
    return { verifiable: false, stale: false, missing: false };
  }
  let st;
  try {
    st = statSync(join(root, sym.file));
  } catch (e) {
    if (e && e.code === 'ENOENT') return { verifiable: true, stale: true, missing: true };
    return { verifiable: false, stale: false, missing: false };
  }
  const stale = st.mtimeMs !== sym.mtime || st.size !== sym.size;
  return { verifiable: true, stale, missing: false };
}

function staleSuffix(status) {
  if (status.missing) return ' (arquivo não encontrado — rode graph.sh build)';
  if (!status.verifiable) return ' (não verificável)';
  if (status.stale) return ' (linha possivelmente defasada)';
  return '';
}

// =============================================================================================
// main — CLI. nodes/edges byte a byte idênticos ao motor antigo; symbols aditivo.
// =============================================================================================
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

  // Seção symbols — isolada em try/catch: qualquer falha inesperada aqui degrada para
  // nodes/edges-only (WARN em stderr), nunca derruba a seção já calculada acima (REQ-10, [17b]).
  let ranked = [];
  let enriched = [];
  let invalid = false;
  try {
    const { symbols, warning, invalid: invalidIndex } = readSymbolsSafely(root);
    invalid = !!invalidIndex;
    if (warning) process.stderr.write(warning + '\n');
    ranked = rankSymbols(symbols, term);
    enriched = ranked.slice(0, 20).map((s) => {
      const status = computeSymbolStatus(s, root);
      const out = { id: s.id, name: s.name, type: s.type, file: s.file, line: s.line, layer: s.layer, stale: !!status.stale };
      if (status.missing) out.missing = true;
      return { sym: s, status, json: out };
    });
  } catch (err) {
    process.stderr.write(`WARN: falha inesperada ao processar symbols.json (${err && err.message ? err.message : err}) — degradando para nodes/edges-only\n`);
    ranked = [];
    enriched = [];
  }

  const zeroResults = n.length === 0 && e.length === 0 && ranked.length === 0;

  if (asJson) {
    const data = {
      nodes: n.slice(0, 20).map((x) => ({ id: x.id, lang: x.lang, layer: x.layer, loc: x.loc })),
      edges: e.slice(0, 20).map((x) => ({ from: x.from, to: x.to, kind: x.kind, resolved: !!x.resolved })),
      symbols: enriched.map((x) => x.json),
    };
    if (zeroResults) data.hint = zeroResultsHint(term);
    console.log(JSON.stringify(data, null, 2));
    return;
  }

  console.log(`nodes (${n.length}):`);
  n.slice(0, 20).forEach((x) => console.log(`  ${x.id} [${x.lang}/${x.layer}] loc=${x.loc}`));
  console.log(`edges (${e.length}):`);
  e.slice(0, 20).forEach((x) => console.log(`  ${x.from} -> ${x.to} (${x.kind}${x.resolved ? '' : ' unresolved'})`));
  if (!invalid) console.log(`symbols (${ranked.length}):`);
  enriched.forEach((x) => {
    const s = x.sym;
    console.log(`  ${s.name} [${s.type}] ${s.file}:${s.line} (${s.layer})${staleSuffix(x.status)}`);
  });
  if (zeroResults) console.log(zeroResultsHint(term));
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
