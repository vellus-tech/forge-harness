#!/usr/bin/env node
// tests/w345-graph-symbols-property-gate.driver.mjs — driver do gate `w345-graph-symbols-property-gate.sh`
// (TASK-14 de fix-graph-query-symbols-fusion, STORY-07): consolida as seis propriedades (P1-P6) já
// provadas Red→Verde ao longo das stories anteriores (P2/P4-herança/P5 na TASK-03/w344, P6 na
// TASK-05/w344 [5a]/[6c], P1/P3/P4-desempate na TASK-09/w344) num gate formal dedicado, com seed
// fixa reprodutível e o "teste do teste" (padrão w121 [2] / w344 [6a]: mutação deliberada precisa
// reprovar com contraexemplo minimizado).
//
// DD-08 (design.md §5 item 2): esta task NÃO tem par vermelho/verde de comportamento próprio.
// graph-query.mjs e graph-symbols-extract.mjs já implementam P1-P6 desde TASK-03/TASK-05/TASK-09
// — um import() que resolvesse e passasse de cara não seria Red válido (o comportamento já existe
// e já foi provado Red→Verde na task correspondente). Mesmo padrão de TASK-02/TASK-13.
//
//   P1  completude       — rankSymbols não omite nem inventa matches (substring presente -> achado)
//   P2  sem duplicata    — extractSymbols nunca repete a chave (file,name,type,line)
//   P3  metamórfica      — t' substring de t  =>  results(t) ⊆ results(t'), sem corte de 20
//   P4a invariância (herança)   — resolveInheritance é independente da ORDEM de entrada
//   P4b invariância (desempate) — rankSymbols é independente da ORDEM de entrada (empates estáveis)
//   P5  invariância cosmética   — comentário/linha em branco só muda `line`, nunca (file,name,type)
//   P6  equivalência      — symbols.idx.tsv é projeção EXATA de symbols.json
//   tt-p2 teste do teste  — mutante força duplicata deliberada; P2 reprova com contraexemplo
//   tt-p4 teste do teste  — mutante ignora a ordem de entrada deliberadamente; P4a reprova
//
// Seed: FORGE_PBT_SEED (env), se definida e numérica, substitui a seed-base fixa abaixo — mantém
// reprodutibilidade (rule testing/property-based-testing.md) permitindo variar a base manualmente
// quando necessário. Sem a env var, a seed-base é literal e fixa — nunca Math.random.
//
// "TESTE DO TESTE" — mutação em memória, nunca toca arquivo de produção em disco (evita o risco de
// "mutação fantasma" catalogado no projeto: restore() quebrado deixando mutação residual entre
// casos). Controle = propriedade real já verde nos blocos P2/P4a; mutante = wrapper que QUEBRA
// deliberadamente a propriedade correspondente; recontrole = reconfirmação de que a propriedade
// real continua verde depois do mutante rodar.
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const WS = dirname(dirname(fileURLToPath(import.meta.url)));
const LIB = join(WS, 'template', '.forge', 'scripts', 'lib');
const SEED_BASE = Number(process.env.FORGE_PBT_SEED) || 20261104;

let n = 0;
let failures = 0;

function ok(label, msg) {
  n += 1;
  console.log(`OK [${label}] ${msg}`);
}
function bad(label, msg) {
  n += 1;
  failures += 1;
  console.log(`FAIL [${label}] ${msg}`);
}
async function tryCase(label, fn) {
  try {
    await fn();
  } catch (err) {
    bad(label, err && err.message ? err.message : String(err));
  }
}
function assertOk(cond, msg) {
  if (!cond) throw new Error(msg);
}

// === P2 — sem duplicata: (file,name,type,line) nunca repete ===
function p2Prop(extractFn) {
  return (count) => {
    let src = '';
    for (let k = 0; k < count; k++) src += `class Foo${k} {}\n`;
    src += 'class Dup {} class Dup {}\n';
    const { symbols } = extractFn('synthetic.cs', 'csharp', src);
    const keys = symbols.map((s) => `${s.name}|${s.type}|${s.line}`);
    return new Set(keys).size === keys.length;
  };
}

