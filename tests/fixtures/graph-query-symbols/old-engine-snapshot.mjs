// Snapshot CONGELADO do motor antigo de extração de símbolos (TASK-02,
// fix-graph-query-symbols-fusion) — vendoriza, sem masking de comentário/string, as mesmas
// regexes DECL e o mesmo laço `src.matchAll` usados hoje por
// `template/.forge/scripts/lib/graph-symbols.mjs` (releitura em 2026-11-04). É o oráculo
// diferencial das stories seguintes: o lexer novo (STORY-02+) precisa concordar com este motor
// regex-based sobre o corpus real (`corpus-snapshot/`, `corpus-snapshot-shell/`), exceto nos
// casos de falso-positivo/falso-negativo que o bugfix documenta (fantasma de comentário/string,
// `.sh`/`.go` nunca indexados).
//
// Importável via `import()` dinâmico (nenhum efeito colateral de I/O — função pura sobre
// `(lang, src)`), mesmo padrão que a TASK-03/TASK-14 usam para comparar contra `old-engine-
// snapshot.mjs` sem jamais reimportar o `graph-symbols.mjs` real (que faria I/O e dependeria do
// grafo.json do repositório vivo).
//
// Honestidade herdada do motor original: regex, não AST — sem call graph; herança é best-effort
// por nome (ADR-0001, graph-engine: zero-dep é inegociável).

// Mapa linguagem -> extensão, idêntico ao `LANG` de graph-symbols.mjs (reproduzido aqui só para
// os testes que precisam resolver `lang` a partir de uma extensão de arquivo do corpus).
export const LANG = {
  '.cs': 'csharp', '.ts': 'ts', '.tsx': 'ts',
  '.js': 'js', '.jsx': 'js', '.mjs': 'js', '.cjs': 'js',
  '.py': 'python', '.java': 'jvm', '.kt': 'jvm', '.kts': 'jvm',
};

// declarações + base de herança por linguagem — cópia byte a byte das regexes de
// graph-symbols.mjs (nenhuma reescrita, nenhum masking de comentário/string: é exatamente o
// comportamento que produz os fantasmas documentados em bugfix.md).
export const DECL = {
  csharp: /\b(class|interface|record|struct|enum)\s+([A-Za-z_]\w*)(?:\s*<[^>]*>)?(?:\s*:\s*([A-Za-z_][\w.<>, ]*))?/g,
  ts: /\b(class|interface|enum)\s+([A-Za-z_]\w*)(?:\s*<[^>]*>)?(?:\s+extends\s+([A-Za-z_][\w.<>]*))?|\b(?:export\s+)?(?:async\s+)?function\s+([A-Za-z_]\w*)/g,
  js: /\b(class)\s+([A-Za-z_]\w*)(?:\s+extends\s+([A-Za-z_][\w.]*))?|\b(?:export\s+)?(?:async\s+)?function\s+([A-Za-z_]\w*)/g,
  python: /\b(class)\s+([A-Za-z_]\w*)\s*(?:\(\s*([A-Za-z_][\w., ]*)\))?|\bdef\s+([A-Za-z_]\w*)/g,
  jvm: /\b(class|interface|record|object|enum)\s+(?:class\s+)?([A-Za-z_]\w*)(?:\s*<[^>]*>)?(?:\s*(?::|extends|implements)\s+([A-Za-z_][\w.<>, ]*))?/g,
};

// extractSymbolsOldEngine: função pura — recebe (lang, src), devolve [{name, type, line, base}],
// mesmo laço `for (const m of src.matchAll(re))` + despacho de grupos de captura do motor real.
// Sem `id`/`file`/`layer` (que dependem do caminho do arquivo/grafo) — esses campos são
// montados pelo chamador, exatamente como graph-symbols.mjs monta `id = \`${rel}#${name}\`` fora
// desta função.
export function extractSymbolsOldEngine(lang, src) {
  const re = DECL[lang];
  if (!re) return [];
  re.lastIndex = 0;
  const lineOf = (idx) => src.slice(0, idx).split('\n').length;
  const out = [];
  for (const m of src.matchAll(re)) {
    let type, name, base = null;
    if (m[1] && m[2]) { type = m[1]; name = m[2]; base = m[3] || null; }
    else if (m[4]) { type = 'function'; name = m[4]; }
    else if (m[5]) { type = 'function'; name = m[5]; }
    else if (m[6]) { type = 'function'; name = m[6]; }
    else continue;
    out.push({ name, type, line: lineOf(m.index), base });
  }
  return out;
}
