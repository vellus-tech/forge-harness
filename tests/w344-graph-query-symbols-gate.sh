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
# STORY-03: [DD-02] walk unificado puro (graph-walk.mjs, TASK-04). [5a] graph-build.mjs grava
# symbols.json/symbols.idx.tsv de verdade (TASK-05) — determinismo (dois builds), projeção exata
# idx<->json (P6), herança sobrevive à integração e é independente de ordem física do walk (26b).
#
# STORY-05 (TASK-09/10/11): graph.sh query migra do `node -e` inline para graph-query.mjs.
#   [1]    controle byte a byte — golden pré-mudança (TASK-02) sem symbols.json
#   [2]    acerto de símbolo real (processarPedido, fixture golden)
#   [3]    ranking exato→prefixo→substring
#   [10a]  --json básico ({nodes,edges,symbols}, sem hint com resultado)
#   [24a]  desempate entre arquivos (saída humana)
#   [cli-symlink] guard de CLI via realpathSync funcionando através de symlink real em /tmp —
#          prova direta do padrão kb-cli.mjs (nunca import.meta.url===file://argv[1])
#   PBT P1 (completude), P3 (metamórfica substring⊆substring), P4-desempate (permutação)
#   [7b]   sufixo de defasagem por {mtime,size} sem rebuild
#   [10b]  --json completo com `stale`
#   [11]   query nunca escreve em disco (mtime de graph.json/symbols.json intactos)
#   [22b]  defasagem some após `graph.sh update` real
#   [6b]   staleness de fingerprint-only (graph.json tamperado) não é confundida com {mtime,size}
#   [23]   dica de 0-resultados (texto canônico idêntico em modo humano e --json)
#   [24b]  desempate completo refletido em --json
#   [14]   ENOENT por símbolo individual (sufixo + missing:true, isolado)
#   [15]   symbols.json corrompido degrada para nodes/edges-only, sem crash
#   [16]   entrada legada sem mtime/size → "não verificável"
#   [16b]  vacuidade genuína (projeto só .go) não dispara aviso falso de formato legado
#   [17b]  symbols.json órfão pós-"pull" simulado não crasha a query
#
# TDD red-first (DD-08): o módulo graph-symbols-extract.mjs é novo sob template/.forge/scripts/
# (isInfraPath) — o commit vermelho desta task toca só este arquivo em tests/. Red via import()
# dinâmico + try/catch, convertendo ERR_MODULE_NOT_FOUND numa asserção assert.fail própria
# (cenário [0]), nunca um stub neutro de produção. [5a]/[DD-02] são export novo em módulo
# existente/novo: red por comportamento ausente (symbols.json não gravado / módulo ausente),
# nunca por diff de produção no commit vermelho. graph-query.mjs (STORY-05) é módulo NOVO: o
# commit vermelho de TASK-09 toca só tests/, via import() dinâmico convertido em assert.fail
# (padrão [0]) quando o módulo ainda não existe.
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
const GRAPH_SH = path.join(WS, 'template/.forge/scripts/graph.sh');

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

  // === [DD-02] graph-walk.mjs — walk unificado puro (STORY-03/TASK-04) ===
  // RED-first (DD-08, módulo novo): import() dinâmico convertido em assert.fail quando o módulo
  // ainda não existe. Isolado dos demais blocos deste gate — uma falha aqui não aborta o arquivo
  // inteiro (diferente do [0] acima, que é a guarda de existência do módulo de símbolos).
  await tryCaseAsync('DD-02', async () => {
    let walkMod;
    try {
      walkMod = await import('file://' + path.join(LIB, 'graph-walk.mjs'));
    } catch (e) {
      assert.fail('RED TASK-04: graph-walk.mjs ainda não existe');
    }
    const { walkSourceFiles, SKIP_DIRS, SKIP_UNDER_BIN, CENSUS_EXT, LANG: WALK_LANG, SKIP_FILE } = walkMod;
    assert.equal(typeof walkSourceFiles, 'function', 'walkSourceFiles ausente ou não-função');
    for (const [label, v] of Object.entries({ SKIP_DIRS, SKIP_UNDER_BIN, CENSUS_EXT, LANG: WALK_LANG, SKIP_FILE })) {
      assert.ok(v !== undefined, `constante ausente: ${label}`);
    }

    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-walk-'));
    try {
      fs.mkdirSync(path.join(tmp, 'node_modules'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'node_modules', 'skip.js'), 'skip');
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'a.ts'), 'export const a = 1;\n');
      fs.writeFileSync(path.join(tmp, 'src', 'b.go'), 'package main\n');
      fs.writeFileSync(path.join(tmp, 'src', 'c.sh'), '#!/usr/bin/env bash\n');
      fs.writeFileSync(path.join(tmp, 'src', 'd.rb'), '# ruby, sem LANG\n');
      fs.mkdirSync(path.join(tmp, 'bin', 'Debug'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'bin', 'Debug', 'skip.cs'), 'class Skip {}\n');
      fs.writeFileSync(path.join(tmp, 'bin', 'real.cs'), 'class Real {}\n');
      fs.mkdirSync(path.join(tmp, '.hidden'), { recursive: true });
      fs.writeFileSync(path.join(tmp, '.hidden', 'forced.ts'), 'export const forced = 1;\n');

      // sem includeGlobs: comportamento de hoje — node_modules/ e bin/Debug/ podados, .hidden/
      // pulado por prefixo de ponto, census conta .rb mesmo sem entrar em files
      const plain = walkSourceFiles({ root: tmp });
      const relPlain = plain.files.map((f) => path.relative(tmp, f)).sort();
      assert.deepEqual(relPlain, ['bin/real.cs', 'src/a.ts', 'src/b.go', 'src/c.sh'].sort(),
        `walk sem include_paths: esperado 3 arquivos, obteve ${JSON.stringify(relPlain)}`);
      assert.equal(plain.census.ruby, 1, 'census deveria contar .rb mesmo sem LANG-match');
      assert.ok(!('go' in plain.census) === false, 'census deveria contar .go também');

      // com includeGlobs casando .hidden: forcedInclude vence o prefixo de ponto
      const forced = walkSourceFiles({ root: tmp, includeGlobs: [/^\.hidden(?:\/.*)?$/] });
      const relForced = forced.files.map((f) => path.relative(tmp, f)).sort();
      assert.ok(relForced.includes('.hidden/forced.ts'), 'include_paths deveria forçar .hidden/ a entrar no walk');
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
    ok('DD-02', 'walkSourceFiles pura: {files,census} sem closure, respeita SKIP_DIRS/SKIP_UNDER_BIN/include_paths, inclui .sh/.go');
  });

  // === [5a] graph-build.mjs grava symbols.json/symbols.idx.tsv de verdade (STORY-03/TASK-05) ===
  // RED-first (DD-08, export novo em módulo existente): roda `graph.sh build` (via node direto no
  // script, mesma invocação) sobre um fixture sintético e verifica que os dois artefatos existem,
  // têm conteúdo coerente, são determinísticos entre duas rodadas (byte a byte, incluindo
  // mtime/size) e que a herança sobrevive à integração E é independente da ordem física do walk
  // (26b — duas cópias do mesmo fixture, criadas em ORDEM INVERSA de arquivo, mtime forçado igual
  // via utimesSync para isolar a variável "ordem" de "tempo de criação").
  await tryCaseAsync('5a', async () => {
    const { execFileSync } = require('node:child_process');
    const BUILD = path.join(LIB, 'graph-build.mjs');

    function writeProject(dir, order) {
      // order: array de [relPath, conteúdo], escrito NESTA ordem — simula walk físico distinto.
      for (const [rel, content] of order) {
        const p = path.join(dir, rel);
        fs.mkdirSync(path.dirname(p), { recursive: true });
        fs.writeFileSync(p, content);
      }
      // mtime fixo e idêntico em ambas as cópias — isola "ordem de criação" de "ordem de walk".
      const fixedTime = new Date('2026-01-01T00:00:00Z');
      for (const [rel] of order) {
        fs.utimesSync(path.join(dir, rel), fixedTime, fixedTime);
      }
    }

    const FILES = [
      ['base.ts', 'export class Base {}\n'],
      ['child.ts', 'export class Child extends Base {}\n'],
      ['dup/a.ts', 'export class Dup {}\n'],
      ['dup/b.ts', 'export class Dup {}\n'],
      ['script.sh', '#!/usr/bin/env bash\nfoo() {\n  echo hi\n}\n'],
      ['mod.py', 'class PyBase:\n    pass\n\n\nclass PyChild(PyBase):\n    pass\n'],
    ];
    const REVERSED = FILES.slice().reverse();

    const tmpA = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-build-a-'));
    const tmpB = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-build-b-'));
    try {
      writeProject(tmpA, FILES);
      writeProject(tmpB, REVERSED);

      execFileSync('node', [BUILD, tmpA], { stdio: 'pipe' });
      const symJsonPathA = path.join(tmpA, '.forge/graph/symbols.json');
      const idxPathA = path.join(tmpA, '.forge/graph/symbols.idx.tsv');
      assert.ok(fs.existsSync(symJsonPathA) && fs.statSync(symJsonPathA).size > 0,
        'symbols.json deveria existir e não estar vazio após graph.sh build');
      assert.ok(fs.existsSync(idxPathA) && fs.statSync(idxPathA).size > 0,
        'symbols.idx.tsv deveria existir e não estar vazio após graph.sh build (par atômico)');

      const symA1 = fs.readFileSync(symJsonPathA, 'utf8');
      const idxA1 = fs.readFileSync(idxPathA, 'utf8');
      const parsedA1 = JSON.parse(symA1);
      assert.equal(parsedA1.schema, 'symbols/v0', 'schema deveria ser symbols/v0');
      const childEdge = parsedA1.edges.find((e) => e.kind === 'inherits' && e.from === 'child.ts#Child');
      assert.ok(childEdge && childEdge.resolved === true && childEdge.to === 'base.ts#Base',
        `herança Child->Base deveria resolver (TS); obteve ${JSON.stringify(childEdge)}`);
      const pyEdge = parsedA1.edges.find((e) => e.kind === 'inherits' && e.from === 'mod.py#PyChild');
      assert.ok(pyEdge && pyEdge.resolved === true && pyEdge.to === 'mod.py#PyBase',
        `herança PyChild->PyBase deveria resolver (python); obteve ${JSON.stringify(pyEdge)}`);

      // [6c]/P6 — idx.tsv é projeção EXATA de symbols.json
      const idxLinesA1 = idxA1.split('\n').filter(Boolean);
      assert.equal(idxLinesA1.length, parsedA1.symbols.length, 'idx.tsv deveria ter uma linha por símbolo');
      for (let i = 0; i < parsedA1.symbols.length; i++) {
        const s = parsedA1.symbols[i];
        assert.equal(idxLinesA1[i], `${s.name}\t${s.file}\t${s.line}\t${s.type}\t${s.layer}`,
          `linha ${i} do idx.tsv não é projeção exata do símbolo correspondente`);
      }

      // determinismo: segunda rodada sobre a MESMA árvore (fontes inalteradas) é byte a byte igual
      execFileSync('node', [BUILD, tmpA], { stdio: 'pipe' });
      const symA2 = fs.readFileSync(symJsonPathA, 'utf8');
      const idxA2 = fs.readFileSync(idxPathA, 'utf8');
      assert.equal(symA2, symA1, 'symbols.json deveria ser byte a byte idêntico entre duas rodadas (mtime/size inclusos)');
      assert.equal(idxA2, idxA1, 'symbols.idx.tsv deveria ser byte a byte idêntico entre duas rodadas');

      // [26b] independência de ordem física do walk: fixture B (ordem de criação invertida,
      // mtime forçado igual) produz symbols.json/idx.tsv byte a byte IDÊNTICOS ao A.
      execFileSync('node', [BUILD, tmpB], { stdio: 'pipe' });
      const symB = fs.readFileSync(path.join(tmpB, '.forge/graph/symbols.json'), 'utf8');
      const idxB = fs.readFileSync(path.join(tmpB, '.forge/graph/symbols.idx.tsv'), 'utf8');
      assert.equal(symB, symA1, 'symbols.json não deveria depender da ordem física do walk (26b)');
      assert.equal(idxB, idxA1, 'symbols.idx.tsv não deveria depender da ordem física do walk (26b)');

      ok('5a', 'symbols.json/symbols.idx.tsv gravados, determinísticos entre rodadas, projeção exata, herança integrada e independente de ordem física do walk');
    } finally {
      fs.rmSync(tmpA, { recursive: true, force: true });
      fs.rmSync(tmpB, { recursive: true, force: true });
    }
  });

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

  tryCase('python-docstring-escape', () => {
    const src = 'def actual():\n    """before \\"""\ndef ghost(): pass\n    """\n    pass\n\ndef after(): pass\n';
    const symbols = extractSymbols('escape.py', 'python', src).symbols;
    assert.deepEqual(symbols.map((s) => s.name), ['actual', 'after'], 'aspas escapadas não devem fechar a docstring');
    ok('python-docstring-escape', 'docstring com aspas escapadas não indexa fantasmas nem oculta declarações');
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
    const oracle = JSON.parse(fs.readFileSync(path.join(FIX, 'corpus-diff.json'), 'utf8'));
    for (const group of [oracle.removed, oracle.added]) {
      assert.ok(group.length > 0 && group.every((x) => x.key && x.reason), 'listas fixas devem conter chaves e justificativas');
      assert.equal(new Set(group.map((x) => x.key)).size, group.length, 'oráculo contém chave duplicada');
    }
    assert.deepEqual(removed.sort(), oracle.removed.map((x) => x.key).sort(), 'remoções divergem da lista congelada');
    assert.deepEqual(added.sort(), oracle.added.map((x) => x.key).sort(), 'adições divergem da lista congelada');

    // Verificação MECÂNICA (não por curadoria): roda o PRÓPRIO motor antigo (DECL sem masking)
    // sobre o texto JÁ MASCARADO pelo lexer novo (stripCommentsPreservingLines). Se a chave
    // removida não reaparece quando o motor antigo lê o texto mascarado, o masking é a causa
    // mecânica comprovada da remoção — nunca uma afirmação de curadoria manual. Cobre também o
    // caso de fantasma cross-line (ex. `\s+` do motor antigo casando um comentário "// ... function"
    // com o início de linha seguinte).
    const oldOnMaskedKeysByFile = new Map();
    function oldKeysOnMasked(file, lang) {
      if (oldOnMaskedKeysByFile.has(file)) return oldOnMaskedKeysByFile.get(file);
      const masked = maskedByFile.get(file);
      const set = new Set(oldMod.extractSymbolsOldEngine(lang, masked).map((s) => `${file}|${s.name}|${s.type}|${s.line}`));
      oldOnMaskedKeysByFile.set(file, set);
      return set;
    }
    const unconfirmedRemovals = [];
    for (const k of removed) {
      const [file] = k.split('|');
      const lang = shFiles.some((fn) => stripTxt(fn) === file) ? 'shell' : 'js';
      const stillThere = oldKeysOnMasked(file, lang).has(k);
      if (stillThere) unconfirmedRemovals.push(k);
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

  // O motor antigo fornece as linhas de referência para cada declaração conhecida.
  await tryCaseAsync('32', async () => {
    const old = await import('file://' + path.join(FIX, 'old-engine-snapshot.mjs'));
    const names = {
      'api-surface.mjs': ['policyTableAnchored', 'fromChecklist'],
      'red-classify.mjs': ['classify', 'countsAsRed'],
      'route-scan.mjs': ['resolveSpec', 'posixDirname', 'posixJoin', 'candidatasVisiveis', 'compose', 'walk', 'scanRoutes', 'routeKeys'],
      'tasks-graph.mjs': ['trimWrappers', 'parseTasks', 'checkTasksGraph', 'parseSurfaceChecklist', 'checkSurfaceChecklistLiteral', 'checkSurfaceChecklistPresence', 'namesApiSurface'],
      'untrusted-render.mjs': ['renderUntrusted'],
    };
    for (const [file, expected] of Object.entries(names)) {
      const src = fs.readFileSync(path.join(FIX, 'corpus-snapshot', file + '.txt'), 'utf8');
      const oldSymbols = old.extractSymbolsOldEngine('js', src);
      const actual = extractSymbols(file, 'js', src).symbols;
      for (const name of expected) {
        const reference = oldSymbols.filter((s) => s.name === name);
        assert.equal(reference.length, 1, `${file}:${name}: referência antiga ausente ou ambígua`);
        assert.ok(actual.some((s) => s.name === name && s.line === reference[0].line), `${file}:${name}:${reference[0].line} ausente`);
      }
    }
    ok('32', '20 declarações reais verificadas nominalmente no corpus congelado');
  });

  // === [32b] oráculo nominal de corpus shell congelado ===
  tryCase('32b', () => {
    const oracle = JSON.parse(fs.readFileSync(path.join(FIX, 'corpus-diff.json'), 'utf8'));
    for (const file of ['doctor.sh', 'pentest-ops.sh']) {
      const src = fs.readFileSync(path.join(FIX, 'corpus-snapshot-shell', file + '.txt'), 'utf8');
      const actual = extractSymbols(file, 'shell', src).symbols;
      const expected = oracle.added.map((x) => x.key).filter((key) => key.startsWith(file + '|'));
      assert.ok(expected.length > 0, `${file}: lista nominal vazia`);
      for (const key of expected) {
        const [, name, type, line] = key.split('|');
        assert.ok(actual.some((s) => s.name === name && s.type === type && s.line === Number(line)), `${key} ausente`);
      }
      if (file === 'doctor.sh') for (const name of ['tp_sha','suggest_pack','try_install','check_dotnet','check_node','check_python','check_java','check_kotlin']) {
        assert.ok(expected.some((key) => key.split('|')[1] === name), `${file}:${name} ausente do oráculo`);
      }
    }
    ok('32b', 'declarações shell verificadas por nome e linha no corpus congelado');
  });

  tryCase('33', () => {
    const phrase = 'busca por nome de símbolo (classe/função) com arquivo:linha, não só por caminho de arquivo';
    const files = ['template/.forge/commands/graph/query.md', 'template/.forge/rules/conventions/lsp-impact-analysis.md', 'template/.forge/commands/specs/implement.md', 'README.md'];
    for (const file of files) assert.ok(fs.readFileSync(path.join(WS, file), 'utf8').includes(phrase), `${file}: frase ausente`);
    const query = fs.readFileSync(path.join(WS, files[0]), 'utf8');
    assert.ok(query.split('\n').find((line) => line.startsWith('description:')).includes(phrase), 'description de query não contém a frase');
    const graph = fs.readFileSync(GRAPH_SH, 'utf8');
    assert.match(graph, /query <term>[^\n]*symbols/);
    assert.match(graph, /usage: graph\.sh[^\n]*symbols/);
    const rule = fs.readFileSync(path.join(WS, files[1]), 'utf8');
    assert.doesNotMatch(rule, /não entende semântica de símbolo/);
    assert.match(rule, /tipo, overload ou call graph/);
    const update = fs.readFileSync(path.join(WS, 'template/.forge/commands/graph/update.md'), 'utf8');
    assert.doesNotMatch(update, /nada é reprocessado|sem reprocessar/i);
    const updatePlugin = fs.readFileSync(path.join(WS, 'plugin/forge/commands/update.md'), 'utf8');
    assert.doesNotMatch(updatePlugin, /nada é reprocessado|sem reprocessar/i);
    ok('33', 'fiação da documentação e das descrições validada');
  });

  // === PBT P2 — sem duplicata (file,name,type,line) ===
  await tryCaseAsyncSafe('pbt-p2', async () => {
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
  await tryCaseAsyncSafe('pbt-p4', async () => {
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
  await tryCaseAsyncSafe('pbt-p5', async () => {
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

  // === [5b]/[12]/[12b]/[22a] — `--if-changed` honesto em graph-build.mjs (STORY-04/TASK-06) ===
  // RED-first (DD-08, export/flag novo em módulo existente): hoje graph-build.mjs ignora
  // `--if-changed` (flag inexistente) e sempre regrava incondicionalmente — os 4 cenários abaixo
  // detectam isso por COMPORTAMENTO real (mtime do arquivo de saída), nunca por diff de produção.
  await tryCaseAsync('5b', async () => {
    const { execFileSync } = require('node:child_process');
    const BUILD = path.join(LIB, 'graph-build.mjs');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-ifchanged-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'a.ts'), 'export class A {}\n');
      execFileSync('node', [BUILD, tmp], { stdio: 'pipe' });
      const graphPath = path.join(tmp, '.forge/graph/graph.json');
      const mtime1 = fs.statSync(graphPath).mtimeMs;
      execFileSync('node', [BUILD, tmp, '--if-changed'], { stdio: 'pipe' });
      const mtime2 = fs.statSync(graphPath).mtimeMs;
      assert.equal(mtime2, mtime1, 'graph.json não deveria ser regravado sob --if-changed quando nada mudou');
      ok('5b', 'graph.json não regravado sob --if-changed sem mudança real');
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  await tryCaseAsync('12', async () => {
    const { execFileSync } = require('node:child_process');
    const BUILD = path.join(LIB, 'graph-build.mjs');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-honest-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'a.ts'), 'export class A {}\n');
      fs.writeFileSync(path.join(tmp, 'script.sh'), '#!/usr/bin/env bash\nfoo() {\n  echo hi\n}\n');
      execFileSync('node', [BUILD, tmp], { stdio: 'pipe' });
      const artifacts = [
        '.forge/graph/graph.json',
        '.forge/graph/cache/fingerprints.json',
        '.forge/graph/cache/summaries.json',
        '.forge/graph/report.md',
        '.forge/graph/symbols.json',
        '.forge/graph/symbols.idx.tsv',
      ].map((p) => path.join(tmp, p));
      execFileSync('node', [BUILD, tmp, '--if-changed'], { stdio: 'pipe' });
      fs.utimesSync(path.join(tmp, '.forge/graph/report.md'), 1000000000, 1000000000);
      const before = artifacts.map((p) => fs.statSync(p).mtimeMs);
      execFileSync('node', [BUILD, tmp, '--if-changed'], { stdio: 'pipe' });
      const after = artifacts.map((p) => fs.statSync(p).mtimeMs);
      for (let i = 0; i < artifacts.length; i++) {
        assert.equal(after[i], before[i], `${artifacts[i]} foi regravado no segundo update sem toque real`);
      }
      const reportPath = path.join(tmp, '.forge/graph/report.md');
      fs.writeFileSync(reportPath, 'relatório corrompido');
      execFileSync('node', [BUILD, tmp, '--if-changed'], { stdio: 'pipe' });
      assert.match(fs.readFileSync(reportPath, 'utf8'), /^# Code Graph — report/m, 'update deve reparar relatório alterado');
      fs.utimesSync(reportPath, 1000000000, 1000000000);
      execFileSync('node', [BUILD, tmp], { stdio: 'pipe' });
      assert.notEqual(fs.statSync(reportPath).mtimeMs, 1000000000000, 'build deve forçar a gravação');
      ok('12', 'dois updates --if-changed consecutivos sem toque real: zero regravação nos 6 artefatos (mtime)');
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  await tryCaseAsync('12b', async () => {
    const { execFileSync } = require('node:child_process');
    const BUILD = path.join(LIB, 'graph-build.mjs');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-corrupt-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'a.ts'), 'export class A {}\n');
      execFileSync('node', [BUILD, tmp], { stdio: 'pipe' });
      const graphPath = path.join(tmp, '.forge/graph/graph.json');
      fs.writeFileSync(graphPath, '{ not valid json ');
      execFileSync('node', [BUILD, tmp, '--if-changed'], { stdio: 'pipe' });
      const parsed = JSON.parse(fs.readFileSync(graphPath, 'utf8'));
      assert.equal(parsed.schema, 'graph/v0', 'graph.json corrompido deveria ser reescrito incondicionalmente sob --if-changed');
      ok('12b', 'graph.json corrompido em disco força escrita incondicional sob --if-changed');
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  await tryCaseAsync('22a', async () => {
    const { execFileSync } = require('node:child_process');
    const BUILD = path.join(LIB, 'graph-build.mjs');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-mtime-size-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      const target = path.join(tmp, 'src', 'f.ts');
      fs.writeFileSync(target, 'export function foo() {\n  return 1;\n}\n');
      execFileSync('node', [BUILD, tmp], { stdio: 'pipe' });
      const symbolsPath = path.join(tmp, '.forge/graph/symbols.json');
      const before = JSON.parse(fs.readFileSync(symbolsPath, 'utf8'));
      const beforeSym = before.symbols.find((s) => s.name === 'foo');
      assert.ok(beforeSym, 'símbolo foo deveria existir antes da edição');

      // edita só o CORPO (mesmo name/line/type) — tamanho do arquivo muda
      fs.writeFileSync(target, 'export function foo() {\n  return 12345;\n}\n');
      const future = new Date(Date.now() + 5000);
      fs.utimesSync(target, future, future);

      execFileSync('node', [BUILD, tmp, '--if-changed'], { stdio: 'pipe' });
      const after = JSON.parse(fs.readFileSync(symbolsPath, 'utf8'));
      const afterSym = after.symbols.find((s) => s.name === 'foo');
      assert.ok(afterSym, 'símbolo foo deveria existir depois da edição');
      assert.notEqual(afterSym.size, beforeSym.size, 'size deveria mudar após editar o corpo da função');
      assert.notEqual(afterSym.mtime, beforeSym.mtime, 'mtime deveria mudar após editar o corpo da função');
      ok('22a', `{mtime,size} de symbols.json atualizados após editar só o corpo (size ${beforeSym.size}->${afterSym.size})`);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // === [4]/[4c]/[6a]/[17a]/[28] — integridade referencial symbols<->graph em validate-graph.mjs
  // (STORY-04/TASK-08). RED-first: validate-graph.mjs hoje nunca lê symbols.json — [4]/[4c]/[6a]/
  // [17a] detectam a ausência do comportamento; [28] é controle negativo (já verde hoje, e deve
  // continuar verde depois).
  const VALIDATE = path.join(LIB, 'validate-graph.mjs');

  function writeGraphFixture(dir) {
    const graphDir = path.join(dir, '.forge/graph');
    fs.mkdirSync(graphDir, { recursive: true });
    const graph = {
      schema: 'graph/v0',
      generated_at: new Date().toISOString(),
      engine: 'native',
      root: dir,
      stats: { nodes: 1, edges: 0, languages: ['ts'], summaries_stale: 0, census: { ts: 1 }, layer_coverage: { classified: 1, unclassified: 0, out_of_taxonomy: 0, denominator: 1, ratio: 1 } },
      nodes: [{ id: 'src/a.ts', lang: 'ts', loc: 1, fingerprint: 'a'.repeat(64), layer: 'domain', summary: null }],
      edges: [],
    };
    fs.writeFileSync(path.join(graphDir, 'graph.json'), JSON.stringify(graph, null, 2) + '\n');
    return { graphDir, graph };
  }

  await tryCaseAsync('4', async () => {
    const { execFileSync } = require('node:child_process');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-val-orphan-'));
    try {
      const { graphDir } = writeGraphFixture(tmp);
      const symbols = { schema: 'symbols/v0', engine: 'native-regex', note: 'x', stats: {}, symbols: [{ id: 'src/ghost.ts#Foo', file: 'src/ghost.ts', name: 'Foo', type: 'function', line: 1, layer: 'unknown', mtime: 1, size: 1 }], edges: [] };
      fs.writeFileSync(path.join(graphDir, 'symbols.json'), JSON.stringify(symbols, null, 2) + '\n');
      let out, rc = 0;
      try { out = execFileSync('node', [VALIDATE, path.join(graphDir, 'graph.json'), tmp], { stdio: 'pipe' }).toString(); }
      catch (e) { rc = e.status; out = (e.stdout || '').toString() + (e.stderr || '').toString(); }
      assert.notEqual(rc, 0, 'validate-graph deveria reprovar symbol.file órfão (src/ghost.ts não existe em graph.json)');
      assert.match(out, /src\/ghost\.ts/, 'mensagem de FAIL deveria citar o arquivo órfão explicitamente');
      ok('4', 'validate-graph reprova symbol.file órfão com mensagem explícita citando o arquivo');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  await tryCaseAsync('4c', async () => {
    const { execFileSync } = require('node:child_process');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-val-corrupt-'));
    try {
      const { graphDir } = writeGraphFixture(tmp);
      fs.writeFileSync(path.join(graphDir, 'symbols.json'), '{ not valid json');
      let out, rc = 0;
      try { out = execFileSync('node', [VALIDATE, path.join(graphDir, 'graph.json'), tmp], { stdio: 'pipe' }).toString(); }
      catch (e) { rc = e.status; out = (e.stdout || '').toString() + (e.stderr || '').toString(); }
      assert.notEqual(rc, 0, 'validate-graph deveria reprovar symbols.json corrompido');
      assert.match(out, /symbols\.json/i, 'FAIL de symbols.json corrompido deveria citar symbols.json');
      assert.doesNotMatch(out, /referential integrity|orphan symbol file/i, 'FAIL de parse deveria ser DEDICADO, distinto da mensagem de órfão');
      ok('4c', 'symbols.json corrompido produz FAIL dedicado (parse), distinto da mensagem de órfão');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  await tryCaseAsync('6a', async () => {
    const { execFileSync } = require('node:child_process');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-val-mutation-'));
    try {
      const { graphDir } = writeGraphFixture(tmp);
      // controle: symbol.file existe de verdade em graph.json -> validate deveria passar (OK)
      const symbolsControl = { schema: 'symbols/v0', engine: 'native-regex', note: 'x', stats: {}, symbols: [{ id: 'src/a.ts#Foo', file: 'src/a.ts', name: 'Foo', type: 'function', line: 1, layer: 'domain', mtime: 1, size: 1 }], edges: [] };
      fs.writeFileSync(path.join(graphDir, 'symbols.json'), JSON.stringify(symbolsControl, null, 2) + '\n');
      let rcControl = 0;
      try { execFileSync('node', [VALIDATE, path.join(graphDir, 'graph.json'), tmp], { stdio: 'pipe' }); }
      catch (e) { rcControl = e.status; }
      assert.equal(rcControl, 0, 'controle: symbol.file existente em graph.json não deveria reprovar');

      // recontrole (mutação): symbol.file inexistente -> validate DEVE reprovar
      const symbolsMutated = { schema: 'symbols/v0', engine: 'native-regex', note: 'x', stats: {}, symbols: [{ id: 'src/removed.ts#Foo', file: 'src/removed.ts', name: 'Foo', type: 'function', line: 1, layer: 'domain', mtime: 1, size: 1 }], edges: [] };
      fs.writeFileSync(path.join(graphDir, 'symbols.json'), JSON.stringify(symbolsMutated, null, 2) + '\n');
      let rcMutated = 0;
      try { execFileSync('node', [VALIDATE, path.join(graphDir, 'graph.json'), tmp], { stdio: 'pipe' }); }
      catch (e) { rcMutated = e.status; }
      assert.notEqual(rcMutated, 0, 'mutação: symbol.file inexistente (src/removed.ts) deveria reprovar');
      ok('6a', 'mutação com controle/recontrole: arquivo existente passa, arquivo inexistente reprova');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  await tryCaseAsync('17a', async () => {
    const { execFileSync } = require('node:child_process');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-val-pull-'));
    try {
      const { graphDir } = writeGraphFixture(tmp);
      // symbols.json referencia src/a.ts (existe em graph.json) — simula um pull que REMOVEU o
      // node do graph.json sem reconstruir symbols.json (órfão pós-pull, sem rebuild do grafo).
      const symbols = { schema: 'symbols/v0', engine: 'native-regex', note: 'x', stats: {}, symbols: [{ id: 'src/a.ts#Foo', file: 'src/a.ts', name: 'Foo', type: 'function', line: 1, layer: 'domain', mtime: 1, size: 1 }], edges: [] };
      fs.writeFileSync(path.join(graphDir, 'symbols.json'), JSON.stringify(symbols, null, 2) + '\n');
      const graphAfterPull = JSON.parse(fs.readFileSync(path.join(graphDir, 'graph.json'), 'utf8'));
      graphAfterPull.nodes = [];
      graphAfterPull.stats.nodes = 0;
      fs.writeFileSync(path.join(graphDir, 'graph.json'), JSON.stringify(graphAfterPull, null, 2) + '\n');
      let rc = 0, out = '';
      try { out = execFileSync('node', [VALIDATE, path.join(graphDir, 'graph.json'), tmp], { stdio: 'pipe' }).toString(); }
      catch (e) { rc = e.status; out = (e.stdout || '').toString() + (e.stderr || '').toString(); }
      assert.notEqual(rc, 0, 'órfão pós-pull (symbols.json aponta para node removido do graph.json) deveria reprovar');
      assert.match(out, /src\/a\.ts/, 'FAIL deveria citar src/a.ts como órfão');
      ok('17a', 'órfão pós-"git pull" simulado (graph.json reconstruído sem rebuild de symbols.json) reprova');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  tryCase('28', () => {
    const { execFileSync } = require('node:child_process');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-val-nosymbols-'));
    try {
      const { graphDir } = writeGraphFixture(tmp);
      let rc = 0, out = '';
      try { out = execFileSync('node', [VALIDATE, path.join(graphDir, 'graph.json'), tmp], { stdio: 'pipe' }).toString(); }
      catch (e) { rc = e.status; out = (e.stdout || '').toString() + (e.stderr || '').toString(); }
      assert.equal(rc, 0, `ausência de symbols.json não deveria reprovar validate; saída: ${out}`);
      ok('28', 'ausência de symbols.json pula a checagem de integridade referencial (controle negativo)');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // =============================================================================================
  // STORY-05 (TASK-09/10/11) — graph.sh query migra para graph-query.mjs
  // =============================================================================================
  const QUERY_MOD_PATH = path.join(LIB, 'graph-query.mjs');

  function runQuery(root, args) {
    const { spawnSync } = require('node:child_process');
    const result = spawnSync('bash', [GRAPH_SH, 'query', ...args], { encoding: 'utf8', env: { ...process.env, FORGE_ROOT: root } });
    if (result.error) throw result.error;
    return { stdout: result.stdout, stderr: result.stderr, code: result.status };
  }
  function buildAt(root) {
    const { execFileSync } = require('node:child_process');
    execFileSync('bash', [GRAPH_SH, 'build'], { stdio: 'pipe', env: { ...process.env, FORGE_ROOT: root } });
  }
  function updateAt(root) {
    const { execFileSync } = require('node:child_process');
    execFileSync('bash', [GRAPH_SH, 'update'], { stdio: 'pipe', env: { ...process.env, FORGE_ROOT: root } });
  }

  // === [1] controle byte a byte — golden pré-mudança sem symbols.json (RED-first, DD-08) ===
  await tryCaseAsync('1', async () => {
    try {
      await import('file://' + QUERY_MOD_PATH);
    } catch {
      assert.fail('RED TASK-09: graph-query.mjs ainda não existe');
    }
    const { execFileSync } = require('node:child_process');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q1-'));
    try {
      execFileSync('bash', [path.join(FIX, 'golden-pre-change/make-fixture.sh'), tmp], { stdio: 'pipe' });
      buildAt(tmp);
      const symbolsPath = path.join(tmp, '.forge/graph/symbols.json');
      assert.ok(fs.existsSync(symbolsPath), 'build deveria gravar symbols.json (STORY-03 já integrada)');
      // cenário de CONTROLE: symbols.json ausente — nodes/edges precisam ser byte a byte iguais
      // ao motor ANTIGO (golden capturado na TASK-02, antes de qualquer edição desta story).
      fs.rmSync(symbolsPath);
      fs.rmSync(path.join(tmp, '.forge/graph/symbols.idx.tsv'), { force: true });
      const r = runQuery(tmp, ['processar-pedido']);
      assert.equal(r.code, 0, `query deveria sair exit 0; stderr=${r.stderr}`);
      const golden = readFix('golden-pre-change/query-golden-pre-change.txt');
      const lines = r.stdout.split('\n');
      const nodesEdgesPortion = lines.slice(0, 4).join('\n') + '\n';
      assert.equal(nodesEdgesPortion, golden, `nodes/edges deveriam ser BYTE A BYTE idênticos ao golden pré-mudança; obteve:\n${r.stdout}`);
      assert.ok(r.stdout.includes('symbols (0):'), 'seção symbols (0): deveria aparecer (aditiva) mesmo sem symbols.json');
      ok('1', 'nodes/edges byte a byte idênticos ao golden pré-mudança quando symbols.json está ausente (cenário de controle)');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [2] acerto de símbolo real (fixture golden, symbols.json presente) ===
  await tryCaseAsync('2', async () => {
    const { execFileSync } = require('node:child_process');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q2-'));
    try {
      execFileSync('bash', [path.join(FIX, 'golden-pre-change/make-fixture.sh'), tmp], { stdio: 'pipe' });
      buildAt(tmp);
      const r = runQuery(tmp, ['processarPedido']);
      assert.equal(r.code, 0, `query deveria sair exit 0; stderr=${r.stderr}`);
      assert.match(r.stdout, /^symbols \(1\):$/m, `esperado symbols (1): ao buscar por processarPedido; obteve:\n${r.stdout}`);
      assert.match(r.stdout, /^  processarPedido \[function\] src\/handlers\/processar-pedido\.js:1 \([a-z]+\)$/m,
        `esperado linha de símbolo sem sufixo de defasagem; obteve:\n${r.stdout}`);
      ok('2', 'busca por símbolo real (processarPedido) produz symbols (1): com arquivo:linha');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [3]/[10a] ranking exato→prefixo→substring + --json básico ===
  await tryCaseAsync('3', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q3-'));
    try {
      fs.mkdirSync(path.join(tmp, 'a'), { recursive: true });
      fs.mkdirSync(path.join(tmp, 'b'), { recursive: true });
      fs.mkdirSync(path.join(tmp, 'c'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'a', 'pay.ts'), 'export function Pay() {\n  return 1;\n}\n');
      fs.writeFileSync(path.join(tmp, 'b', 'payfast.ts'), 'export function PayFast() {\n  return 1;\n}\n');
      fs.writeFileSync(path.join(tmp, 'c', 'repay.ts'), 'export function repay() {\n  return 1;\n}\n');
      buildAt(tmp);
      const r = runQuery(tmp, ['pay', '--json']);
      assert.equal(r.code, 0, `query --json deveria sair exit 0; stderr=${r.stderr}`);
      const data = JSON.parse(r.stdout);
      assert.deepEqual(data.symbols.map((s) => s.name), ['Pay', 'PayFast', 'repay'],
        `ordem de ranking (exato→prefixo→substring) incorreta; obteve ${JSON.stringify(data.symbols.map((s) => s.name))}`);
      ok('3', 'ranking exato→prefixo→substring: Pay (exato), PayFast (prefixo), repay (substring)');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  await tryCaseAsync('10a', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q10a-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'f.ts'), 'export function foo() {\n  return 1;\n}\n');
      buildAt(tmp);
      const r = runQuery(tmp, ['foo', '--json']);
      assert.equal(r.code, 0, `query --json deveria sair exit 0; stderr=${r.stderr}`);
      const data = JSON.parse(r.stdout);
      assert.ok(Array.isArray(data.nodes) && Array.isArray(data.edges) && Array.isArray(data.symbols),
        '--json deveria produzir {nodes,edges,symbols}');
      assert.ok(!('hint' in data), 'hint não deveria aparecer quando há resultados');
      const sym = data.symbols.find((s) => s.name === 'foo');
      assert.ok(sym, 'símbolo foo deveria aparecer em --json');
      for (const k of ['id', 'name', 'type', 'file', 'line', 'layer', 'stale']) {
        assert.ok(k in sym, `campo ${k} ausente no símbolo --json`);
      }
      assert.equal(sym.stale, false, 'stale deveria ser false imediatamente após o build');
      ok('10a', '--json básico produz {nodes,edges,symbols}, cada símbolo com {id,name,type,file,line,layer,stale}');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [24a] desempate entre arquivos (saída humana) ===
  await tryCaseAsync('24a', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q24a-'));
    try {
      fs.mkdirSync(path.join(tmp, 'd'), { recursive: true });
      fs.mkdirSync(path.join(tmp, 'e'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'd', 'dup1.ts'), 'export function Helper() {\n  return 1;\n}\n');
      fs.writeFileSync(path.join(tmp, 'e', 'dup2.ts'), 'export function Helper() {\n  return 1;\n}\n');
      buildAt(tmp);
      const r = runQuery(tmp, ['helper']);
      assert.equal(r.code, 0, `query deveria sair exit 0; stderr=${r.stderr}`);
      const idxD = r.stdout.indexOf('d/dup1.ts');
      const idxE = r.stdout.indexOf('e/dup2.ts');
      assert.ok(idxD >= 0 && idxE >= 0 && idxD < idxE,
        `desempate por file (localeCompare) deveria listar d/dup1.ts antes de e/dup2.ts; obteve:\n${r.stdout}`);
      ok('24a', 'desempate (name,file,line) entre arquivos: d/dup1.ts antes de e/dup2.ts (saída humana)');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [cli-symlink] guard de CLI via realpathSync funciona através de symlink REAL em /tmp ===
  // Prova direta do bug provado durante o design desta spec: `import.meta.url === 'file://' +
  // process.argv[1]` quebra sob symlink no macOS (/tmp e /var/folders são symlinks); o padrão
  // kb-cli.mjs (realpathSync dos dois lados) não quebra. Invoca graph-query.mjs DIRETO via um
  // symlink real criado em /tmp, sem passar por graph.sh, para isolar exatamente o guard.
  tryCase('cli-symlink', () => {
    const { execFileSync } = require('node:child_process');
    const base = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-symlink-'));
    try {
      const linkDir = path.join(base, 'linked');
      fs.mkdirSync(linkDir);
      const link = path.join(linkDir, 'graph-query.mjs');
      fs.symlinkSync(QUERY_MOD_PATH, link);

      const gdir = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-symlink-graph-'));
      try {
        fs.mkdirSync(path.join(gdir, '.forge/graph'), { recursive: true });
        const graph = { schema: 'graph/v0', nodes: [{ id: 'x/y.ts', lang: 'ts', layer: 'unknown', loc: 1 }], edges: [] };
        const graphPath = path.join(gdir, '.forge/graph/graph.json');
        fs.writeFileSync(graphPath, JSON.stringify(graph));
        const out = execFileSync('node', [link, graphPath, gdir, 'y'], { stdio: 'pipe' }).toString();
        assert.match(out, /^nodes \(1\):$/m, 'guard de CLI deveria reconhecer invocação via symlink real em /tmp e executar main()');
        ok('cli-symlink', 'guard de CLI (realpathSync dos dois lados) funciona invocando graph-query.mjs através de symlink real em /tmp');
      } finally { fs.rmSync(gdir, { recursive: true, force: true }); }
    } finally { fs.rmSync(base, { recursive: true, force: true }); }
  });

  // === PBT P1 — completude (rankSymbols não omite nem inventa matches) ===
  await tryCaseAsyncSafe('pbt-p1', async () => {
    const pbt = await import('file://' + path.join(LIB, 'pbt.mjs'));
    const queryMod = await import('file://' + QUERY_MOD_PATH);
    const prop = (n) => {
      const symbols = Array.from({ length: n }, (_, k) => ({ name: `sym${k}abc`, file: `f${k}.ts`, line: 1, type: 'function', layer: 'unknown' }));
      const term = 'abc';
      const ranked = queryMod.rankSymbols(symbols, term);
      const expected = new Set(symbols.filter((s) => s.name.toLowerCase().includes(term)).map((s) => s.name));
      const got = new Set(ranked.map((s) => s.name));
      return expected.size === got.size && [...expected].every((x) => got.has(x));
    };
    const r = pbt.forAll([pbt.gen.int(1, 15)], prop, { seed: 20261104, runs: 25 });
    assert.ok(r.ok, `P1 falhou: ${JSON.stringify(r.counterexample)}`);
    ok('pbt-p1', `P1 (completude) — ${r.runs} casos, seed ${r.seed}`);
  });

  // === PBT P3 — metamórfica: substring ⊆ substring (termo mais específico ⊆ menos específico) ===
  await tryCaseAsyncSafe('pbt-p3', async () => {
    const pbt = await import('file://' + path.join(LIB, 'pbt.mjs'));
    const queryMod = await import('file://' + QUERY_MOD_PATH);
    const prop = (n) => {
      const symbols = [
        { name: 'AlphaPayFastBeta', file: 'f0.ts', line: 1, type: 'function', layer: 'unknown' },
        { name: 'onlypay', file: 'f1.ts', line: 1, type: 'function', layer: 'unknown' },
      ];
      for (let k = 0; k < n; k++) symbols.push({ name: `decoy${k}`, file: `d${k}.ts`, line: 1, type: 'function', layer: 'unknown' });
      const term1 = 'payfast', term2 = 'pay'; // term2 é substring de term1
      const r1 = new Set(queryMod.rankSymbols(symbols, term1).map((s) => s.name));
      const r2 = new Set(queryMod.rankSymbols(symbols, term2).map((s) => s.name));
      return [...r1].every((x) => r2.has(x)) && r1.has('AlphaPayFastBeta') && !r1.has('onlypay');
    };
    const r = pbt.forAll([pbt.gen.int(0, 10)], prop, { seed: 42, runs: 20 });
    assert.ok(r.ok, `P3 falhou: ${JSON.stringify(r.counterexample)}`);
    ok('pbt-p3', `P3 (metamórfica substring⊆substring) — ${r.runs} casos, seed ${r.seed}`);
  });

  // === PBT P4-desempate — invariância sob permutação da ordem de entrada ===
  await tryCaseAsyncSafe('pbt-p4-desempate', async () => {
    const pbt = await import('file://' + path.join(LIB, 'pbt.mjs'));
    const queryMod = await import('file://' + QUERY_MOD_PATH);
    const prop = (size) => {
      const symbols = Array.from({ length: size }, (_, k) => ({ name: 'Dup', file: `f${k}.ts`, line: k, type: 'function', layer: 'unknown' }));
      const rnd = pbt.makeRandom(size + 1);
      const shuffled = pbt.shuffle(symbols, rnd);
      const baseline = JSON.stringify(queryMod.rankSymbols(symbols, 'Dup'));
      const got = JSON.stringify(queryMod.rankSymbols(shuffled, 'Dup'));
      return baseline === got;
    };
    const r = pbt.forAll([pbt.gen.int(2, 10)], prop, { seed: 999, runs: 25 });
    assert.ok(r.ok, `P4-desempate falhou: ${JSON.stringify(r.counterexample)}`);
    ok('pbt-p4-desempate', `P4-desempate (invariância sob permutação) — ${r.runs} casos, seed ${r.seed}`);
  });

  // === [7b] sufixo de defasagem por {mtime,size} sem rebuild ===
  await tryCaseAsync('7b', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q7b-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      const f = path.join(tmp, 'src', 'f.ts');
      fs.writeFileSync(f, 'export function foo() {\n  return 1;\n}\n');
      buildAt(tmp);
      const before = runQuery(tmp, ['foo']);
      assert.ok(!before.stdout.includes('defasada'), 'sem edição após o build, não deveria haver sufixo de defasagem');
      fs.writeFileSync(f, 'export function foo() {\n  return 99999;\n}\n');
      fs.utimesSync(f, new Date(Date.now() + 5000), new Date(Date.now() + 5000));
      const after = runQuery(tmp, ['foo']);
      assert.equal(after.code, 0, `query deveria sair exit 0; stderr=${after.stderr}`);
      assert.match(after.stdout, /foo \[function\] src\/f\.ts:1 \([a-z]+\) \(linha possivelmente defasada\)/,
        `esperado sufixo de defasagem; obteve:\n${after.stdout}`);
      ok('7b', 'sufixo de defasagem aparece quando {mtime,size} divergem do indexado, sem rebuild');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [10b] --json completo com stale ===
  await tryCaseAsync('10b', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q10b-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      const f = path.join(tmp, 'src', 'f.ts');
      fs.writeFileSync(f, 'export function foo() {\n  return 1;\n}\n');
      buildAt(tmp);
      fs.writeFileSync(f, 'export function foo() {\n  return 999999;\n}\n');
      fs.utimesSync(f, new Date(Date.now() + 5000), new Date(Date.now() + 5000));
      const r = runQuery(tmp, ['foo', '--json']);
      assert.equal(r.code, 0, `query --json deveria sair exit 0; stderr=${r.stderr}`);
      const data = JSON.parse(r.stdout);
      const sym = data.symbols.find((s) => s.name === 'foo');
      assert.ok(sym, 'símbolo foo deveria aparecer em --json');
      assert.equal(sym.stale, true, 'stale deveria ser true após edição sem rebuild');
      ok('10b', '--json completo com stale:true refletindo a defasagem real');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [11] query nunca escreve em disco ===
  await tryCaseAsync('11', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q11-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'f.ts'), 'export function foo() {\n  return 1;\n}\n');
      buildAt(tmp);
      const graphPath = path.join(tmp, '.forge/graph/graph.json');
      const symbolsPath = path.join(tmp, '.forge/graph/symbols.json');
      const mtimeGraphBefore = fs.statSync(graphPath).mtimeMs;
      const mtimeSymbolsBefore = fs.statSync(symbolsPath).mtimeMs;
      runQuery(tmp, ['foo']);
      runQuery(tmp, ['foo', '--json']);
      const mtimeGraphAfter = fs.statSync(graphPath).mtimeMs;
      const mtimeSymbolsAfter = fs.statSync(symbolsPath).mtimeMs;
      assert.equal(mtimeGraphAfter, mtimeGraphBefore, 'graph.json não deveria ser tocado por query');
      assert.equal(mtimeSymbolsAfter, mtimeSymbolsBefore, 'symbols.json não deveria ser tocado por query');
      ok('11', 'query nunca escreve em disco (mtime de graph.json/symbols.json intactos após query humana e --json)');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [22b] defasagem some após `graph.sh update` real ===
  await tryCaseAsync('22b', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q22b-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      const f = path.join(tmp, 'src', 'f.ts');
      fs.writeFileSync(f, 'export function foo() {\n  return 1;\n}\n');
      buildAt(tmp);
      fs.writeFileSync(f, 'export function foo() {\n  return 42;\n}\n');
      fs.utimesSync(f, new Date(Date.now() + 5000), new Date(Date.now() + 5000));
      const beforeUpdate = runQuery(tmp, ['foo']);
      assert.match(beforeUpdate.stdout, /defasada/, 'antes do update real, sufixo de defasagem deveria aparecer');
      updateAt(tmp);
      const afterUpdate = runQuery(tmp, ['foo']);
      assert.ok(!afterUpdate.stdout.includes('defasada'), `após update real, sufixo de defasagem deveria sumir; obteve:\n${afterUpdate.stdout}`);
      ok('22b', 'defasagem aparece antes do update real e some depois (visível via query, sem reler artefato nenhum manualmente)');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [6b] staleness de fingerprint-only (mecanismo distinto) não é confundida com {mtime,size} ===
  await tryCaseAsync('6b', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q6b-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'f.ts'), 'export function foo() {\n  return 1;\n}\n');
      buildAt(tmp);
      const graphPath = path.join(tmp, '.forge/graph/graph.json');
      const graph = JSON.parse(fs.readFileSync(graphPath, 'utf8'));
      const node = graph.nodes.find((x) => x.id === 'src/f.ts');
      assert.ok(node, 'node src/f.ts deveria existir em graph.json');
      node.fingerprint = 'f'.repeat(64); // diverge DELIBERADAMENTE — mecanismo distinto de {mtime,size}
      fs.writeFileSync(graphPath, JSON.stringify(graph, null, 2) + '\n');
      const r = runQuery(tmp, ['foo']);
      assert.equal(r.code, 0, `query deveria sair exit 0; stderr=${r.stderr}`);
      assert.ok(!r.stdout.includes('defasada'),
        `fingerprint estrutural tamperado (mecanismo distinto) não deveria marcar stale via {mtime,size}; obteve:\n${r.stdout}`);
      ok('6b', 'staleness de fingerprint-only (graph.json tamperado) não é confundida com defasagem de {mtime,size}');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [23] dica de 0-resultados (texto canônico idêntico em modo humano e --json) ===
  await tryCaseAsync('23', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q23-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'f.ts'), 'export function foo() {\n  return 1;\n}\n');
      buildAt(tmp);
      const term = 'zzz-nao-existe';
      const r = runQuery(tmp, [term]);
      assert.equal(r.code, 0, `query deveria sair exit 0 mesmo com 0 resultados; stderr=${r.stderr}`);
      const expectedHint = 'hint: nenhum node/edge/símbolo casou com "' + term + '". Se symbols.json não existe, rode `graph.sh build` para gerar símbolos; se já existe, tente um termo mais genérico (prefixo/substring) ou `graph.sh symbols` para conferir o índice.';
      assert.ok(r.stdout.includes(expectedHint), `texto canônico de 0-resultados ausente; obteve:\n${r.stdout}`);
      const rJson = runQuery(tmp, [term, '--json']);
      const data = JSON.parse(rJson.stdout);
      assert.equal(data.hint, expectedHint, 'campo hint do --json deveria ser o mesmo texto canônico do modo humano');
      ok('23', 'dica de 0-resultados com texto canônico idêntico em modo humano e --json, exit 0');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [24b] desempate completo refletido em --json ===
  await tryCaseAsync('24b', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q24b-'));
    try {
      fs.mkdirSync(path.join(tmp, 'd'), { recursive: true });
      fs.mkdirSync(path.join(tmp, 'e'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'd', 'dup1.ts'), 'export function Helper() {\n  return 1;\n}\n');
      fs.writeFileSync(path.join(tmp, 'e', 'dup2.ts'), 'export function Helper() {\n  return 1;\n}\n');
      buildAt(tmp);
      const r = runQuery(tmp, ['helper', '--json']);
      assert.equal(r.code, 0, `query --json deveria sair exit 0; stderr=${r.stderr}`);
      const data = JSON.parse(r.stdout);
      const files = data.symbols.map((s) => s.file);
      assert.deepEqual(files, ['d/dup1.ts', 'e/dup2.ts'], `desempate por file deveria ordenar d/ antes de e/; obteve ${JSON.stringify(files)}`);
      ok('24b', 'desempate (name,file,line) completo refletido em --json: d/dup1.ts antes de e/dup2.ts');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [14] ENOENT por símbolo individual (sufixo + missing:true, isolado) ===
  await tryCaseAsync('14', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q14-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'f.ts'), 'export function fooz() {\n  return 1;\n}\n');
      fs.writeFileSync(path.join(tmp, 'src', 'g.ts'), 'export function barz() {\n  return 1;\n}\n');
      buildAt(tmp);
      fs.rmSync(path.join(tmp, 'src', 'g.ts')); // remove o arquivo SEM atualizar symbols.json
      const r = runQuery(tmp, ['z']);
      assert.equal(r.code, 0, `query deveria sair exit 0; stderr=${r.stderr}`);
      assert.match(r.stdout, /^  fooz \[function\] src\/f\.ts:1 \([a-z]+\)$/m,
        `fooz não deveria ser afetado pelo ENOENT de outro símbolo; obteve:\n${r.stdout}`);
      assert.match(r.stdout, /barz \[function\] src\/g\.ts:1 \([a-z]+\) \(arquivo não encontrado — rode graph\.sh build\)/,
        `barz deveria ter sufixo de ENOENT; obteve:\n${r.stdout}`);
      const rJson = runQuery(tmp, ['z', '--json']);
      const data = JSON.parse(rJson.stdout);
      const barSym = data.symbols.find((s) => s.name === 'barz');
      const fooSym = data.symbols.find((s) => s.name === 'fooz');
      assert.equal(barSym.missing, true, 'missing:true deveria aparecer no JSON para o símbolo com ENOENT');
      assert.equal(barSym.stale, true, 'arquivo ausente também deve marcar stale:true');
      assert.ok(!fooSym.missing, 'fooz não deveria ter missing:true');
      ok('14', 'ENOENT por símbolo individual: sufixo + missing:true isolado, sem afetar os demais símbolos');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [15] symbols.json corrompido degrada para nodes/edges-only, sem crash ===
  await tryCaseAsync('15', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q15-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'f.ts'), 'export function foo() {\n  return 1;\n}\n');
      buildAt(tmp);
      fs.writeFileSync(path.join(tmp, '.forge/graph/symbols.json'), '{ not valid json');
      const r = runQuery(tmp, ['foo']);
      assert.equal(r.code, 0, `query deveria sair exit 0 mesmo com symbols.json corrompido; rc=${r.code} stderr=${r.stderr}`);
      assert.match(r.stdout, /^nodes \(\d+\):$/m, 'nodes/edges deveriam continuar funcionando (degrada só symbols)');
      assert.doesNotMatch(r.stdout, /^symbols \(/m, 'índice corrompido deve omitir a seção symbols');
      assert.match(r.stderr, /WARN symbols\.json inválido/, 'degradação deve avisar em stderr');
      ok('15', 'symbols.json corrompido (JSON inválido) degrada para nodes/edges-only, sem crash, exit 0');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [16] entrada legada sem mtime/size → "não verificável" ===
  await tryCaseAsync('16', async () => {
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q16-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'f.ts'), 'export function foo() {\n  return 1;\n}\n');
      buildAt(tmp);
      const symbolsPath = path.join(tmp, '.forge/graph/symbols.json');
      const parsed = JSON.parse(fs.readFileSync(symbolsPath, 'utf8'));
      for (const s of parsed.symbols) { delete s.mtime; delete s.size; }
      fs.writeFileSync(symbolsPath, JSON.stringify(parsed, null, 2) + '\n');
      const r = runQuery(tmp, ['foo']);
      assert.equal(r.code, 0, `query com symbols.json legado deveria sair exit 0; stderr=${r.stderr}`);
      assert.match(r.stdout, /foo \[function\] src\/f\.ts:1 \([a-z]+\) \(não verificável\)/,
        `esperado sufixo "não verificável"; obteve:\n${r.stdout}`);
      ok('16', 'entrada legada sem mtime/size produz sufixo "não verificável", sem crash');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [16b] vacuidade genuína (projeto só .go) não dispara aviso falso de formato legado ===
  tryCase('16b', () => {
    const { spawnSync, execFileSync } = require('node:child_process');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q16b-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'main.go'), 'package main\nfunc Foo() {}\n');
      execFileSync('bash', [GRAPH_SH, 'build'], { stdio: 'pipe', env: { ...process.env, FORGE_ROOT: tmp } });
      const symbolsPath = path.join(tmp, '.forge/graph/symbols.json');
      const parsed = JSON.parse(fs.readFileSync(symbolsPath, 'utf8'));
      assert.deepEqual(parsed.symbols, [], 'projeto só .go deveria produzir symbols:[] genuinamente vazio');
      const res = spawnSync('bash', [GRAPH_SH, 'query', 'main'], { env: { ...process.env, FORGE_ROOT: tmp } });
      assert.equal(res.status, 0, 'query deveria sair exit 0');
      assert.equal(res.stderr.toString(), '',
        `symbols:[] genuinamente vazio (.go) NÃO deveria disparar WARN em stderr; obteve: ${res.stderr.toString()}`);
      ok('16b', 'vacuidade genuína de symbols (projeto só .go) não dispara aviso falso de formato legado');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  });

  // === [17b] symbols.json órfão pós-"pull" simulado não crasha a query ===
  tryCase('17b', () => {
    const { spawnSync, execFileSync } = require('node:child_process');
    const tmp = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'w344-q17b-'));
    try {
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src', 'a.ts'), 'export function alfa() {\n  return 1;\n}\n');
      fs.writeFileSync(path.join(tmp, 'src', 'b.ts'), 'export function beta() {\n  return 1;\n}\n');
      execFileSync('bash', [GRAPH_SH, 'build'], { stdio: 'pipe', env: { ...process.env, FORGE_ROOT: tmp } });
      // simula um "git pull" que removeu src/b.ts sem ninguém rodar graph.sh update/build de novo
      fs.rmSync(path.join(tmp, 'src', 'b.ts'));
      const res = spawnSync('bash', [GRAPH_SH, 'query', 'a'], { env: { ...process.env, FORGE_ROOT: tmp } });
      assert.equal(res.status, 0, 'query não deveria crashar nem sair != 0 com symbols.json órfão pós-pull simulado');
      const out = res.stdout.toString();
      assert.doesNotMatch(out, /Error:|at Object\.|at Module\./, 'saída não deveria conter rastro de exceção não tratada');
      ok('17b', 'query não crasha com symbols.json referenciando arquivo removido pós-"pull" simulado (exit 0)');
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
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
