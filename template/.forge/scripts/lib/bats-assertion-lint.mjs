// bats-assertion-lint.mjs - LDG-1626: bats só usa o exit code da ÚLTIMA instrução do corpo de
// um @test pra decidir pass/fail. Uma asserção "[ ]"/"[[ ]]" fora de `run`, que falha NO MEIO do
// teste, não aborta nada por padrão - as linhas seguintes continuam rodando e só a última
// decide. Um @test com 2+ dessas linhas sem "||"/"return"/"exit"/"assert_" tem, por construção,
// pelo menos uma que nunca é verificada de fato.
//
// Zero-dependência: só node:fs.

export function findVulnerableTests(text) {
  const lines = text.split('\n');
  const results = [];
  let inTest = false;
  let depth = 0;
  let startLine = 0;
  let testName = '';
  let buf = [];

  const ASSERT_RE = /^\s*(\[\[|\[)\s/;
  const GUARD_RE = /\|\||return|exit|assert_/;

  function flushTest(endLine) {
    const assertionLines = buf
      .map((l, idx) => ({ l, idx }))
      .filter(({ l }) => ASSERT_RE.test(l));
    const bare = assertionLines.filter(({ l }) => !GUARD_RE.test(l));
    if (bare.length >= 2) {
      results.push({
        name: testName,
        startLine,
        endLine,
        bareCount: bare.length,
        bareLines: bare.map(({ l, idx }) => ({ lineNo: startLine + idx + 1, text: l.trim() })),
      });
    }
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const s = line.trim();
    if (!inTest && /^@test\b/.test(s)) {
      inTest = true;
      depth = (line.match(/\{/g) || []).length - (line.match(/\}/g) || []).length;
      startLine = i;
      testName = s;
      buf = [];
      continue;
    }
    if (inTest) {
      depth += (line.match(/\{/g) || []).length;
      depth -= (line.match(/\}/g) || []).length;
      if (depth <= 0) {
        flushTest(i + 1);
        inTest = false;
        continue;
      }
      buf.push(line);
    }
  }
  return results;
}

export function collectBatsFiles(dir, fs) {
  const { readdirSync, statSync } = fs;
  const SKIP = new Set(['node_modules', '.git', '.forge', 'dist', 'build']);
  const out = [];
  function walk(d) {
    let entries;
    try { entries = readdirSync(d); } catch { return; }
    for (const e of entries) {
      if (SKIP.has(e)) continue;
      const p = `${d}/${e}`;
      let st;
      try { st = statSync(p); } catch { continue; }
      if (st.isDirectory()) walk(p);
      else if (e.endsWith('.bats')) out.push(p);
    }
  }
  walk(dir);
  return out;
}

// Parse de hunks de `git diff -U0`: devolve o conjunto de números de linha ADICIONADOS no
// arquivo de DESTINO (lado +), por arquivo.
export function parseAddedLines(diffText) {
  const perFile = new Map();
  let currentFile = null;
  let newLine = 0;
  for (const line of diffText.split('\n')) {
    const fm = line.match(/^\+\+\+ b\/(.+)$/);
    if (fm) { currentFile = fm[1]; if (!perFile.has(currentFile)) perFile.set(currentFile, new Set()); continue; }
    const hm = line.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/);
    if (hm) { newLine = parseInt(hm[1], 10); continue; }
    if (currentFile == null) continue;
    if (line.startsWith('+') && !line.startsWith('+++')) {
      perFile.get(currentFile).add(newLine);
      newLine += 1;
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      // linha removida não avança newLine
    } else if (line.startsWith(' ')) {
      newLine += 1;
    }
  }
  return perFile;
}
