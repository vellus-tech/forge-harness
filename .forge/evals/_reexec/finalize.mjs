#!/usr/bin/env node
// finalize.mjs — fecha uma iteração de reexecução de UM artefato, só com script.
//
// Uso: node finalize.mjs <skills|agents> <nome> --iteration 2 [--iteration-ref 1] [--no-collect]
// Ambiente: REEXEC_SCRATCH (o mesmo do prep), AGGREGATE_PY (default: aggregate_benchmark.py do skill-creator).
//
// Passos, nesta ordem, e qualquer falha aborta com rc≠0 antes de gravar veredito:
//  1. coleta: copia de REEXEC_SCRATCH/runs/<id>/ para workspace/iteration-N/eval-<caso>/<config>/run-<k>/
//     o grading.json, o timing.json, os prompts e outputs/ (texto, ≤ 1 MB por arquivo), trocando
//     caminhos de máquina por marcador (<RUN>, <SCRATCH>, <HOME>);
//  2. validação dos grading.json contra o snapshot evals.json da iteração: uma expectativa por asserção,
//     na ordem e com o texto literal; passed booleano; summary.pass_rate NÚMERO igual a passed/total;
//     summary.passed igual à contagem de passed:true; sem campo timing (o tempo vem do timing.json);
//     mesmo número de execuções por configuração em todos os casos; timing.json com tokens > 0;
//  3. agregação pelo aggregate_benchmark.py (estatística só dele) e correção de METADADOS do
//     benchmark.json (runs_per_configuration observado, modelos, sha dos arquivos medidos, maquinaria);
//  4. veredito por regra fixa, registrada antes da coleta (ver classify): IC 95% por bootstrap
//     estratificado por caso e configuração sobre as taxas por execução do benchmark.json, semente fixa.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '../../..');
const [kind, name, ...rest] = process.argv.slice(2);
const opt = { iteration: '2', 'iteration-ref': '1', collect: true };
for (let i = 0; i < rest.length; i++) {
  if (rest[i] === '--no-collect') opt.collect = false; else opt[rest[i].replace(/^--/, '')] = rest[++i];
}
const SCRATCH = process.env.REEXEC_SCRATCH;
const AGG = process.env.AGGREGATE_PY || join(process.env.HOME, '.claude/plugins/marketplaces/claude-plugins-official/plugins/skill-creator/skills/skill-creator/scripts/aggregate_benchmark.py');
const EVALDIR = join(REPO, '.forge/evals', kind, name);
const ITER = join(EVALDIR, 'workspace', `iteration-${opt.iteration}`);
const errors = [];
const fail = (m) => errors.push(m);
const evals = JSON.parse(readFileSync(join(ITER, 'evals.json'), 'utf8')).evals;
const byId = new Map(evals.map((e) => [e.id, e]));

// 1. coleta -------------------------------------------------------------------------------------
const rows = existsSync(join(SCRATCH || '', 'map.tsv'))
  ? readFileSync(join(SCRATCH, 'map.tsv'), 'utf8').trim().split('\n').map((l) => l.split('\t'))
    .filter((r) => r[1] === kind && r[2] === name)
  : [];
