#!/usr/bin/env node
// prep.mjs — materializa os casos de uma iteração de reexecução A/B fora do repositório.
//
// Uso: node prep.mjs <skills|agents> <nome> --iteration 2 --runs 1-3 [--evals 1,2,3]
// Ambiente: REEXEC_SCRATCH (obrigatório, diretório descartável fora do repositório).
//
// Para cada (eval, execução), monta os dois braços (with_skill e without_skill) com o MESMO setup.sh,
// a MESMA maquinaria (FORGE_REPO = esta árvore) e datas de commit fixas, de modo que os commits da
// fixture tenham o mesmo sha nos dois braços. A cópia literal de um braço para o outro não serve:
// graph.json grava a raiz absoluta e o setup grava o sha dele. A igualdade é provada por um digest
// de conteúdo (raiz absoluta e carimbos ISO trocados por marcador), pelos refs do git e pelo
// git status, e a divergência aborta.
// Depois do digest, instala as dependências declaradas em deps.json nos dois braços e o artefato
// sob teste só no with_skill. Cada execução recebe um id opaco: nem o caminho nem o nome do
// diretório revelam artefato, caso ou configuração ao executor e ao grader.
import { execFileSync } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { appendFileSync, cpSync, existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '../../..');
if (!existsSync(join(REPO, 'bin/forge.mjs')) || JSON.parse(readFileSync(join(REPO, 'package.json'), 'utf8')).name !== 'forge-harness') {
  console.error(`FAIL raiz do harness não confere: ${REPO}`); process.exit(1);
}
const SCRATCH = process.env.REEXEC_SCRATCH;
if (!SCRATCH) { console.error('FAIL REEXEC_SCRATCH ausente'); process.exit(2); }
if (resolve(SCRATCH).startsWith(REPO)) { console.error('FAIL REEXEC_SCRATCH dentro do repositório'); process.exit(2); }

const [kind, name, ...rest] = process.argv.slice(2);
const opt = { iteration: '2', runs: '1-3', evals: '' };
for (let i = 0; i < rest.length; i += 2) opt[rest[i].replace(/^--/, '')] = rest[i + 1];
if (!['skills', 'agents'].includes(kind) || !name) { console.error('uso: prep.mjs <skills|agents> <nome> --iteration N --runs a-b [--evals 1,2]'); process.exit(2); }
const [r0, r1] = opt.runs.split('-').map(Number);
const runs = []; for (let r = r0; r <= (r1 || r0); r++) runs.push(r);

const EVALDIR = join(REPO, '.forge/evals', kind, name);
const ITER = join(EVALDIR, 'workspace', `iteration-${opt.iteration}`);
mkdirSync(ITER, { recursive: true });
const snap = join(ITER, 'evals.json');
if (!existsSync(snap)) cpSync(join(EVALDIR, 'evals.json'), snap);
const evals = JSON.parse(readFileSync(snap, 'utf8'));
const wanted = opt.evals ? opt.evals.split(',').map(Number) : evals.evals.map((e) => e.id);

