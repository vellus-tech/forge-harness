#!/usr/bin/env node
// tools/spike-complexity-duplication.mjs — roteiro executável do spike REQ-05 (change
// adopt-ub-mode-practices, design.md §2.3). Mede complexidade ciclomática por função (parser AST)
// e duplicação estrutural (jscpd), sobre um universo definido por `git ls-files` (nunca varredura
// de disco — exclui .forge/, node_modules/, .next/ e qualquer artefato de build não versionado
// automaticamente). Execução SOMENTE DE LEITURA: nenhuma dependência é instalada no alvo medido.
//
// Complexidade: @babel/parser já é devDependency deste repositório (tools/ roda a partir do
// node_modules da raiz); sobre um consumidor externo sem essa devDependency, resolve a mesma
// versão via `npx -p @babel/parser@<versão fixada>` — NODE_PATH injetado pelo npx é consultado
// pelo algoritmo CJS de `createRequire`, então o require funciona sem instalar nada
// permanentemente no alvo.
// Duplicação: `npx jscpd@<versão fixada>`, nunca instalado como dependência do harness nem do
// consumidor (ver design §2.3, risco documentado da issue #10 do `crapper` upstream).
//
// Cobertura (design §2.3, ordem de preferência): (a) reporter `lcov` nativo de
// `node --test --experimental-test-coverage` (Node 20+), se já existir alguma fonte de cobertura
// detectável no alvo; (b) na ausência comprovada, reporta COMPLEXIDADE PURA (CC, sem elevar ao
// quadrado nem somar), explicitamente rotulada "sem dado de cobertura" — nunca a fórmula CRAP
// completa assumindo cobertura zero, que infla o achado.
//
// Usage:
//   node tools/spike-complexity-duplication.mjs <target-dir>
//       [--complexity-threshold <N>] [--duplication-threshold <0..1>] [--json]
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdtempSync, rmSync, existsSync } from 'node:fs';
import { join, resolve, extname, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const PINNED_BABEL_VERSION = '7.29.9'; // mesma versão do devDependency em package.json
const PINNED_JSCPD_VERSION = '4.0.5';
const THIS_FILE = fileURLToPath(import.meta.url);

function fail(msg, code = 1) { console.error(`FAIL (${msg})`); process.exit(code); }

function parseArgs(argv) {
  if (argv.length === 0) fail('uso: spike-complexity-duplication.mjs <target-dir> [--complexity-threshold N] [--duplication-threshold P] [--json]', 2);
  const out = { target: resolve(argv[0]), complexityThreshold: 10, duplicationThreshold: 0.8, json: false };
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--complexity-threshold') out.complexityThreshold = Number(argv[++i]);
    else if (a === '--duplication-threshold') out.duplicationThreshold = Number(argv[++i]);
    else if (a === '--json') out.json = true;
    else fail(`flag desconhecida: ${a}`, 2);
  }
  if (!Number.isFinite(out.complexityThreshold) || out.complexityThreshold <= 0) fail('--complexity-threshold precisa ser número > 0', 2);
  if (!Number.isFinite(out.duplicationThreshold) || out.duplicationThreshold <= 0 || out.duplicationThreshold > 1) fail('--duplication-threshold precisa ser número em (0,1]', 2);
  return out;
}

function gitLsFiles(dir) {
  if (!existsSync(join(dir, '.git')) && !isInsideGitRepo(dir)) fail(`'${dir}' não é um repositório git — universo é git ls-files, nunca varredura de disco`, 2);
  let out;
  try { out = execFileSync('git', ['-C', dir, 'ls-files'], { encoding: 'utf8' }); }
  catch (e) { fail(`git ls-files falhou em '${dir}': ${e.message}`); }
  return out.split(/\r?\n/).filter(Boolean);
}
function isInsideGitRepo(dir) {
  try { execFileSync('git', ['-C', dir, 'rev-parse', '--is-inside-work-tree'], { stdio: 'ignore' }); return true; }
  catch { return false; }
}

