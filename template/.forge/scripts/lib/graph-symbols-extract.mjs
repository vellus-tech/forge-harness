// lib/graph-symbols-extract.mjs — extrator PURO de símbolos (STORY-02 de
// fix-graph-query-symbols-fusion). Nenhuma integração com graph-build.mjs/walkSourceFiles ainda
// (STORY-03) — este módulo só exporta funções puras sobre (lang, src) ou sobre arrays já
// materializados, nunca lê disco, nunca escreve disco, nunca fecha sobre ordem de walk.
//
// Honestidade herdada de graph-symbols.mjs: regex/lexer artesanal, não AST (ADR-0001,
// graph-engine, zero-dep é inegociável) — herança é best-effort por nome, sem resolução de tipo.
//
// Exports:
//   stripCommentsPreservingLines(src, lang) — lexer de passada única, mascara comentário e
//     conteúdo de string/docstring/heredoc/regex substituindo por espaços do MESMO comprimento,
//     preservando toda quebra de linha original (REQ-02, design.md DD-01).
//   extractSymbols(rel, lang, src) — migra as regexes DECL de graph-symbols.mjs, rodando sobre a
//     saída já mascarada (REQ-01).
//   resolveInheritance(symbolsByFile) — resolve herança por nome sobre o array já materializado,
//     nunca sobre ordem de walk (design.md DD-02, ponto de injeção de ordem para P4/[26]).
//   compareSymbolNames(a, b) — comparador único de desempate (name,file,line),
//     localeCompare('en')+numérico (design.md DD-04) — reusado por TASK-09 em tieBreak, nunca
//     reimplementado.
//   assembleSymbolsArtifacts(symbolsByFile, {layerByFile, mtimeSizeByFile}) — monta
//     {symbolsJson, idxTsv} em memória (schema symbols/v0); gravação em disco é da STORY-03.

// =============================================================================================
// stripCommentsPreservingLines — lexer de passada única
// =============================================================================================

function maskFactory(out) {
  return (i) => { if (out[i] !== '\n') out[i] = ' '; };
}

// --- Python ------------------------------------------------------------------------------------
// `#` fora de string SEMPRE abre comentário (regra simples, sem exceção de shell). Docstring
// triplo-aspas tratada como string multi-linha (aspa de abertura/fechamento visível, conteúdo
// mascarado). String simples/dupla faz bail no fim da linha (REQ-02, "5 linguagens").
function stripPython(src) {
  const n = src.length;
  const out = src.split('');
  const mask = maskFactory(out);
  let i = 0;
  while (i < n) {
    const c = src[i];
    if ((c === '"' || c === "'") && src[i + 1] === c && src[i + 2] === c) {
      const q = c;
      let j = i + 3;
      while (j < n && !(src[j] === q && src[j + 1] === q && src[j + 2] === q)) { mask(j); j++; }
      if (j < n) j += 3; // consome a aspa tripla de fechamento, sem mascarar
      i = j;
      continue;
    }
    if (c === '"' || c === "'") {
      const quote = c;
      let j = i + 1;
      while (j < n && src[j] !== '\n') {
        if (src[j] === quote) {
          let bs = 0, k = j - 1;
          while (k >= 0 && src[k] === '\\') { bs++; k--; }
          if (bs % 2 === 0) break;
        }
        mask(j);
        j++;
      }
      if (j < n && src[j] === quote) j++;
      i = j;
      continue;
    }
    if (c === '#') {
      let j = i;
      while (j < n && src[j] !== '\n') { mask(j); j++; }
      i = j;
      continue;
    }
    i++;
  }
  return out.join('');
}

// --- Shell — pilha de frames (design.md DD-01) --------------------------------------------------
function isShellWordBoundary(src, i) {
  if (i === 0) return true;
  const p = src[i - 1];
  return p === '\n' || p === ' ' || p === '\t' || ';&|(){}<>'.includes(p);
}