const T = join(REPO, 'template/.forge');
function artifactPath() {
  if (kind === 'skills') return join(T, 'skills', name);
  const hit = execFileSync('find', [join(T, 'agents'), '-name', `${name}.md`], { encoding: 'utf8' }).trim().split('\n').filter(Boolean);
  if (hit.length !== 1) throw new Error(`agente ${name}: ${hit.length} arquivos`);
  return hit[0];
}
const ART = artifactPath();
const ART_REL = relative(T, ART); // skills/<nome> ou agents/<família>/<nome>.md
const deps = (JSON.parse(readFileSync(join(HERE, 'deps.json'), 'utf8'))[name]) || [];
const BASE_SHA = execFileSync('git', ['-C', REPO, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
const tmplExec = readFileSync(join(HERE, 'prompts/executor.md'), 'utf8');
const tmplGrade = readFileSync(join(HERE, 'prompts/grader.md'), 'utf8');
const SANDBOX = {
  git_local: 'permitido (branch, worktree, commit, merge local)',
  push: 'só para remotes que apontam para dentro do projeto',
  build_e_teste_local: 'permitido sem rede',
  rede: 'proibida',
  subagentes: 'permitidos, Agent com model sonnet e general-purpose, mesma política repassada',
  docker: 'proibido',
  tmp: '/tmp/<x> é mapeado para o diretório tmp da execução',
  igual_nas_duas_configuracoes: true
};

function walk(dir, acc = []) {
  for (const n of readdirSync(dir)) {
    const p = join(dir, n);
    if (n === '.git') continue;
    const s = statSync(p, { throwIfNoEntry: false });
    if (!s) continue;
    if (s.isDirectory()) walk(p, acc); else if (s.isFile()) acc.push(p);
  }
  return acc;
}
function digest(root) {
  const h = createHash('sha256');
  for (const f of walk(root).sort()) {
    // Normaliza o que difere legitimamente entre dois braços montados pelo mesmo setup: a raiz
    // absoluta e carimbos de tempo ISO (graph.json grava generated_at).
    const buf = readFileSync(f).toString('latin1').split(root).join('<ROOT>')
      .replace(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z/g, '<TS>');
    h.update(relative(root, f)); h.update('\0'); h.update(buf); h.update('\0');
  }
  // Histórico por assunto e refs por nome: um commit que versiona arquivo com carimbo de tempo
  // (impact.json) muda de sha entre os braços sem mudar de conteúdo normalizado.
  h.update(execFileSync('git', ['-C', root, 'log', '--all', '--topo-order', '--format=%s'], { encoding: 'utf8' }));
  h.update(execFileSync('git', ['-C', root, 'for-each-ref', '--format=%(refname)'], { encoding: 'utf8' }));
  let head = 'DETACHED';
  try { head = execFileSync('git', ['-C', root, 'symbolic-ref', '-q', '--short', 'HEAD'], { encoding: 'utf8' }); } catch { /* HEAD destacado */ }
  h.update(head);
  h.update(execFileSync('git', ['-C', root, 'status', '--porcelain'], { encoding: 'utf8' }));
  return h.digest('hex');
}
function install(rel, work) {
  const src = join(T, rel);
  const dst = join(work, '.forge', rel);
  mkdirSync(dirname(dst), { recursive: true });
  cpSync(src, dst, { recursive: true });
}
function fill(t, vars) { return Object.entries(vars).reduce((s, [k, v]) => s.split(`{{${k}}}`).join(v), t); }

const env = { ...process.env, FORGE_REPO: REPO, GIT_AUTHOR_DATE: '2026-09-20T12:00:00-0300', GIT_COMMITTER_DATE: '2026-09-20T12:00:00-0300' };
mkdirSync(join(SCRATCH, 'runs'), { recursive: true });
const MAP = join(SCRATCH, 'map.tsv');

for (const ev of evals.evals.filter((e) => wanted.includes(e.id))) {
  const fixture = ev.fixture || (ev.files && ev.files[0]) || `fixtures/${ev.eval_name}/setup.sh`;
  const setup = join(EVALDIR, fixture);
  if (!existsSync(setup)) throw new Error(`setup ausente: ${setup}`);
  const caseDir = join(ITER, `eval-${ev.eval_name}`);
  mkdirSync(caseDir, { recursive: true });
  const fixtureTree = execFileSync('git', ['-C', REPO, 'rev-parse', `HEAD:${relative(REPO, dirname(setup))}`], { encoding: 'utf8' }).trim();
  const dirty = execFileSync('git', ['-C', REPO, 'status', '--porcelain', '--', dirname(setup)], { encoding: 'utf8' }).trim();
  writeFileSync(join(caseDir, 'eval_metadata.json'), JSON.stringify({
    eval_id: ev.id, eval_name: ev.eval_name, prompt: ev.prompt,
    assertions: ev.assertions.map((a) => (typeof a === 'string' ? a : a.text)),
    fixture, fixture_tree: dirty ? `${fixtureTree} (com alterações não commitadas no momento do prep)` : fixtureTree,
    machinery_sha: BASE_SHA, sandbox: SANDBOX
  }, null, 2) + '\n');
  const assertions = ev.assertions.map((a, i) => `${i + 1}. ${typeof a === 'string' ? a : a.text}`).join('\n');
  for (const run of runs) {
    const digests = {};
    for (const config of ['with_skill', 'without_skill']) {
      const id = randomBytes(5).toString('hex');
      const RUN = join(SCRATCH, 'runs', id);
      const WORK = join(RUN, 'work'), OUT = join(RUN, 'outputs'), TMP = join(RUN, 'tmp');
      mkdirSync(OUT, { recursive: true }); mkdirSync(TMP, { recursive: true });
      execFileSync('bash', [setup, WORK], { env, cwd: RUN, stdio: ['ignore', 'ignore', 'inherit'] });
      digests[config] = digest(WORK);
      const excl = join(WORK, '.git/info/exclude');
      const cur = existsSync(excl) ? readFileSync(excl, 'utf8') : '';
      for (const line of ['/.forge/skills/', '/.forge/agents/']) if (!cur.split('\n').includes(line)) appendFileSync(excl, `${line}\n`);
      for (const d of deps) install(d, WORK);
      let block = '';
      if (config === 'with_skill') {
        install(ART_REL, WORK);
        block = kind === 'skills'
          ? `## Skill disponível\n\nEste projeto tem a skill \`${name}\` instalada em \`${WORK}/.forge/${ART_REL}/\`. Antes de agir, leia integralmente \`${WORK}/.forge/${ART_REL}/SKILL.md\` e aplique-a a este pedido, como faria com uma skill carregada na sessão.`
          : `## Seu papel\n\nVocê atua como o agente \`${name}\`. A definição dele está em \`${WORK}/.forge/${ART_REL}\`: leia-a integralmente antes de agir e siga-a como as suas instruções.`;
      }
      writeFileSync(join(RUN, 'prompt.md'), fill(tmplExec, { WORK, OUT, TMP, PROMPT: ev.prompt, ARTIFACT_BLOCK: block }).replace(/\n{3,}/g, '\n\n'));
      writeFileSync(join(RUN, 'grader_prompt.md'), fill(tmplGrade, { WORK, OUT, TMP, RUN, PROMPT: ev.prompt, ASSERTIONS: assertions, N: String(ev.assertions.length) }));
      writeFileSync(join(RUN, 'meta.json'), JSON.stringify({ id, kind, name, eval_id: ev.id, eval_name: ev.eval_name, config, run, base_sha: BASE_SHA, prepared_at: new Date().toISOString() }, null, 2) + '\n');
      appendFileSync(MAP, [id, kind, name, ev.id, ev.eval_name, config, run].join('\t') + '\n');
      console.log(`${id}\t${name}\teval ${ev.id}\t${config}\trun-${run}`);
    }
    if (digests.with_skill !== digests.without_skill) {
      console.error(`FAIL fixture divergente entre braços: ${name} eval ${ev.id} run-${run}`); process.exit(1);
    }
  }
}