// === P4a — invariância sob permutação (herança): resolveInheritance independe da ordem ===
function p4aProp(resolveFn, pbt) {
  return (size) => {
    const files = Array.from({ length: size }, (_, k) => ({
      file: `pf${k}.ts`,
      symbols: [{ name: `PSym${k}`, type: 'class', line: 1 }],
      inherit: k > 0 ? [{ name: `PSym${k}`, base: `PSym${k - 1}`, line: 1 }] : [],
    }));
    const rnd = pbt.makeRandom(size + 1);
    const shuffled = pbt.shuffle(files, rnd);
    return JSON.stringify(resolveFn(files)) === JSON.stringify(resolveFn(shuffled));
  };
}

// === P6 — equivalência: symbols.idx.tsv é projeção EXATA de symbols.json ===
function p6Prop(assembleFn) {
  return (count) => {
    const symbolsByFile = Array.from({ length: count }, (_, k) => ({
      file: `p6f${k}.ts`,
      symbols: [{ name: `P6Sym${k}`, type: k % 2 === 0 ? 'class' : 'function', line: k + 1 }],
      inherit: [],
    }));
    const { symbolsJson, idxTsv } = assembleFn(symbolsByFile);
    const idxLines = idxTsv.split('\n').filter(Boolean);
    if (idxLines.length !== symbolsJson.symbols.length) return false;
    for (let i = 0; i < symbolsJson.symbols.length; i++) {
      const s = symbolsJson.symbols[i];
      const expectedLine = `${s.name}\t${s.file}\t${s.line}\t${s.type}\t${s.layer}`;
      if (idxLines[i] !== expectedLine) return false;
    }
    return true;
  };
}