function parseHeredocTag(src, j, n) {
  let allowTabs = false;
  if (src[j] === '-') { allowTabs = true; j++; }
  while (j < n && (src[j] === ' ' || src[j] === '\t')) j++;
  let tag = '';
  if (src[j] === "'" || src[j] === '"') {
    const q = src[j];
    j++;
    const start = j;
    while (j < n && src[j] !== q && src[j] !== '\n') j++;
    tag = src.slice(start, j);
    if (j < n && src[j] === q) j++;
  } else if (src[j] === '\\') {
    j++;
    const start = j;
    while (j < n && /[A-Za-z0-9_]/.test(src[j])) j++;
    tag = src.slice(start, j);
  } else {
    const start = j;
    while (j < n && /[A-Za-z0-9_]/.test(src[j])) j++;
    tag = src.slice(start, j);
  }
  return { tag, allowTabs, next: j };
}

function stripShell(src) {
  const n = src.length;
  const out = src.split('');
  const mask = maskFactory(out);
  const frames = [{ type: 'top', parenDepth: 0, braceDepth: 0, heredocPending: null, heredocActive: null }];
  const top = () => frames[frames.length - 1];

  let i = 0;
  while (i < n) {
    const frame = top();
    const c = src[i];

    // --- corpo de heredoc ativo (prioridade máxima) ---
    if (frame.heredocActive) {
      const { tag, allowTabs } = frame.heredocActive;
      let lineEnd = src.indexOf('\n', i);
      if (lineEnd === -1) lineEnd = n;
      let checkStart = i;
      if (allowTabs) { while (checkStart < lineEnd && src[checkStart] === '\t') checkStart++; }
      const lineContent = src.slice(checkStart, lineEnd);
      if (lineContent === tag) {
        frame.heredocActive = null;
        i = lineEnd < n ? lineEnd + 1 : n;
      } else {
        for (let k = i; k < lineEnd; k++) mask(k);
        i = lineEnd < n ? lineEnd + 1 : n;
      }
      continue;
    }

    // --- aspas simples: terminal, sem escape, atravessa linha ---
    if (frame.type === 'sq') {
      if (c === "'") { frames.pop(); i++; continue; }
      mask(i); i++; continue;
    }

    // --- aspas duplas: escape por contagem, $()/crase abrem subst aninhado, atravessa linha ---
    if (frame.type === 'dq') {
      if (c === '\\') { mask(i); if (i + 1 < n) mask(i + 1); i += 2; continue; }
      if (c === '"') { frames.pop(); i++; continue; }
      if (c === '$' && src[i + 1] === '(') {
        frames.push({ type: 'subst-paren', parenDepth: 1, braceDepth: 0, heredocPending: null, heredocActive: null });
        i += 2;
        continue;
      }
      if (c === '`') {
        frames.push({ type: 'subst-backtick', parenDepth: 0, braceDepth: 0, heredocPending: null, heredocActive: null });
        i += 1;
        continue;
      }
      mask(i); i++; continue;
    }

    // --- frame de código: top ou subst-paren/subst-backtick ---

    // fecho específico do frame de substituição atual (checado antes de qualquer outra regra)
    if (frame.type === 'subst-paren') {
      if (c === '(') { frame.parenDepth++; i++; continue; }
      if (c === ')') {
        frame.parenDepth--;
        i++;
        if (frame.parenDepth <= 0) frames.pop();
        continue;
      }
    }
    if (frame.type === 'subst-backtick' && c === '`') { frames.pop(); i++; continue; }

    // escape de caractere único em código normal (\\', \\", \\$, \\`, etc.)
    if (c === '\\') { i += 2; continue; }

    // heredoc pendente ativa no fim da linha
    if (c === '\n' && frame.heredocPending) {
      frame.heredocActive = frame.heredocPending;
      frame.heredocPending = null;
      i++;
      continue;
    }

    // comentário — início de palavra, não precedido por `$`, fora de `${...}`
    if (c === '#' && frame.braceDepth === 0 && isShellWordBoundary(src, i)) {
      let j = i;
      while (j < n && src[j] !== '\n') { mask(j); j++; }
      i = j;
      continue;
    }

    // here-string explicitamente excluído de heredoc
    if (src[i] === '<' && src[i + 1] === '<' && src[i + 2] === '<') { i += 3; continue; }

    // heredoc — `<<`/`<<-` + palavra-chave (só em top/subst, nunca em sq/dq, já garantido aqui)
    if (c === '<' && src[i + 1] === '<') {
      const { tag, allowTabs, next } = parseHeredocTag(src, i + 2, n);
      if (tag) {
        frame.heredocPending = { tag, allowTabs };
        i = next;
        continue;
      }
    }

    // substituição de comando `$(...)`
    if (c === '$' && src[i + 1] === '(') {
      frames.push({ type: 'subst-paren', parenDepth: 1, braceDepth: 0, heredocPending: null, heredocActive: null });
      i += 2;
      continue;
    }

    // crase — abre subst-backtick (só alcançável se o frame atual não for subst-backtick, já
    // tratado pelo fecho específico acima)
    if (c === '`') {
      frames.push({ type: 'subst-backtick', parenDepth: 0, braceDepth: 0, heredocPending: null, heredocActive: null });
      i += 1;
      continue;
    }

    // `${...}` — profundidade por frame, suprime comentário incondicionalmente
    if (c === '$' && src[i + 1] === '{') { frame.braceDepth++; i += 2; continue; }
    if (c === '}' && frame.braceDepth > 0) { frame.braceDepth--; i++; continue; }

    // abertura de aspas
    if (c === "'") { frames.push({ type: 'sq', parenDepth: 0, braceDepth: 0, heredocPending: null, heredocActive: null }); i++; continue; }
    if (c === '"') { frames.push({ type: 'dq', parenDepth: 0, braceDepth: 0, heredocPending: null, heredocActive: null }); i++; continue; }

    i++;
  }
  return out.join('');
}

