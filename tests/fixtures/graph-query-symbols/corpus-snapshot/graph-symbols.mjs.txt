#!/usr/bin/env node
// forge graph symbols — wrapper FINO (STORY-04/TASK-07) sobre o walk/extrator unificado
// (walkSourceFiles em graph-walk.mjs + extractSymbols/assembleSymbolsArtifacts em
// graph-symbols-extract.mjs), os MESMOS que graph-build.mjs usa. Antes desta mudança este
// arquivo tinha seu próprio walk (sem shell, sem codegraph.include_paths) e seu próprio DECL —
// motor duplicado que divergia silenciosamente do extrator real a cada linguagem nova.
//
// Honestidade: por ser regex (não AST), NÃO há call graph (resolução de chamada exige
// AST/tree-sitter); herança é best-effort por nome. Para o grafo de arquivos use
// `graph build` (preciso). Escreve APENAS .forge/graph/symbols.json e symbols.idx.tsv — NUNCA
// graph.json/fingerprints.json/report.md como efeito colateral (invariante crítica do epic;
// gate [25]).
//
// `includeGlobs` é calculado EXATAMENTE como graph-build.mjs (readForgeFrontmatter +
// compileLayerMap) — nunca `[]` por omissão (DD-02): um diretório oculto declarado em
// codegraph.include_paths entra no universo do wrapper standalone igual entra no build.
//
// `layer` de cada símbolo: herdado do graph.json já existente quando houver (mesma política do
// motor antigo); na ausência, 'unknown' — rodar o wrapper antes de build/update é diagnóstico
// válido (órfão esperado), não bug.
//
// Uso: graph-symbols.mjs <forge-root>
import { readFileSync, writeFileSync, existsSync, statSync } from 'node:fs';
import { join, resolve, extname, relative } from 'node:path';
import { readForgeFrontmatter, compileLayerMap } from './graph-layers.mjs';
import { walkSourceFiles, LANG } from './graph-walk.mjs';
import { extractSymbols, assembleSymbolsArtifacts } from './graph-symbols-extract.mjs';

const root = resolve(process.argv[2] || '.');
const graphPath = join(root, '.forge/graph/graph.json');

// reaproveita as camadas já calculadas no graph.json quando existir — mesma política do motor
// antigo (ausência/corrupção é no-op, nunca propaga exceção).
const layerByFile = new Map();
if (existsSync(graphPath)) {
  try { for (const n of JSON.parse(readFileSync(graphPath, 'utf8')).nodes) layerByFile.set(n.id, n.layer); } catch { /* ignore */ }
}

const forgeFrontmatter = readForgeFrontmatter(root);
const layerMap = compileLayerMap(forgeFrontmatter);
const includeGlobs = layerMap.includeGlobs || [];

const { files } = walkSourceFiles({ root, includeGlobs });

const symbolsByFile = [];
const mtimeSizeByFile = new Map();
for (const f of files) {
  const lang = LANG[extname(f)];
  const rel = relative(root, f);
  let src;
  try { src = readFileSync(f, 'utf8'); } catch { continue; }
  const { symbols, inherit } = extractSymbols(rel, lang, src);
  symbolsByFile.push({ file: rel, symbols, inherit });
  const st = statSync(f);
  mtimeSizeByFile.set(rel, { mtime: st.mtimeMs, size: st.size });
}

// mesma ordem canônica (file,line) de graph-build.mjs (STORY-03/TASK-05, design.md DD-02) — nunca
// a ordem física do walk.
const canonicalSymbolsByFile = symbolsByFile.slice().sort((a, b) => a.file.localeCompare(b.file, 'en'));
const { symbolsJson, idxTsv } = assembleSymbolsArtifacts(canonicalSymbolsByFile, { layerByFile, mtimeSizeByFile });

writeFileSync(join(root, '.forge/graph/symbols.json'), JSON.stringify(symbolsJson, null, 2) + '\n');
writeFileSync(join(root, '.forge/graph/symbols.idx.tsv'), idxTsv);

const byType = symbolsJson.stats.by_type;
console.log(`OK symbols.json (${symbolsJson.stats.symbols} símbolos: ${Object.entries(byType).map(([t, n]) => `${n} ${t}`).join(', ')}; ${symbolsJson.stats.inherit_edges} herança, ${symbolsJson.stats.resolved} resolvidas)`);