function sanitize(text, runDir) {
  let t = text;
  for (const p of [runDir, runDir.replace(/^\/private/, '')]) t = t.split(p).join('<RUN>');
  for (const p of [SCRATCH, SCRATCH.replace(/^\/private/, '')]) t = t.split(p).join('<SCRATCH>');
  return t.split(process.env.HOME).join('<HOME>');
}
function copyText(src, dst, runDir) {
  const buf = readFileSync(src);
  if (buf.length > 1024 * 1024 || buf.includes(0)) return false;
  mkdirSync(dirname(dst), { recursive: true });
  writeFileSync(dst, sanitize(buf.toString('utf8'), runDir));
  return true;
}
function walk(dir, acc = []) {
  for (const n of readdirSync(dir)) {
    const p = join(dir, n); const s = statSync(p, { throwIfNoEntry: false });
    if (!s) continue; if (s.isDirectory()) { if (n !== '.git' && n !== 'node_modules') walk(p, acc); } else if (s.isFile()) acc.push(p);
  }
  return acc;
}
if (opt.collect) {
  if (!rows.length) fail(`nenhuma execução em ${SCRATCH}/map.tsv para ${kind}/${name}`);
  for (const [id, , , evalId, evalName, config, run] of rows) {
    const runDir = join(SCRATCH, 'runs', id);
    const dst = join(ITER, `eval-${evalName}`, config, `run-${run}`);
    if (existsSync(dst)) rmSync(dst, { recursive: true });
    mkdirSync(dst, { recursive: true });
    for (const f of ['grading.json', 'timing.json']) {
      if (!existsSync(join(runDir, f))) { fail(`${evalName}/${config}/run-${run}: ${f} ausente (id ${id})`); continue; }
      copyText(join(runDir, f), join(dst, f), runDir);
    }
    copyText(join(runDir, 'prompt.md'), join(dst, 'executor_prompt.md'), runDir);
    copyText(join(runDir, 'grader_prompt.md'), join(dst, 'grader_prompt.md'), runDir);
    const out = join(runDir, 'outputs');
    const skipped = [];
    for (const f of walk(out)) if (!copyText(f, join(dst, 'outputs', relative(out, f)), runDir)) skipped.push(relative(out, f));
    if (!existsSync(join(out, 'transcript.md'))) fail(`${evalName}/${config}/run-${run}: outputs/transcript.md ausente (id ${id})`);
    if (skipped.length) writeFileSync(join(dst, 'outputs', '_omitidos.txt'), skipped.join('\n') + '\n');
  }
}