// --- JS/TS/C#/Java/Kotlin/Go — `//`/`/* */`, mais `regex` só para JS/TS ------------------------
const REGEX_PUNCT = '(,=:[!&|?{};+-*%<>~^';
const REGEX_KEYWORDS = new Set(['return', 'typeof', 'case', 'else', 'throw', 'await', 'yield', 'in', 'of', 'void', 'delete', 'new', 'do']);

function isRegexStart(src, i) {
  let j = i - 1;
  while (j >= 0 && (src[j] === ' ' || src[j] === '\t')) j--;
  if (j < 0) return true;
  const c = src[j];
  if (c === '\n') return true;
  if (REGEX_PUNCT.includes(c)) return true;
  let k = j;
  while (k >= 0 && /[A-Za-z0-9_$]/.test(src[k])) k--;
  const word = src.slice(k + 1, j + 1);
  return REGEX_KEYWORDS.has(word);
}

function stripGeneric(src, { allowRegex, allowBacktick }) {
  const n = src.length;
  const out = src.split('');
  const mask = maskFactory(out);
  let i = 0;
  while (i < n) {
    const c = src[i];

    if (c === '/' && src[i + 1] === '/') {
      let j = i;
      while (j < n && src[j] !== '\n') { mask(j); j++; }
      i = j;
      continue;
    }

    if (c === '/' && src[i + 1] === '*') {
      let j = i;
      mask(j); mask(j + 1);
      j += 2;
      while (j < n && !(src[j] === '*' && src[j + 1] === '/')) { mask(j); j++; }
      if (j < n) { mask(j); mask(j + 1); j += 2; }
      i = j;
      continue;
    }

    if (c === '"' || c === "'" || (allowBacktick && c === '`')) {
      const quote = c;
      const isTemplate = quote === '`';
      let j = i + 1;
      while (j < n) {
        if (src[j] === '\n' && !isTemplate) break;
        if (src[j] === quote) {
          let bs = 0, k = j - 1;
          while (k >= 0 && src[k] === '\\') { bs++; k--; }
          if (bs % 2 === 0) break;
        }
        mask(j);
        j++;
      }
      if (j < n && src[j] === quote) j++;
      i = j;
      continue;
    }

    if (allowRegex && c === '/' && isRegexStart(src, i)) {
      let j = i + 1;
      let inClass = false;
      while (j < n && src[j] !== '\n') {
        if (src[j] === '\\') { mask(j); j++; if (j < n) mask(j); j++; continue; }
        if (src[j] === '[') { inClass = true; mask(j); j++; continue; }
        if (src[j] === ']') { inClass = false; mask(j); j++; continue; }
        if (src[j] === '/' && !inClass) break;
        mask(j);
        j++;
      }
      if (j < n && src[j] === '/' && !inClass) j++;
      i = j;
      continue;
    }

    i++;
  }
  return out.join('');
}

export function stripCommentsPreservingLines(src, lang) {
  if (lang === 'python') return stripPython(src);
  if (lang === 'shell') return stripShell(src);
  const isJsTs = lang === 'ts' || lang === 'js';
  return stripGeneric(src, { allowRegex: isJsTs, allowBacktick: isJsTs });
}