// ---- bootstrap do @babel/parser: local (este repo) ou instalado num prefixo TEMPORÁRIO
// (consumidor externo sem a devDependency) — nunca `npx -p ... node -e`: comprovado que `npx -p`
// NÃO injeta NODE_PATH no processo `node` filho (require() do -e segue "Cannot find module"),
// então o pacote fica indisponível independente da versão fixada. A alternativa real:
// `npm install --prefix <tmp>` materializa o pacote num diretório descartável, nunca no alvo
// medido nem no harness, e `createRequire` resolve a partir desse diretório (algoritmo CJS sobe
// procurando node_modules a partir do arquivo-base informado).
function loadBabelParserSync() {
  const req = createRequire(import.meta.url);
  try { return req('@babel/parser'); } catch { /* segue para o fallback via prefixo temporário */ }
  const tmp = mkdtempSync(join(tmpdir(), 'forge-spike-babel-'));
  try {
    execFileSync('npm', ['install', '--no-save', '--no-audit', '--no-fund', '--prefix', tmp, `@babel/parser@${PINNED_BABEL_VERSION}`], { stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (e) {
    fail(`não foi possível instalar @babel/parser temporariamente em ${tmp}: ${e.message}`);
  }
  const reqTmp = createRequire(join(tmp, 'noop.cjs'));
  try { return reqTmp('@babel/parser'); }
  catch (e) { fail(`@babel/parser instalado em ${tmp} mas não resolveu via require: ${e.message}`); }
}

// ---- complexidade ciclomática por função: CC = 1 + nº de pontos de decisão ----
const DECISION_TYPES = new Set([
  'IfStatement', 'ConditionalExpression', 'ForStatement', 'ForInStatement', 'ForOfStatement',
  'WhileStatement', 'DoWhileStatement', 'SwitchCase', 'CatchClause', 'LogicalExpression',
]);
const FUNCTION_TYPES = new Set(['FunctionDeclaration', 'FunctionExpression', 'ArrowFunctionExpression', 'ClassMethod', 'ObjectMethod']);

function walk(node, visitor) {
  if (!node || typeof node.type !== 'string') return;
  visitor(node);
  for (const key of Object.keys(node)) {
    if (key === 'loc' || key === 'start' || key === 'end' || key === 'range' || key === 'leadingComments' || key === 'trailingComments') continue;
    const v = node[key];
    if (Array.isArray(v)) { for (const item of v) if (item && typeof item === 'object') walk(item, visitor); }
    else if (v && typeof v === 'object' && typeof v.type === 'string') walk(v, visitor);
  }
}

function functionsWithComplexity(ast) {
  const program = ast.program || ast; // tolera AST serializado via JSON (npx) ou direto
  const results = [];
  walk(program, (node) => {
    if (!FUNCTION_TYPES.has(node.type)) return;
    let cc = 1;
    const nameNode = node.id || (node.key && node.key.name ? node.key : null);
    const name = (nameNode && (nameNode.name || nameNode.value)) || '<anônima>';
    const line = node.loc ? node.loc.start.line : 0;
    walk(node.body || node, (inner) => {
      if (inner === node) return;
      if (DECISION_TYPES.has(inner.type)) cc++;
    });
    results.push({ name, line, complexity: cc });
  });
  return results;
}

function hasCoverageSource(targetDir) {
  // (a) node --test --experimental-test-coverage (Node 20+) com reporter lcov — só É considerado
  // presente se o alvo já tiver um relatório lcov gerado; este spike não gera cobertura nova
  // (execução só-leitura, nunca instala nada, nunca roda a suíte de teste do consumidor).
  return existsSync(join(targetDir, 'coverage', 'lcov.info')) || existsSync(join(targetDir, 'lcov.info'));
}

// ---- duplicação: jscpd via npx, nunca instalado como dependência ----
function runJscpd(targetDir, files) {
  const tmp = mkdtempSync(join(tmpdir(), 'forge-spike-jscpd-'));
  try {
    const listFile = join(tmp, 'files.txt');
    writeFileSync(listFile, files.join('\n'));
    const reportDir = join(tmp, 'report');
    execFileSync('npx', [
      '--yes', `jscpd@${PINNED_JSCPD_VERSION}`,
      '--reporters', 'json', '--output', reportDir, '--silent',
      '--min-lines', '5', '--min-tokens', '50',
      '--absolute',
      ...files,
    ], { cwd: targetDir, encoding: 'utf8', maxBuffer: 1024 * 1024 * 64 });
    const reportPath = join(reportDir, 'jscpd-report.json');
    if (!existsSync(reportPath)) return { percentage: 0, clones: [] };
    const report = JSON.parse(readFileSync(reportPath, 'utf8'));
    return {
      percentage: (report.statistics && report.statistics.total && report.statistics.total.percentage) || 0,
      clones: report.duplicates || [],
    };
  } catch (e) {
    // jscpd sai com rc != 0 quando ultrapassa --threshold (não usado aqui) OU por erro real;
    // tenta ler o relatório mesmo assim antes de desistir.
    const reportPath = join(tmp, 'report', 'jscpd-report.json');
    if (existsSync(reportPath)) {
      const report = JSON.parse(readFileSync(reportPath, 'utf8'));
      return { percentage: (report.statistics && report.statistics.total && report.statistics.total.percentage) || 0, clones: report.duplicates || [] };
    }
    fail(`jscpd falhou: ${e.message}`);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

async function main() {
  const { target, complexityThreshold, duplicationThreshold, json } = parseArgs(process.argv.slice(2));
  const JS_EXT = new Set(['.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx']);
  const universe = gitLsFiles(target).filter((f) => JS_EXT.has(extname(f)));
  if (universe.length === 0) {
    console.log(`OK — 0 arquivo(s) JS/TS no universo (git ls-files de '${target}'); nada a medir`);
    process.exit(0);
  }

  const babelParser = loadBabelParserSync();
  const coverageLabel = hasCoverageSource(target) ? 'com dado de cobertura' : 'sem dado de cobertura';

  const complexityFindings = [];
  for (const rel of universe) {
    const abs = join(target, rel);
    let ast;
    try {
      const code = readFileSync(abs, 'utf8');
      ast = babelParser.parse(code, { sourceType: 'unambiguous', plugins: ['jsx', 'typescript'], errorRecovery: true });
    } catch (e) {
      console.error(`AVISO: '${rel}' não parseou (${e.message}) — excluído da medição`);
      continue;
    }
    for (const fn of functionsWithComplexity(ast)) {
      complexityFindings.push({ file: rel, ...fn, aboveThreshold: fn.complexity > complexityThreshold });
    }
  }

  const dup = runJscpd(target, universe.map((f) => join(target, f)));
  const dupAboveThreshold = (dup.percentage / 100) >= duplicationThreshold;

  const result = {
    target,
    universe: universe.length,
    coverage: coverageLabel,
    complexity: { threshold: complexityThreshold, findings: complexityFindings, aboveThresholdCount: complexityFindings.filter((f) => f.aboveThreshold).length },
    duplication: { threshold: duplicationThreshold, percentage: dup.percentage, aboveThreshold: dupAboveThreshold, clones: dup.clones.length },
  };

  if (json) { console.log(JSON.stringify(result, null, 2)); return; }

  console.log(`OK — universo: ${result.universe} arquivo(s) JS/TS (git ls-files), ${coverageLabel}`);
  console.log(`complexidade (limiar ${complexityThreshold}): ${result.complexity.aboveThresholdCount} de ${complexityFindings.length} função(ões) acima do limiar`);
  for (const f of complexityFindings.filter((x) => x.aboveThreshold)) {
    console.log(`  ACIMA — ${f.file}:${f.line} ${f.name}() CC=${f.complexity}`);
  }
  console.log(`duplicação (limiar ${(duplicationThreshold * 100).toFixed(0)}%): ${dup.percentage}% duplicado, ${result.duplication.clones} clone(s) — ${dupAboveThreshold ? 'ACIMA' : 'abaixo'} do limiar`);
}

main().catch((e) => fail(e.stack || e.message));