// 2. validação ----------------------------------------------------------------------------------
// O grader às vezes devolve o texto sem a crase de código ou com espaço diferente; a identidade da
// asserção é a posição, e o texto só confere que é a mesma asserção, então a comparação ignora isso.
const norm = (t) => String(t || '').replace(/`/g, '').replace(/\s+/g, ' ').trim();
const counts = {};
for (const ev of evals) {
  const caseDir = join(ITER, `eval-${ev.eval_name}`);
  const texts = ev.assertions.map((a) => (typeof a === 'string' ? a : a.text));
  for (const config of ['with_skill', 'without_skill']) {
    const cdir = join(caseDir, config);
    const runs = existsSync(cdir) ? readdirSync(cdir).filter((n) => /^run-\d+$/.test(n)) : [];
    counts[`${ev.id}/${config}`] = runs.length;
    for (const r of runs) {
      const where = `${ev.eval_name}/${config}/${r}`;
      const gp = join(cdir, r, 'grading.json');
      if (!existsSync(gp)) { fail(`${where}: sem grading.json`); continue; }
      let g; try { g = JSON.parse(readFileSync(gp, 'utf8')); } catch (e) { fail(`${where}: grading.json inválido (${e.message})`); continue; }
      const ex = g.expectations || [];
      if (ex.length !== texts.length) fail(`${where}: ${ex.length} expectativas, esperado ${texts.length}`);
      ex.forEach((x, i) => {
        if (typeof x.passed !== 'boolean') fail(`${where}: expectativa ${i + 1} com passed não booleano`);
        if (texts[i] !== undefined && norm(x.text) !== norm(texts[i])) fail(`${where}: expectativa ${i + 1} com texto diferente da asserção`);
      });
      const s = g.summary || {};
      const trues = ex.filter((x) => x.passed === true).length;
      if (typeof s.pass_rate !== 'number') fail(`${where}: summary.pass_rate não é número (${JSON.stringify(s.pass_rate)})`);
      else if (Math.abs(s.pass_rate - trues / texts.length) > 0.005) fail(`${where}: pass_rate ${s.pass_rate} ≠ ${trues}/${texts.length}`);
      if (s.passed !== trues || s.total !== texts.length) fail(`${where}: summary passed/total (${s.passed}/${s.total}) ≠ ${trues}/${texts.length}`);
      if ('timing' in g) fail(`${where}: grading.json com campo timing (o tempo vem do timing.json)`);
      const tp = join(cdir, r, 'timing.json');
      if (existsSync(tp)) {
        const t = JSON.parse(readFileSync(tp, 'utf8'));
        if (!(t.total_tokens > 0) || !(t.total_duration_seconds > 0)) fail(`${where}: timing.json sem tokens ou tempo`);
      } else fail(`${where}: sem timing.json`);
    }
  }
}
const distinct = new Set(Object.values(counts));
if (distinct.size !== 1) fail(`execuções por configuração desiguais: ${JSON.stringify(counts)}`);
if (errors.length) { console.log(`FAIL ${kind}/${name} iteration-${opt.iteration}`); for (const e of errors) console.log(`  - ${e}`); process.exit(1); }
const runsPerConfig = [...distinct][0];

// 3. agregação + metadados ----------------------------------------------------------------------
execFileSync('python3', [AGG, ITER, '--skill-name', name, '--skill-path', kind === 'skills' ? `template/.forge/skills/${name}` : relative(REPO, execFileSync('find', [join(REPO, 'template/.forge/agents'), '-name', `${name}.md`], { encoding: 'utf8' }).trim())], { stdio: ['ignore', 'ignore', 'inherit'] });
const bp = join(ITER, 'benchmark.json');
const bench = JSON.parse(readFileSync(bp, 'utf8'));
const sha = (p) => createHash('sha256').update(readFileSync(p)).digest('hex');
const files = {};
const artRoot = kind === 'skills' ? join(REPO, 'template/.forge/skills', name) : null;
if (artRoot) for (const f of walk(artRoot)) files[relative(REPO, f)] = sha(f);
else { const f = bench.metadata.skill_path; files[f] = sha(join(REPO, f)); }
const deps = JSON.parse(readFileSync(join(HERE, 'deps.json'), 'utf8'))[name] || [];
for (const d of deps) { const p = join(REPO, 'template/.forge', d); for (const f of statSync(p).isDirectory() ? walk(p) : [p]) files[relative(REPO, f)] = sha(f); }
const meta0 = JSON.parse(readFileSync(join(ITER, `eval-${evals[0].eval_name}`, 'eval_metadata.json'), 'utf8'));
Object.assign(bench.metadata, {
  executor_model: 'sonnet', grader_model: 'sonnet', analyzer_model: 'sonnet',
  runs_per_configuration: runsPerConfig, machinery_sha: meta0.machinery_sha, artifact_files: files,
  method: 'reexecução A/B da #176 (iteração 2): executor fora do repositório, braços com a mesma fixture e a mesma política, grader cego ao braço por id opaco, validação de tipo antes da agregação'
});
writeFileSync(bp, JSON.stringify(bench, null, 2) + '\n');

// 4. veredito -----------------------------------------------------------------------------------
// Regra (fixada antes da coleta): IC 95% do delta (with − without), por bootstrap estratificado —
// em cada réplica, as execuções de cada caso e configuração são reamostradas com reposição, a taxa do
// caso é a média delas e o delta do artefato é a média dos deltas dos casos. 20.000 réplicas, semente 176.
//   agrega        se o limite inferior ≥ +0,15
//   prejudica     se o limite superior ≤ −0,15
//   neutro        se o IC inteiro está em (−0,15; +0,15)
//   indeterminado nos demais casos (o IC cruza +0,15 ou −0,15)
//   inconclusivo  se defects.json da iteração declara defeito de eval comprovado (sobrepõe a classe)
function rng(seed) { let a = seed >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const cells = {};
for (const r of bench.runs) (cells[`${r.eval_id}|${r.configuration}`] ||= []).push(r.result.pass_rate);
const ids = [...new Set(bench.runs.map((r) => r.eval_id))].sort((a, b) => a - b);
const mean = (xs) => xs.reduce((a, b) => a + b, 0) / xs.length;
const caseDelta = (pick) => ids.map((id) => pick(cells[`${id}|with_skill`]) - pick(cells[`${id}|without_skill`]));
const point = mean(caseDelta(mean));
const next = rng(176); const B = 20000; const reps = [];
const resample = (xs) => mean(xs.map(() => xs[Math.floor(next() * xs.length)]));
for (let b = 0; b < B; b++) reps.push(mean(caseDelta(resample)));
reps.sort((a, b) => a - b);
const lo = reps[Math.floor(0.025 * B)], hi = reps[Math.ceil(0.975 * B) - 1];
let verdict = lo >= 0.15 ? 'agrega' : hi <= -0.15 ? 'prejudica' : (lo > -0.15 && hi < 0.15) ? 'neutro' : 'indeterminado';
const defectsPath = join(ITER, 'defects.json');
const defects = existsSync(defectsPath) ? JSON.parse(readFileSync(defectsPath, 'utf8')) : [];
if (defects.length) verdict = 'inconclusivo';
const r4 = (x) => Math.round(x * 10000) / 10000;
const perCase = ids.map((id) => ({ eval_id: id, eval_name: byId.get(id)?.eval_name, with: r4(mean(cells[`${id}|with_skill`])), without: r4(mean(cells[`${id}|without_skill`])), with_runs: cells[`${id}|with_skill`], without_runs: cells[`${id}|without_skill`] }));
const refBp = join(EVALDIR, 'workspace', `iteration-${opt['iteration-ref']}`, 'benchmark.json');
let ref = null;
if (existsSync(refBp)) {
  const rb = JSON.parse(readFileSync(refBp, 'utf8')).run_summary;
  const d = rb.with_skill.pass_rate.mean - rb.without_skill.pass_rate.mean;
  ref = { iteration: Number(opt['iteration-ref']), with: rb.with_skill.pass_rate.mean, without: rb.without_skill.pass_rate.mean, delta: r4(d) };
}
// Contagem por asserção (descritiva, para o analista não recontar): aprovações / execuções em cada
// configuração nesta iteração e na de referência, na ordem das asserções do caso.
function assertionTable(b) {
  const t = {};
  for (const r of b.runs) {
    (r.expectations || []).forEach((x, i) => {
      const k = `${r.eval_id}|${i + 1}`;
      t[k] ||= { with_skill: [0, 0], without_skill: [0, 0] };
      const c = t[k][r.configuration]; if (!c) return;
      c[1]++; if (x.passed === true) c[0]++;
    });
  }
  return t;
}
const a2 = assertionTable(bench);
const a1 = existsSync(refBp) ? assertionTable(JSON.parse(readFileSync(refBp, 'utf8'))) : {};
const assertions = Object.keys(a2).sort((x, y) => { const [e1, i1] = x.split('|').map(Number); const [e2, i2] = y.split('|').map(Number); return e1 - e2 || i1 - i2; })
  .map((k) => { const [e, i] = k.split('|').map(Number); return { eval_id: e, assertion: i, with: a2[k].with_skill.join('/'), without: a2[k].without_skill.join('/'), ref_with: a1[k] ? a1[k].with_skill.join('/') : null, ref_without: a1[k] ? a1[k].without_skill.join('/') : null }; });
const rs = bench.run_summary;
const out = {
  artifact: `${kind}/${name}`, iteration: Number(opt.iteration), runs_per_configuration: runsPerConfig,
  with: rs.with_skill.pass_rate.mean, without: rs.without_skill.pass_rate.mean, delta: r4(point),
  ci95: [r4(lo), r4(hi)], bootstrap: { replicas: B, seed: 176, strata: 'caso × configuração' },
  verdict, defects, per_case: perCase, assertions,
  time_seconds: { with: rs.with_skill.time_seconds.mean, without: rs.without_skill.time_seconds.mean },
  tokens: { with: rs.with_skill.tokens.mean, without: rs.without_skill.tokens.mean },
  reference: ref, delta_vs_reference: ref ? r4(point - ref.delta) : null
};
writeFileSync(join(ITER, 'verdict.json'), JSON.stringify(out, null, 2) + '\n');
console.log(`OK ${kind}/${name} it${opt.iteration}: with ${r4(out.with)} without ${r4(out.without)} delta ${out.delta} IC95 [${out.ci95.join(', ')}] → ${verdict}` + (ref ? ` | it${ref.iteration} delta ${ref.delta} (Δ ${out.delta_vs_reference})` : ''));
