// lib/graph-walk.mjs — walk unificado de arquivos-fonte (STORY-03 de fix-graph-query-symbols-fusion,
// TASK-04, DD-02). Extraído de graph-build.mjs: a função `walk()` de lá fechava sobre globais do
// módulo (`census`, `includeGlobs`) e mutava um acumulador por closure — nada disso é testável
// isoladamente nem reusável pelo consumidor de símbolos (STORY-04). Esta versão é pura:
// `walkSourceFiles({root, includeGlobs})` recebe tudo que precisa como parâmetro e devolve
// `{files, census}` explicitamente, sem efeito colateral de módulo.
//
// As cinco constantes abaixo (SKIP_DIRS, SKIP_UNDER_BIN, CENSUS_EXT, LANG, SKIP_FILE) migraram
// junto — são exportadas daqui e `graph-build.mjs` as importa, nunca duplica (REQ-08 parcial).
import { readdirSync } from 'node:fs';
import { join, relative, extname, basename } from 'node:path';

// Build/output/vendored dirs are excluded: they hold generated artifacts (minified
// bundles, archived copies) that pollute the graph with non-source nodes (G2).
//
// `bin` is deliberately NOT here. The name means opposite things in different ecosystems: in
// .NET/Java it is where the compiler writes output, in Node it is the entrypoint declared in
// package.json — source code by any definition. Skipping it by name removed the CLI entrypoint
// from the graph of every Node project, silently, and /forge:impact, /forge:onboard and
// /forge:c4 all read that graph. The .NET meaning is handled by SKIP_UNDER_BIN below, which is
// contextual: only the build-output subdirectories of a `bin/` are pruned.
export const SKIP_DIRS = new Set([
  'node_modules', '.git', 'dist', 'build', 'out', 'obj', '.forge', 'coverage',
  '.next', 'vendor', 'storybook-static', 'wwwroot', '_archive', 'TestResults',
  '.vs', '.idea', '.venv', '__pycache__', '.turbo', '.cache',
]);
// Subdirectories of a `bin/` that are compiler output (.NET/Java): bin/Debug, bin/Release,
// bin/x64, bin/net8.0, … Pruned only when the PARENT directory is literally `bin` — a
// `src/Debug/` of someone's own making is not touched. This is what keeps generated `.cs`
// (which matches LANG) out of the graph now that `bin` itself is walked.
export const SKIP_UNDER_BIN = /^(Debug|Release|x64|x86|AnyCPU|Any CPU|net[0-9]|netstandard|netcoreapp)/i;
// `.sh`/`.bash` entram como NÓ (lang: shell) e nada além disso (LDG-0027). Um script chamando
// outro por `bash caminho/x.sh` é dependência real, mas quase sempre via variável resolvida em
// runtime (`$SCRIPT_DIR/x.sh`, `$ROOT/.forge/scripts/x.sh`) — medido neste próprio repositório,
// é o idioma dominante em template/.forge/scripts/**. Uma aresta "resolvida" contra um literal de
// variável não resolvida seria precisão fingida (o oposto do que GO_IMPORT/PY_IMPORT fazem hoje,
// que ao menos preservam o identificador real, ainda que não resolvido). Nó sem aresta e dito
// aqui é honesto; aresta fantasma não é. Ver tests/w165-codegraph-scan-roots-gate.sh [3].
export const LANG = { '.js': 'js', '.mjs': 'js', '.cjs': 'js', '.jsx': 'js', '.ts': 'ts', '.tsx': 'ts', '.cs': 'csharp', '.go': 'go', '.py': 'python', '.kt': 'kotlin', '.kts': 'kotlin', '.java': 'java', '.sh': 'shell', '.bash': 'shell' };
// Broader census map for the coverage rule (§19.5): every programming language worth
// counting, INCLUDING ones the extractor does not model (swift/rust/…), so `validate
// graph` can name a dominant language that has no nodes (issue #18). Header-only C/C++
// extensions (.h/.hpp) are deliberately excluded: they are ambiguous (C vs C++) and are
// the dominant source of vendored/NDK noise that would falsely outrank real app code.
// Computed in the SAME walk that builds nodes, so validate never re-walks the tree.
export const CENSUS_EXT = {
  ...LANG,
  '.swift': 'swift', '.rb': 'ruby', '.rs': 'rust', '.php': 'php', '.scala': 'scala',
  '.dart': 'dart', '.cpp': 'cpp', '.cc': 'cpp', '.cxx': 'cpp', '.c': 'c', '.m': 'objc', '.mm': 'objc',
};
// Minified/generated files are not source — skip even when they carry a source extension (G2).
export const SKIP_FILE = /\.min\.(js|css)$|\.bundle\.js$/;

// walkSourceFiles({root, includeGlobs}) — versão pura do antigo walk() de graph-build.mjs
// (design.md DD-02): `root` é o diretório raiz do repositório; `includeGlobs` é o array de
// RegExp já compilado (codegraph.include_paths, LDG-0027), default []. Devolve
// `{files, census}` em vez de mutar closure externa — `files` é a lista de paths absolutos de
// arquivos cuja extensão está em LANG (nós do grafo); `census` é o mapa lang->contagem para
// TODAS as extensões em CENSUS_EXT (população mais ampla, usada pela regra de cobertura §19.5).
export function walkSourceFiles({ root, includeGlobs = [] } = {}) {
  const census = {};
  const files = [];

  function walk(dir) {
    let entries;
    try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      const p = join(dir, e.name);
      // LDG-0027: um caminho declarado em codegraph.include_paths vence o default de "pular" —
      // tanto o prefixo de ponto quanto SKIP_DIRS/SKIP_UNDER_BIN. Sem declaração (includeGlobs
      // vazio, o caso de todo projeto consumidor) forcedInclude é sempre false e o walk abaixo é
      // idêntico ao de antes desta chave existir.
      const relId = relative(root, p);
      const forcedInclude = includeGlobs.length > 0 && includeGlobs.some((re) => re.test(relId));
      if (!forcedInclude && e.name.startsWith('.') && e.name !== '.') continue;
      if (e.isDirectory()) {
        if (!forcedInclude) {
          if (SKIP_DIRS.has(e.name)) continue;
          // contextual: só poda saída de compilação quando o pai é um `bin/` de verdade
          if (basename(dir) === 'bin' && SKIP_UNDER_BIN.test(e.name)) continue;
        }
        walk(p);
      }
      else if (!SKIP_FILE.test(e.name)) {
        const ext = extname(e.name);
        const cl = CENSUS_EXT[ext];
        if (cl) census[cl] = (census[cl] || 0) + 1;
        if (LANG[ext]) files.push(p);
      }
    }
  }

  walk(root);
  return { files, census };
}
