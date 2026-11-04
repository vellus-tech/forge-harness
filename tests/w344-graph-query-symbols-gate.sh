#!/usr/bin/env bash
# Gate — TASK-03 de fix-graph-query-symbols-fusion (REQ-01, REQ-02; story STORY-02): extrator
# puro de símbolos + lexer de pilha de frames em graph-symbols-extract.mjs. Sem integração com
# graph-build.mjs ainda (STORY-03) — tudo aqui é função pura sobre (lang, src) ou sobre arrays já
# materializados.
#   [0]    vacuidade por linguagem (cs/ts/js/py/java/kotlin/shell >0; .go === [])
#   [8]    fantasma de string/comentário não indexa
#   [8b]   apóstrofo em comentário não vaza para a linha seguinte
#   [13a]  herança pura isolada (resolveInheritance sobre array sintético)
#   [18]   equivalência diferencial com o motor antigo (old-engine-snapshot.mjs) sobre o corpus
#          congelado da STORY-01 — remoções verificadas mecanicamente como fantasma, adições
#          classificadas (shell novo / arrow function)
#   [19]   regras de `#` em shell (${...} suprime incondicionalmente; $#; a#b)
#   [19c]  substituição de comando dentro de aspas duplas (pilha de frames, não par linear)
#   [19d]  `$(node -e '...` multi-linha dentro de substituição de comando
#   [20]   heredoc shell mascara corpo, não mascara código real depois
#   [21]   docstring Python não gera fantasma
#   [26a]  herança independente de ordem de entrada (função pura, shuffle em memória)
#   [29]   regex com aspas/crase não abre string (estado `regex` JS/TS)
#   [29b]  precedência `//`/`/*` sobre `regex`
#   [29c]  caso adversarial A5 — arrow/keyword abrindo regex
#   [30]   here-string `<<<` não é heredoc
#   [31]   heredoc com palavra-chave entre aspas/escapada (4 variantes)
#   [31b]  `<<-EOF` com TAB vs `<<EOF` com TAB (heredoc nunca fechado, mascara até EOF)
#   [32]   oráculo de corpus real (.mjs de template/.forge/scripts/lib/*.mjs) — plausível, sem crash
#   [32b]  oráculo de corpus real shell (.sh de template/.forge/scripts/**) — plausível, sem crash
#   PBT P2 (sem duplicata), P4-herança (invariância sob permutação), P5 (invariância cosmética)
#
# TDD red-first (DD-08): o módulo graph-symbols-extract.mjs é novo sob template/.forge/scripts/
# (isInfraPath) — o commit vermelho desta task toca só este arquivo em tests/. Red via import()
# dinâmico + try/catch, convertendo ERR_MODULE_NOT_FOUND numa asserção assert.fail própria
# (cenário [0]), nunca um stub neutro de produção.
set -uo pipefail
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUT="$(node - "$WS" <<'NODEEOF'
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');

const [, , WS] = process.argv;
const LIB = path.join(WS, 'template/.forge/scripts/lib');
const FIX = path.join(WS, 'tests/fixtures/graph-query-symbols');

let fail = 0;
function ok(tag, msg) { console.log(`OK [${tag}]: ${msg}`); }
function bad(tag, msg) { console.log(`FAIL [${tag}]: ${msg}`); fail = 1; }
function tryCase(tag, fn) {
  try { fn(); } catch (e) { bad(tag, e && e.message ? e.message : String(e)); }
}

function readFix(name) { return fs.readFileSync(path.join(FIX, name), 'utf8'); }

// recursivamente lista arquivos sob um diretório, filtrando por extensão
function walk(dir, exts, acc = []) {
  let entries;
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return acc; }
  for (const e of entries) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, exts, acc);
    else if (exts.some((ext) => e.name.endsWith(ext))) acc.push(p);
  }
  return acc;
}