// =============================================================================================
// extractSymbols — migração linha a linha das regexes DECL de graph-symbols.mjs
// =============================================================================================

const DECL = {
  csharp: /\b(?<kw>class|interface|record|struct|enum)\s+(?<name>[A-Za-z_]\w*)(?:\s*<[^>]*>)?(?:\s*:\s*(?<base>[A-Za-z_][\w.<>, ]*))?/g,
  jvm: /\b(?<kw>class|interface|record|object|enum)\s+(?:class\s+)?(?<name>[A-Za-z_]\w*)(?:\s*<[^>]*>)?(?:\s*(?::|extends|implements)\s*(?<base>[A-Za-z_][\w.<>, ]*))?/g,
  python: /\b(?<kw>class)\s+(?<name1>[A-Za-z_]\w*)\s*(?:\(\s*(?<base>[A-Za-z_][\w., ]*)\))?|\bdef\s+(?<name2>[A-Za-z_]\w*)/g,
  ts: /\b(?<kw>class|interface|enum)\s+(?<name1>[A-Za-z_]\w*)(?:\s*<[^>]*>)?(?:\s+extends\s+(?<base>[A-Za-z_][\w.<>]*))?|\b(?:export\s+)?(?:async\s+)?function\s+(?<name2>[A-Za-z_]\w*)|\bexport\s+const\s+(?<name3>[A-Za-z_]\w*)\s*=\s*(?:async\s*)?\([^)]*\)\s*=>/g,
  js: /\b(?<kw>class)\s+(?<name1>[A-Za-z_]\w*)(?:\s+extends\s+(?<base>[A-Za-z_][\w.]*))?|\b(?:export\s+)?(?:async\s+)?function\s+(?<name2>[A-Za-z_]\w*)|\bexport\s+const\s+(?<name3>[A-Za-z_]\w*)\s*=\s*(?:async\s*)?\([^)]*\)\s*=>/g,
  shell: /^[ \t]*(?:function\s+)?(?<name>[A-Za-z_]\w*)\s*\(\s*\)\s*\{/gm,
};

function resolveLang(lang) {
  if (lang === 'java' || lang === 'kotlin') return 'jvm';
  return lang;
}

function pickMatch(resolvedLang, m) {
  const g = m.groups || {};
  if (resolvedLang === 'shell') {
    return g.name ? { type: 'function', name: g.name, base: null } : null;
  }
  if (resolvedLang === 'csharp' || resolvedLang === 'jvm') {
    return g.kw && g.name ? { type: g.kw, name: g.name, base: g.base || null } : null;
  }
  if (resolvedLang === 'python') {
    if (g.kw && g.name1) return { type: 'class', name: g.name1, base: g.base || null };
    if (g.name2) return { type: 'function', name: g.name2, base: null };
    return null;
  }
  if (resolvedLang === 'ts' || resolvedLang === 'js') {
    if (g.kw && g.name1) return { type: g.kw, name: g.name1, base: g.base || null };
    if (g.name2) return { type: 'function', name: g.name2, base: null };
    if (g.name3) return { type: 'function', name: g.name3, base: null };
    return null;
  }
  return null;
}

// índice de offsets de linha pré-computado — um split('\n') por arquivo, não um por símbolo
// (graph-symbols.mjs:58 recalculava `src.slice(0, idx).split('\n').length` a cada ocorrência,
// O(n²) no tamanho do arquivo).
function buildLineIndex(src) {
  const starts = [0];
  for (let i = 0; i < src.length; i++) if (src[i] === '\n') starts.push(i + 1);
  return starts;
}

function lineAt(starts, idx) {
  let lo = 0, hi = starts.length - 1, ans = 0;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (starts[mid] <= idx) { ans = mid; lo = mid + 1; } else hi = mid - 1;
  }
  return ans + 1;
}