async function main() {
  const extractMod = await import(join(LIB, 'graph-symbols-extract.mjs'));
  const { extractSymbols, resolveInheritance, assembleSymbolsArtifacts } = extractMod;
  const queryMod = await import(join(LIB, 'graph-query.mjs'));
  const { rankSymbols } = queryMod;
  const pbt = await import(join(LIB, 'pbt.mjs'));

  for (const [label, fn] of Object.entries({ extractSymbols, resolveInheritance, assembleSymbolsArtifacts, rankSymbols })) {
    if (typeof fn !== 'function') bad('setup', `export ausente ou não-função: ${label}`);
  }
  if (failures > 0) {
    console.log(`\n${failures} de ${n} checagem(ns) reprovada(s) no setup.`);
    process.exit(1);
  }

  // === P1 — completude: rankSymbols não omite nem inventa matches ===
  await tryCase('P1', async () => {
    const prop = (count) => {
      const symbols = Array.from({ length: count }, (_, k) => ({ name: `sym${k}abc`, file: `f${k}.ts`, line: 1, type: 'function', layer: 'unknown' }));
      const term = 'abc';
      const ranked = rankSymbols(symbols, term);
      const expected = new Set(symbols.filter((s) => s.name.toLowerCase().includes(term)).map((s) => s.name));
      const got = new Set(ranked.map((s) => s.name));
      return expected.size === got.size && [...expected].every((x) => got.has(x));
    };
    const r = pbt.forAll([pbt.gen.int(1, 15)], prop, { seed: SEED_BASE + 1, runs: 40 });
    assertOk(r.ok, `P1 falhou: ${JSON.stringify(r.counterexample)}`);
    ok('P1', `completude (rankSymbols não omite nem inventa matches) — ${r.runs} casos, seed ${r.seed}`);
  });

  // === P2 — sem duplicata ===
  await tryCase('P2', async () => {
    const r = pbt.forAll([pbt.gen.int(1, 8)], p2Prop(extractSymbols), { seed: SEED_BASE + 2, runs: 40 });
    assertOk(r.ok, `P2 falhou: ${JSON.stringify(r.counterexample)}`);
    ok('P2', `sem duplicata (file,name,type,line) — ${r.runs} casos, seed ${r.seed}`);
  });

  // === P3 — metamórfica: t' substring de t => results(t) subconjunto de results(t'), sem corte de 20 ===
  await tryCase('P3', async () => {
    const prop = (count) => {
      const symbols = [
        { name: 'AlphaPayFastBeta', file: 'f0.ts', line: 1, type: 'function', layer: 'unknown' },
        { name: 'onlypay', file: 'f1.ts', line: 1, type: 'function', layer: 'unknown' },
      ];
      // count pode superar 20 decoys deliberadamente — a propriedade não tem corte de 20 (DD-09)
      for (let k = 0; k < count; k++) symbols.push({ name: `decoy${k}`, file: `d${k}.ts`, line: 1, type: 'function', layer: 'unknown' });
      for (let k = 0; k < 25; k++) symbols.push({ name: `PayFastExtra${k}`, file: `m${k}.ts`, line: 1, type: 'function', layer: 'unknown' });
      const term1 = 'payfast';
      const term2 = 'pay'; // term2 é substring de term1
      const r1 = new Set(rankSymbols(symbols, term1).map((s) => s.name));
      const r2 = new Set(rankSymbols(symbols, term2).map((s) => s.name));
      return r1.size === 26 && r2.size === 27 && [...r1].every((x) => r2.has(x)) && r1.has('AlphaPayFastBeta') && !r1.has('onlypay');
    };
    const r = pbt.forAll([pbt.gen.int(0, 30)], prop, { seed: SEED_BASE + 3, runs: 30 });
    assertOk(r.ok, `P3 falhou: ${JSON.stringify(r.counterexample)}`);
    ok('P3', `metamórfica substring subconjunto de substring, sem corte de 20 — ${r.runs} casos, seed ${r.seed}`);
  });

  // === P4a — invariância sob permutação (herança) ===
  await tryCase('P4a', async () => {
    const r = pbt.forAll([pbt.gen.int(2, 10)], p4aProp(resolveInheritance, pbt), { seed: SEED_BASE + 4, runs: 30 });
    assertOk(r.ok, `P4a (herança) falhou: ${JSON.stringify(r.counterexample)}`);
    ok('P4a', `invariância sob permutação — herança (resolveInheritance) — ${r.runs} casos, seed ${r.seed}`);
  });

  // === P4b — invariância sob permutação (desempate) ===
  await tryCase('P4b', async () => {
    const prop = (size) => {
      const symbols = Array.from({ length: size }, (_, k) => ({ name: 'Dup', file: `f${k}.ts`, line: k, type: 'function', layer: 'unknown' }));
      const rnd = pbt.makeRandom(size + 1);
      const shuffled = pbt.shuffle(symbols, rnd);
      const baseline = JSON.stringify(rankSymbols(symbols, 'Dup'));
      const got = JSON.stringify(rankSymbols(shuffled, 'Dup'));
      return baseline === got;
    };
    const r = pbt.forAll([pbt.gen.int(2, 10)], prop, { seed: SEED_BASE + 5, runs: 30 });
    assertOk(r.ok, `P4b (desempate) falhou: ${JSON.stringify(r.counterexample)}`);
    ok('P4b', `invariância sob permutação — desempate (rankSymbols) — ${r.runs} casos, seed ${r.seed}`);
  });

  // === P5 — invariância cosmética: comentário/linha em branco só muda `line` ===
  await tryCase('P5', async () => {
    const prop = (nInserted) => {
      const before = 'class Foo {}\n';
      const noise = Array.from({ length: nInserted }, (_, k) => `// noise ${k}\n`).join('');
      const after = noise + before;
      const r1 = extractSymbols('f.cs', 'csharp', before);
      const r2 = extractSymbols('f.cs', 'csharp', after);
      if (r1.symbols.length !== 1 || r2.symbols.length !== 1) return false;
      const a = r1.symbols[0];
      const b = r2.symbols[0];
      return a.name === b.name && a.type === b.type && b.line === a.line + nInserted;
    };
    const r = pbt.forAll([pbt.gen.int(0, 20)], prop, { seed: SEED_BASE + 6, runs: 30 });
    assertOk(r.ok, `P5 falhou: ${JSON.stringify(r.counterexample)}`);
    ok('P5', `invariância cosmética (comentário/linha em branco só muda line) — ${r.runs} casos, seed ${r.seed}`);
  });

  // === P6 — equivalência: idx.tsv é projeção exata de symbols.json ===
  await tryCase('P6', async () => {
    const r = pbt.forAll([pbt.gen.int(0, 15)], p6Prop(assembleSymbolsArtifacts), { seed: SEED_BASE + 7, runs: 30 });
    assertOk(r.ok, `P6 falhou: ${JSON.stringify(r.counterexample)}`);
    ok('P6', `symbols.idx.tsv é projeção exata de symbols.json — ${r.runs} casos, seed ${r.seed}`);
  });

  // === tt-p2 — teste do teste: mutante força duplicata deliberada; P2 precisa reprovar ===
  await tryCase('tt-p2', async () => {
    // controle: a propriedade real já passou no bloco P2 acima (sem duplicata).
    const mutantExtract = (file, lang, src) => {
      const r = extractSymbols(file, lang, src);
      // mutante: se houver ao menos 1 símbolo, duplica o primeiro deliberadamente — quebra P2
      // (sem duplicata) por construção.
      if (r.symbols.length > 0) return { ...r, symbols: [...r.symbols, { ...r.symbols[0] }] };
      return r;
    };
    const rMutant = pbt.forAll([pbt.gen.int(1, 8)], p2Prop(mutantExtract), { seed: SEED_BASE + 2, runs: 40 });
    assertOk(rMutant.ok === false, 'mutante com duplicata forçada deveria REPROVAR P2, mas passou');
    assertOk(!!rMutant.counterexample, 'mutante deveria produzir contraexemplo minimizado');

    // recontrole: a propriedade real (não-mutante) continua verde depois do mutante rodar — prova
    // que o mutante não deixou resíduo e que o motor de PBT em si não está quebrado.
    const rRecontrole = pbt.forAll([pbt.gen.int(1, 8)], p2Prop(extractSymbols), { seed: SEED_BASE + 2, runs: 40 });
    assertOk(rRecontrole.ok, `recontrole da propriedade real deveria continuar verde: ${JSON.stringify(rRecontrole.counterexample)}`);
    ok('tt-p2', `mutação (duplicata forçada) reprova P2 com contraexemplo minimizado: ${JSON.stringify(rMutant.counterexample)}; recontrole da propriedade real segue verde`);
  });

  // === tt-p4 — teste do teste: mutante ignora a ordem de entrada deliberadamente; P4a precisa reprovar ===
  await tryCase('tt-p4', async () => {
    // controle: a propriedade real já passou no bloco P4a acima (invariância sob permutação).
    const mutantResolveInheritance = (filesEntries) => {
      // mutante: devolve a ORDEM FÍSICA do array de entrada como parte do resultado — quebra
      // deliberadamente a invariância sob permutação (o resultado passa a depender da ordem).
      return filesEntries.map((f, i) => ({ from: `${f.file}#${(f.symbols[0] || {}).name}`, physicalIndex: i }));
    };
    const rMutant = pbt.forAll([pbt.gen.int(2, 10)], p4aProp(mutantResolveInheritance, pbt), { seed: SEED_BASE + 4, runs: 30 });
    assertOk(rMutant.ok === false, 'mutante sensível à ordem física deveria REPROVAR P4a, mas passou');
    assertOk(!!rMutant.counterexample, 'mutante deveria produzir contraexemplo minimizado');

    // recontrole: a propriedade real (não-mutante) continua verde depois do mutante rodar.
    const rRecontrole = pbt.forAll([pbt.gen.int(2, 10)], p4aProp(resolveInheritance, pbt), { seed: SEED_BASE + 4, runs: 30 });
    assertOk(rRecontrole.ok, `recontrole da propriedade real deveria continuar verde: ${JSON.stringify(rRecontrole.counterexample)}`);
    ok('tt-p4', `mutação (sensibilidade à ordem física) reprova P4a com contraexemplo minimizado: ${JSON.stringify(rMutant.counterexample)}; recontrole da propriedade real segue verde`);
  });

  if (failures > 0) {
    console.log(`\n${failures} de ${n} checagem(ns) reprovada(s).`);
    process.exit(1);
  }
  console.log(`\nPASS w345-graph-symbols-property-gate.driver — ${n} checagens (P1-P6 + teste do teste).`);
}

main().catch((err) => {
  console.log(`FAIL [${n + 1}] driver: exceção não tratada: ${err && err.stack ? err.stack : err}`);
  process.exit(1);
});