async function main() {
  // === [0] parte 1: módulo precisa existir — RED-first (DD-08) ===
  let mod;
  try {
    mod = await import('file://' + path.join(LIB, 'graph-symbols-extract.mjs'));
  } catch (e) {
    try {
      assert.fail('RED TASK-03: graph-symbols-extract.mjs ainda não existe');
    } catch (ae) {
      bad('0', ae.message);
    }
    console.log('__GATE_ABORT_NO_MODULE__');
    process.exit(fail);
  }

  const { stripCommentsPreservingLines, extractSymbols, resolveInheritance, compareSymbolNames, assembleSymbolsArtifacts } = mod;

  for (const [label, fn] of Object.entries({ stripCommentsPreservingLines, extractSymbols, resolveInheritance, compareSymbolNames, assembleSymbolsArtifacts })) {
    if (typeof fn !== 'function') bad('0', `export ausente ou não-função: ${label}`);
  }

  // === [0] parte 2: vacuidade por linguagem ===
  tryCase('0', () => {
    const cases = [
      ['f.js', 'js', 'class Foo {}\nfunction bar() {}\n'],
      ['f.java', 'java', 'public class Foo extends Bar {\n}\n'],
      ['f.kt', 'kotlin', 'class Foo : Bar {\n}\n'],
    ];
    for (const [rel, lang, src] of cases) {
      const r = extractSymbols(rel, lang, src);
      assert.ok(r.symbols.length > 0, `${lang}: esperado >0 símbolos, obteve ${r.symbols.length}`);
    }
    const goR = extractSymbols('f.go', 'go', 'package main\nfunc Foo() {}\n');
    assert.deepEqual(goR.symbols, [], '.go precisa produzir symbols: []');

    const cs = extractSymbols('ghosts.cs', 'csharp', readFix('ghosts.cs.txt'));
    assert.ok(cs.symbols.length > 0, 'csharp: esperado >0 símbolos na fixture');
    const ts = extractSymbols('ghosts.ts', 'ts', readFix('ghosts.ts.txt'));
    assert.ok(ts.symbols.length > 0, 'ts: esperado >0 símbolos na fixture');
    const py = extractSymbols('docstring.py', 'python', readFix('docstring.py.txt'));
    assert.ok(py.symbols.length > 0, 'python: esperado >0 símbolos na fixture');
    const sh = extractSymbols('shell-basic.sh', 'shell', readFix('shell-basic.sh.txt'));
    assert.ok(sh.symbols.length > 0, 'shell: esperado >0 símbolos na fixture');
    ok('0', `vacuidade por linguagem confirmada (cs=${cs.symbols.length} ts=${ts.symbols.length} py=${py.symbols.length} sh=${sh.symbols.length} go=0)`);
  });

  // === [8] fantasma de string/comentário ===
  tryCase('8', () => {
    const ts = extractSymbols('ghosts.ts', 'ts', readFix('ghosts.ts.txt'));
    assert.ok(!ts.symbols.some((s) => s.name === 'Ghost'), 'ts: "Ghost" não deveria ser indexado (fantasma de string/comentário/template)');
    const cs = extractSymbols('ghosts.cs', 'csharp', readFix('ghosts.cs.txt'));
    assert.ok(!cs.symbols.some((s) => /Ghost/.test(s.name)), 'cs: nenhum "Ghost*" deveria ser indexado');
    const py = extractSymbols('docstring.py', 'python', readFix('docstring.py.txt'));
    assert.ok(!py.symbols.some((s) => /Ghost/.test(s.name)), 'py: nenhum "Ghost*" deveria ser indexado');
    const sh = extractSymbols('shell-basic.sh', 'shell', readFix('shell-basic.sh.txt'));
    assert.ok(!sh.symbols.some((s) => /Ghost/.test(s.name)), 'sh: nenhum "Ghost*" deveria ser indexado');
    const hd = extractSymbols('shell-heredoc.sh', 'shell', readFix('shell-heredoc.sh.txt'));
    assert.ok(!hd.symbols.some((s) => /Ghost/.test(s.name)), 'sh heredoc: "Ghost" dentro do corpo não deveria ser indexado');
    ok('8', 'nenhum fantasma de string/comentário/template/heredoc indexado');
  });

  // === [8b] apóstrofo em comentário não vaza ===
  tryCase('8b', () => {
    const py = extractSymbols('docstring.py', 'python', readFix('docstring.py.txt'));
    const realMethod = py.symbols.find((s) => s.name === 'real_method');
    assert.ok(realMethod && realMethod.line === 17, `py: real_method esperado na linha 17, obteve ${realMethod && realMethod.line}`);
    const sh = extractSymbols('shell-basic.sh', 'shell', readFix('shell-basic.sh.txt'));
    const suggestPack = sh.symbols.find((s) => s.name === 'suggest_pack');
    assert.ok(suggestPack && suggestPack.line === 18, `sh: suggest_pack esperado na linha 18, obteve ${suggestPack && suggestPack.line}`);
    ok('8b', 'apóstrofo dentro de comentário não abriu estado de string vazando para a linha seguinte');
  });

  // === [13a] herança pura isolada ===
  tryCase('13a', () => {
    const synthetic = [
      { file: 'a.ts', symbols: [{ name: 'Base', type: 'class', line: 1 }], inherit: [] },
      { file: 'b.ts', symbols: [{ name: 'Child', type: 'class', line: 1 }], inherit: [{ name: 'Child', base: 'Base', line: 1 }] },
      { file: 'c.ts', symbols: [{ name: 'Orphan', type: 'class', line: 1 }], inherit: [{ name: 'Orphan', base: 'NoSuchBase', line: 1 }] },
    ];
    const edges = resolveInheritance(synthetic);
    const resolved = edges.find((e) => e.from === 'b.ts#Child');
    assert.ok(resolved, 'edge de Child->Base não encontrada');
    assert.equal(resolved.to, 'a.ts#Base');
    assert.equal(resolved.resolved, true);
    const unresolved = edges.find((e) => e.from === 'c.ts#Orphan');
    assert.ok(unresolved, 'edge de Orphan->NoSuchBase não encontrada');
    assert.equal(unresolved.to, 'NoSuchBase');
    assert.equal(unresolved.resolved, false);
    ok('13a', `herança pura resolvida corretamente (${edges.length} edges)`);
  });

  // === [18] equivalência diferencial com o motor antigo ===
  await tryCaseAsync('18', async () => {
    const oldMod = await import('file://' + path.join(FIX, 'old-engine-snapshot.mjs'));
    const EXT_LANG_MJS = { '.mjs': 'js' };
    const EXT_LANG_SH = { '.sh': 'shell' };

    function stripTxt(name) { return name.replace(/\.txt$/, ''); }

    const mjsDir = path.join(FIX, 'corpus-snapshot');
    const shDir = path.join(FIX, 'corpus-snapshot-shell');
    const mjsFiles = fs.readdirSync(mjsDir).filter((n) => n.endsWith('.mjs.txt'));
    const shFiles = fs.readdirSync(shDir).filter((n) => n.endsWith('.sh.txt'));

    const oldKeys = new Set();
    const newKeys = new Set();
    const newByKey = new Map();
    const srcByFile = new Map();
    const maskedByFile = new Map();

    for (const fn of mjsFiles) {
      const file = stripTxt(fn);
      const src = fs.readFileSync(path.join(mjsDir, fn), 'utf8');
      srcByFile.set(file, src);
      const lang = EXT_LANG_MJS['.mjs'];
      for (const s of oldMod.extractSymbolsOldEngine(lang, src)) {
        oldKeys.add(`${file}|${s.name}|${s.type}|${s.line}`);
      }
      const masked = stripCommentsPreservingLines(src, lang);
      maskedByFile.set(file, masked);
      const r = extractSymbols(file, lang, src);
      for (const s of r.symbols) {
        const k = `${file}|${s.name}|${s.type}|${s.line}`;
        newKeys.add(k);
        newByKey.set(k, { file, ...s });
      }
    }
    for (const fn of shFiles) {
      const file = stripTxt(fn);
      const src = fs.readFileSync(path.join(shDir, fn), 'utf8');
      srcByFile.set(file, src);
      const lang = EXT_LANG_SH['.sh'];
      // motor antigo não tem DECL.shell — extractSymbolsOldEngine(lang) com lang desconhecido
      // devolve [] (shell nunca foi indexado antes desta fatia).
      for (const s of oldMod.extractSymbolsOldEngine(lang, src)) {
        oldKeys.add(`${file}|${s.name}|${s.type}|${s.line}`);
      }
      const masked = stripCommentsPreservingLines(src, lang);
      maskedByFile.set(file, masked);
      const r = extractSymbols(file, lang, src);
      for (const s of r.symbols) {
        const k = `${file}|${s.name}|${s.type}|${s.line}`;
        newKeys.add(k);
        newByKey.set(k, { file, ...s });
      }
    }

    const removed = [...oldKeys].filter((k) => !newKeys.has(k));
    const added = [...newKeys].filter((k) => !oldKeys.has(k));

    const unconfirmedRemovals = [];
    for (const k of removed) {
      const [file, name, , lineStr] = k.split('|');
      const line = Number(lineStr);
      const src = srcByFile.get(file);
      const masked = maskedByFile.get(file);
      const origLine = (src.split('\n')[line - 1] || '');
      const maskLine = (masked.split('\n')[line - 1] || '');
      const re = new RegExp('\\b' + name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\b');
      const m = re.exec(origLine);
      const seg = m ? maskLine.slice(m.index, m.index + name.length) : null;
      const isGhost = m && seg === ' '.repeat(name.length);
      if (!isGhost) unconfirmedRemovals.push(k);
    }

    const unconfirmedAdditions = [];
    for (const k of added) {
      const entry = newByKey.get(k);
      const src = srcByFile.get(entry.file);
      const line = Number(k.split('|')[3]);
      const origLine = (src.split('\n')[line - 1] || '');
      const isShellFile = shFiles.some((fn) => stripTxt(fn) === entry.file);
      const isArrowForm = origLine.includes('=>');
      if (!isShellFile && !isArrowForm) unconfirmedAdditions.push(k);
    }

    assert.equal(unconfirmedRemovals.length, 0, `remoções não confirmadas como fantasma: ${unconfirmedRemovals.join(', ')}`);
    assert.equal(unconfirmedAdditions.length, 0, `adições não classificadas (nem shell nem arrow): ${unconfirmedAdditions.join(', ')}`);
    ok('18', `diff motor antigo vs novo sobre corpus congelado: ${removed.length} remoção(ões) confirmada(s) como fantasma, ${added.length} adição(ões) classificada(s) (shell/arrow)`);
  });

  // === [19] regras de `#` em shell ===
  tryCase('19', () => {
    const r = extractSymbols('shell-basic.sh', 'shell', readFix('shell-basic.sh.txt'));
    const byName = new Map(r.symbols.map((s) => [s.name, s.line]));
    assert.equal(byName.get('ok'), 5, `ok esperado na linha 5, obteve ${byName.get('ok')}`);
    assert.equal(byName.get('tp_sha'), 9, `tp_sha esperado na linha 9, obteve ${byName.get('tp_sha')}`);
    assert.equal(byName.get('suggest_pack'), 18, `suggest_pack esperado na linha 18, obteve ${byName.get('suggest_pack')}`);
    assert.equal(r.symbols.length, 3, `esperado exatamente 3 funções em shell-basic.sh.txt, obteve ${r.symbols.length}: ${JSON.stringify(r.symbols)}`);
    ok('19', '${...}/$#/a#b não cortaram o resto da linha; ok/tp_sha/suggest_pack indexados com line correta');
  });

  // === [19c]/[19d] substituição de comando com aspas aninhadas / multi-linha ===
  tryCase('19c-19d', () => {
    const r = extractSymbols('shell-subst.sh', 'shell', readFix('shell-subst.sh.txt'));
    const byName = new Map(r.symbols.map((s) => [s.name, s.line]));
    assert.equal(byName.get('after_dq_subst'), 2, `after_dq_subst esperado na linha 2, obteve ${byName.get('after_dq_subst')}`);
    assert.equal(byName.get('after_backtick_subst'), 7, `after_backtick_subst esperado na linha 7, obteve ${byName.get('after_backtick_subst')}`);
    assert.equal(byName.get('after_multiline_node_subst'), 16, `after_multiline_node_subst esperado na linha 16, obteve ${byName.get('after_multiline_node_subst')}`);
    assert.equal(r.symbols.length, 3, `esperado exatamente 3 funções em shell-subst.sh.txt, obteve ${r.symbols.length}: ${JSON.stringify(r.symbols)}`);
    ok('19c-19d', 'paridade de aspas não inverteu através de $(...)/crase aninhados, inclusive multi-linha');
  });

  // === [20]/[30]/[31]/[31b] heredoc, here-string, variantes de delimitador ===
  tryCase('20-30-31-31b', () => {
    const r = extractSymbols('shell-heredoc.sh', 'shell', readFix('shell-heredoc.sh.txt'));
    const byName = new Map(r.symbols.map((s) => [s.name, s.line]));
    assert.equal(byName.get('after_plain_heredoc'), 4, `linha esperada 4, obteve ${byName.get('after_plain_heredoc')}`);
    assert.equal(byName.get('after_herestring'), 9, `linha esperada 9, obteve ${byName.get('after_herestring')}`);
    assert.equal(byName.get('after_dq_tag_heredoc'), 16, `linha esperada 16, obteve ${byName.get('after_dq_tag_heredoc')}`);
    assert.equal(byName.get('after_space_tag_heredoc'), 23, `linha esperada 23, obteve ${byName.get('after_space_tag_heredoc')}`);
    assert.equal(byName.get('after_escaped_tag_heredoc'), 30, `linha esperada 30, obteve ${byName.get('after_escaped_tag_heredoc')}`);
    assert.equal(byName.get('after_sq_tag_heredoc'), 37, `linha esperada 37, obteve ${byName.get('after_sq_tag_heredoc')}`);
    assert.equal(byName.get('after_dash_tab_heredoc'), 43, `linha esperada 43, obteve ${byName.get('after_dash_tab_heredoc')}`);
    assert.ok(!byName.has('never_indexed_after_unclosed'), 'never_indexed_after_unclosed NÃO deveria ser indexado (heredoc <<EOF7 com TAB na linha de fechamento nunca reconhece o fechamento, mascara até EOF — comportamento defensivo)');
    assert.equal(r.symbols.length, 7, `esperado exatamente 7 funções indexadas em shell-heredoc.sh.txt, obteve ${r.symbols.length}: ${JSON.stringify(r.symbols)}`);
    ok('20-30-31-31b', 'heredoc (4 variantes de delimitador + <<-TAB), here-string <<< excluído, heredoc não-fechado mascara até EOF');
  });

  // === [21] docstring Python ===
  tryCase('21', () => {
    const r = extractSymbols('docstring.py', 'python', readFix('docstring.py.txt'));
    const byName = new Map(r.symbols.map((s) => [s.name, s.line]));
    assert.equal(byName.get('Base'), 5, `Base esperado na linha 5, obteve ${byName.get('Base')}`);
    assert.equal(byName.get('method_one'), 11, `method_one esperado na linha 11, obteve ${byName.get('method_one')}`);
    assert.equal(byName.get('Real'), 15, `Real esperado na linha 15, obteve ${byName.get('Real')}`);
    assert.equal(byName.get('real_method'), 17, `real_method esperado na linha 17, obteve ${byName.get('real_method')}`);
    assert.equal(r.symbols.length, 4, `esperado exatamente 4 símbolos, obteve ${r.symbols.length}: ${JSON.stringify(r.symbols)}`);
    const realInherit = r.inherit.find((i) => i.name === 'Real');
    assert.ok(realInherit && realInherit.base === 'Base', 'Real deveria herdar de Base');
    ok('21', 'docstring triplo-aspas mascarado sem fantasma; Base/method_one/Real/real_method com line correta');
  });

  // === [26a] herança independente de ordem de entrada ===
  tryCase('26a', () => {
    const files = Array.from({ length: 6 }, (_, k) => ({
      file: `f${k}.ts`,
      symbols: [{ name: `Sym${k}`, type: 'class', line: 1 }],
      inherit: k > 0 ? [{ name: `Sym${k}`, base: `Sym${k - 1}`, line: 1 }] : [],
    }));
    const baseline = JSON.stringify(resolveInheritance(files));
    function shuffleSeeded(arr, seed) {
      let a = (seed >>> 0) || 1;
      const next = () => {
        a = (a + 0x6D2B79F5) >>> 0;
        let t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
      };
      const out = arr.slice();
      for (let i = out.length - 1; i > 0; i--) {
        const j = Math.floor(next() * (i + 1));
        [out[i], out[j]] = [out[j], out[i]];
      }
      return out;
    }
    for (let seed = 1; seed <= 20; seed++) {
      const shuffled = shuffleSeeded(files, seed);
      const got = JSON.stringify(resolveInheritance(shuffled));
      assert.equal(got, baseline, `permutação (seed ${seed}) produziu resultado diferente`);
    }
    ok('26a', 'resolveInheritance produz resultado idêntico sob 20 permutações de ordem de entrada');
  });

  // === [29]/[29b]/[29c] estado regex JS/TS ===
  tryCase('29-29b-29c', () => {
    const r = extractSymbols('ghosts.ts', 'ts', readFix('ghosts.ts.txt'));
    const byName = new Map(r.symbols.map((s) => [s.name, s.line]));
    const expected = {
      Real: 5,
      AfterRegexBacktick: 7,
      AfterLineCommentPrecedence: 9,
      AfterBlockCommentPrecedence: 11,
      AfterArrow: 13,
      useReturn: 14,
      AfterReturn: 15,
      useElse: 16,
      AfterElse: 17,
      AfterCharClassQuotes: 19,
      AfterCharClassEscape: 21,
      ArrowExport: 22,
    };
    for (const [name, line] of Object.entries(expected)) {
      assert.equal(byName.get(name), line, `${name} esperado na linha ${line}, obteve ${byName.get(name)}`);
    }
    assert.equal(r.symbols.length, Object.keys(expected).length, `esperado exatamente ${Object.keys(expected).length} símbolos, obteve ${r.symbols.length}: ${JSON.stringify(r.symbols)}`);
    ok('29-29b-29c', 'regex-com-crase não abriu template literal; precedência //,/* sobre regex; arrow/return/else abrem regex; classe de caracteres não fecha regex prematuramente');
  });

  // === [32] oráculo de corpus real .mjs ===
  tryCase('32', () => {
    const files = fs.readdirSync(LIB).filter((n) => n.endsWith('.mjs'));
    assert.ok(files.length > 10, `esperado >10 arquivos .mjs em lib/, achou ${files.length}`);
    let total = 0;
    for (const fn of files) {
      const src = fs.readFileSync(path.join(LIB, fn), 'utf8');
      const r = extractSymbols(fn, 'js', src);
      total += r.symbols.length;
    }
    assert.ok(total > 100, `esperado >100 símbolos agregados sobre lib/*.mjs real, obteve ${total}`);
    ok('32', `oráculo de corpus real .mjs: ${files.length} arquivos, ${total} símbolos, sem crash`);
  });

  // === [32b] oráculo de corpus real shell ===
  tryCase('32b', () => {
    const shFiles = walk(path.join(WS, 'template/.forge/scripts'), ['.sh']);
    assert.ok(shFiles.length > 10, `esperado >10 arquivos .sh sob template/.forge/scripts, achou ${shFiles.length}`);
    let total = 0;
    for (const fp of shFiles) {
      const src = fs.readFileSync(fp, 'utf8');
      const r = extractSymbols(path.relative(WS, fp), 'shell', src);
      total += r.symbols.length;
    }
    assert.ok(total > 50, `esperado >50 funções shell agregadas sobre o corpus real, obteve ${total}`);
    ok('32b', `oráculo de corpus real shell: ${shFiles.length} arquivos, ${total} funções, sem crash`);
  });

  // === PBT P2 — sem duplicata (file,name,type,line) ===
  tryCaseAsyncSafe('pbt-p2', async () => {
    const pbt = await import('file://' + path.join(LIB, 'pbt.mjs'));
    const prop = (n) => {
      let src = '';
      for (let k = 0; k < n; k++) src += `class Foo${k} {}\n`;
      src += 'class Dup {} class Dup {}\n';
      const { symbols } = extractSymbols('synthetic.cs', 'csharp', src);
      const keys = symbols.map((s) => `${s.name}|${s.type}|${s.line}`);
      return new Set(keys).size === keys.length;
    };
    const r = pbt.forAll([pbt.gen.int(1, 8)], prop, { seed: 20261104, runs: 30 });
    assert.ok(r.ok, `P2 falhou: ${JSON.stringify(r.counterexample)}`);
    ok('pbt-p2', `P2 (sem duplicata (file,name,type,line)) — ${r.runs} casos, seed ${r.seed}`);
  });

  // === PBT P4-herança — invariância sob permutação ===
  tryCaseAsyncSafe('pbt-p4', async () => {
    const pbt = await import('file://' + path.join(LIB, 'pbt.mjs'));
    const prop = (size) => {
      const files = Array.from({ length: size }, (_, k) => ({
        file: `pf${k}.ts`,
        symbols: [{ name: `PSym${k}`, type: 'class', line: 1 }],
        inherit: k > 0 ? [{ name: `PSym${k}`, base: `PSym${k - 1}`, line: 1 }] : [],
      }));
      const rnd = pbt.makeRandom(size + 1);
      const shuffled = pbt.shuffle(files, rnd);
      return JSON.stringify(resolveInheritance(files)) === JSON.stringify(resolveInheritance(shuffled));
    };
    const r = pbt.forAll([pbt.gen.int(2, 10)], prop, { seed: 777, runs: 25 });
    assert.ok(r.ok, `P4-herança falhou: ${JSON.stringify(r.counterexample)}`);
    ok('pbt-p4', `P4-herança (invariância sob permutação) — ${r.runs} casos, seed ${r.seed}`);
  });

  // === PBT P5 — invariância cosmética ===
  tryCaseAsyncSafe('pbt-p5', async () => {
    const pbt = await import('file://' + path.join(LIB, 'pbt.mjs'));
    const prop = (nInserted) => {
      const before = 'class Foo {}\n';
      const noise = Array.from({ length: nInserted }, (_, k) => `// noise ${k}\n`).join('');
      const after = noise + before;
      const r1 = extractSymbols('f.cs', 'csharp', before);
      const r2 = extractSymbols('f.cs', 'csharp', after);
      if (r1.symbols.length !== 1 || r2.symbols.length !== 1) return false;
      const a = r1.symbols[0], b = r2.symbols[0];
      return a.name === b.name && a.type === b.type && b.line === a.line + nInserted;
    };
    const r = pbt.forAll([pbt.gen.int(0, 15)], prop, { seed: 555, runs: 20 });
    assert.ok(r.ok, `P5 falhou: ${JSON.stringify(r.counterexample)}`);
    ok('pbt-p5', `P5 (invariância cosmética) — ${r.runs} casos, seed ${r.seed}`);
  });

  console.log(fail ? '__GATE_FAIL__' : '__GATE_OK__');
  process.exit(fail);
}

async function tryCaseAsync(tag, fn) {
  try { await fn(); } catch (e) { bad(tag, e && e.message ? e.message : String(e)); }
}
async function tryCaseAsyncSafe(tag, fn) { return tryCaseAsync(tag, fn); }

main().catch((e) => {
  console.log(`FAIL [fatal]: ${e && e.stack ? e.stack : e}`);
  process.exit(1);
});
NODEEOF
)"
rc=$?
echo "$OUT"

if [ "$rc" -ne 0 ] || printf '%s\n' "$OUT" | grep -q '^FAIL '; then
  exit 1
fi

echo "PASS — extrator puro de símbolos + lexer de pilha de frames (STORY-02/TASK-03)"
exit 0