export function extractSymbols(rel, lang, src) {
  if (lang === 'go') return { symbols: [], inherit: [] };
  const resolvedLang = resolveLang(lang);
  const re = DECL[resolvedLang];
  if (!re) return { symbols: [], inherit: [] };

  const masked = stripCommentsPreservingLines(src, lang);
  const lineStarts = buildLineIndex(masked);
  const seen = new Set();
  const symbols = [];
  const inherit = [];

  re.lastIndex = 0;
  for (const m of masked.matchAll(re)) {
    const picked = pickMatch(resolvedLang, m);
    if (!picked) continue;
    const { type, name, base } = picked;
    const line = lineAt(lineStarts, m.index);
    const key = `${rel}\u0000${name}\u0000${type}\u0000${line}`;
    if (seen.has(key)) continue;
    seen.add(key);
    symbols.push({ name, type, line });
    if (base) {
      for (const b of base.split(',').map((s) => s.trim().replace(/<.*/, '')).filter(Boolean)) {
        inherit.push({ name, base: b, line });
      }
    }
  }
  return { symbols, inherit };
}

// =============================================================================================
// compareSymbolNames — desempate único (name,file,line), localeCompare('en')+numérico (DD-04)
// =============================================================================================

export function compareSymbolNames(a, b) {
  const byName = a.name.localeCompare(b.name, 'en');
  if (byName !== 0) return byName;
  const byFile = a.file.localeCompare(b.file, 'en');
  if (byFile !== 0) return byFile;
  return Number(a.line) - Number(b.line);
}

// =============================================================================================
// resolveInheritance — função pura sobre array já materializado (design.md DD-02, seam de ordem
// para P4/[26]). `symbolsByFile`: [{ file, symbols:[{name,type,line}], inherit:[{name,base,line}] }]
// =============================================================================================

export function resolveInheritance(symbolsByFile) {
  const byNameCandidates = new Map();
  for (const entry of symbolsByFile) {
    for (const s of entry.symbols) {
      if (!byNameCandidates.has(s.name)) byNameCandidates.set(s.name, []);
      byNameCandidates.get(s.name).push({ file: entry.file, name: s.name, type: s.type, line: s.line });
    }
  }
  const byName = new Map();
  for (const [name, candidates] of byNameCandidates) {
    candidates.sort(compareSymbolNames);
    const chosen = candidates[0];
    byName.set(name, `${chosen.file}#${chosen.name}`);
  }

  const edges = [];
  for (const entry of symbolsByFile) {
    for (const inh of entry.inherit) {
      const from = `${entry.file}#${inh.name}`;
      const to = byName.get(inh.base);
      edges.push({ from, to: to || inh.base, kind: 'inherits', resolved: !!to });
    }
  }
  edges.sort((a, b) => (a.from + a.to).localeCompare(b.from + b.to, 'en'));
  return edges;
}

// =============================================================================================
// assembleSymbolsArtifacts — monta {symbolsJson, idxTsv} EM MEMÓRIA (schema symbols/v0). Nunca
// grava em disco — a gravação real é da STORY-03.
// =============================================================================================

export function assembleSymbolsArtifacts(symbolsByFile, { layerByFile, mtimeSizeByFile } = {}) {
  const layers = layerByFile || new Map();
  const mtimeSizes = mtimeSizeByFile || new Map();

  const symbols = [];
  for (const entry of symbolsByFile) {
    const layer = layers.get(entry.file) || 'unknown';
    const ms = mtimeSizes.get(entry.file) || {};
    for (const s of entry.symbols) {
      symbols.push({
        id: `${entry.file}#${s.name}`,
        file: entry.file,
        name: s.name,
        type: s.type,
        line: s.line,
        layer,
        mtime: ms.mtime ?? null,
        size: ms.size ?? null,
      });
    }
  }
  symbols.sort(compareSymbolNames);

  const edges = resolveInheritance(symbolsByFile);
  const byType = {};
  for (const s of symbols) byType[s.type] = (byType[s.type] || 0) + 1;

  const symbolsJson = {
    schema: 'symbols/v0',
    engine: 'native-regex',
    note: 'declarações + herança (best-effort). Sem call graph (exige AST/tree-sitter).',
    stats: { symbols: symbols.length, by_type: byType, inherit_edges: edges.length, resolved: edges.filter((e) => e.resolved).length },
    symbols,
    edges,
  };

  const idxLines = symbols.map((s) => `${s.name}\t${s.file}\t${s.line}\t${s.type}\t${s.layer}`);
  const idxTsv = idxLines.join('\n') + (idxLines.length ? '\n' : '');

  return { symbolsJson, idxTsv };
}
