#!/usr/bin/env node
// sync-adapters — projects .forge/** into tool-specific adapters (§15), installing ONLY the
// adapters a project actually uses (chosen at /forge:init, recorded in forge.yaml). Switching
// the active set reconciles the workspace: missing adapters are generated, removed ones pruned.
//
// Why adapters are materialized (not symlinked to .forge/): each tool discovers commands/
// agents/skills by its OWN folder convention — Claude reads .claude/, Cursor .cursor/, Kiro
// .kiro/ — and none read from .forge/. AGENTS.md (root) is the canonical interface (industry
// standard); CLAUDE/QWEN/GEMINI.md are cheap symlinks to it, generated only for active tools.
//
// Modes:
//   --set <a,b,...>   rewrite the active adapter list in forge.yaml, then reconcile (generate
//                     active + prune deactivated). Used by /forge:init.
//   --adapter all     reconcile against the active list already in forge.yaml (generate + prune).
//   --adapter <name>  regenerate just one adapter (no prune, does not change the active list).
//   --copy-links      materialize CLAUDE/QWEN/GEMINI.md as copies instead of symlinks.
//
// Dependency-free (runs in target projects without node_modules). FORGE.md frontmatter is read
// via targeted extraction for a structure the Forge owns and schema-validates — not generic YAML.
// Deterministic: no timestamps; lockfile entries sorted; running twice is byte-identical.
import {
  readFileSync, writeFileSync, mkdirSync, readdirSync, statSync, chmodSync,
  existsSync, symlinkSync, lstatSync, unlinkSync, readlinkSync, rmdirSync, realpathSync
} from 'node:fs';
import { createHash } from 'node:crypto';
import { join, relative, basename, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// CliError — marca as validações INTENCIONAIS (FORGE.md ausente, --set vazio, adapter
// desconhecido) que o galho principal converte em `FAIL (mensagem)` de uma linha. Um erro
// inesperado (bug interno, EACCES, ENOTDIR de um `.forge/` corrompido) NÃO é um `CliError` — o
// galho principal imprime o `stack` completo antes do `FAIL (...)`, exatamente como o Node fazia
// por padrão antes de existir este `try/catch` (achado de correção #130, LOW-1: o catch-all
// original engolia a stack de QUALQUER exceção, não só das validações esperadas).
class CliError extends Error {}

// ── args ─────────────────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
const opt = (name, dflt) => {
  const i = argv.indexOf(`--${name}`);
  return i >= 0 ? argv[i + 1] : dflt;
};
const SET = opt('set', null);            // comma list → rewrite active set + reconcile
const ADAPTER = opt('adapter', null);    // 'all' | single name
const ROOT = opt('root', process.cwd());
const COPY_LINKS = argv.includes('--copy-links');
const FORGE = join(ROOT, '.forge');
const ADAPTERS_DIR = join(FORGE, 'adapters');

// A checagem de `.forge/FORGE.md` NÃO roda aqui (nível de módulo): rodar `existsSync` é
// inofensivo, mas o `process.exit(1)` que a acompanhava matava qualquer processo que apenas
// importasse o módulo para ler uma exportação, mesmo a partir de um cwd sem projeto Forge — o
// mesmo dano que a #130 fecha para o bloco de entrada, só que por um caminho de módulo diferente
// (issue #130, achado de correção). A checagem amigável ("run /forge:init first") roda como
// `throw` (nunca `process.exit`) na PRIMEIRA linha do galho principal — antes de qualquer leitura
// ou escrita de `forge.yaml` (achado de correção #130, MEDIUM-1/MEDIUM-2) — e dentro de
// `reconcile()`, para quem a chamar programaticamente sem passar por ali. Só o galho principal,
// ao final do arquivo, converte a exceção em `FAIL (...)` + `exit(1)`.

// ── fs helpers ───────────────────────────────────────────────────────────────
const sha256 = (buf) => 'sha256:' + createHash('sha256').update(buf).digest('hex');
const ensure = (dir) => mkdirSync(dir, { recursive: true });
const writeIfChanged = (path, content) => {
  if (existsSync(path) && readFileSync(path, 'utf8') === content) return;
  ensure(dirname(path));
  writeFileSync(path, content);
};
const exists = (p) => { try { lstatSync(p); return true; } catch { return false; } };

function walk(dir) {
  const out = [];
  if (!existsSync(dir)) return out;
  for (const entry of readdirSync(dir).sort()) {
    if (entry === '.DS_Store') continue;
    const p = join(dir, entry);
    statSync(p).isDirectory() ? out.push(...walk(p)) : out.push(p);
  }
  return out;
}

function removeEmptyDirs(dir) {
  if (!existsSync(dir) || !statSync(dir).isDirectory()) return;
  for (const e of readdirSync(dir)) removeEmptyDirs(join(dir, e));
  try { if (readdirSync(dir).length === 0) rmdirSync(dir); } catch { /* not empty */ }
}

// ── FORGE.md frontmatter (targeted extraction) ──────────────────────────────
function fmExtract(md) {
  const m = md.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return {};
  const out = {};
  let section = null;
  for (const line of m[1].split('\n')) {
    const top = line.match(/^([a-z_]+):\s*(.*)$/);
    const sub = line.match(/^ {2}([a-z_]+):\s*(.*)$/);
    if (top) { section = top[1]; if (top[2]) out[section] = top[2]; }
    else if (sub && section) out[`${section}.${sub[1]}`] = sub[2];
  }
  return out;
}
// Lida sob demanda (não no import): ler `FORGE.md` na avaliação do módulo mataria o import de
// quem só quer uma exportação a partir de um cwd sem projeto Forge (mesma classe da #130).
let _fm = null;
function fm() {
  if (_fm === null) _fm = fmExtract(readFileSync(join(FORGE, 'FORGE.md'), 'utf8'));
  return _fm;
}
const val = (k) => fm()[k] ?? '';

// AGENTS.md operational projection (§7.2, header §7.4) — generated by the always-on core step.
let _projected = null;
function projectAgentsMd() {
  if (_projected) return _projected;
  const tpl = readFileSync(join(FORGE, 'templates', 'AGENTS.md'), 'utf8');
  _projected = tpl
    .replaceAll('{{PROJECT_NAME}}', val('project.name'))
    .replaceAll('{{PROJECT_DISPLAY}}', val('project.display'))
    .replaceAll('{{PROJECT_DESCRIPTION}}', val('project.description'))
    .replaceAll('{{REPO_SLUG}}', val('project.repo_slug'))
    .replaceAll('{{DEFAULT_BRANCH}}', val('project.default_branch'))
    .replaceAll('{{JIRA_KEY}}', '')
    .replaceAll('{{JIRA_SITE}}', '')
    .replaceAll('{{ISSUER}}', '')
    .replaceAll('{{RUN_CMD}}', val('runtime.run'))
    .replaceAll('{{TEST_CMD}}', val('runtime.test'))
    .replaceAll('{{TYPECHECK_CMD}}', val('runtime.typecheck'))
    .replaceAll('{{LINT_CMD}}', val('runtime.lint'));
  return _projected;
}

// ── active adapter list in forge.yaml ────────────────────────────────────────
const FORGE_YAML = join(FORGE, 'forge.yaml');
function readActive() {
  const y = readFileSync(FORGE_YAML, 'utf8');
  const m = y.match(/^  adapters:\n((?:    - .*\n)+)/m);
  if (!m) return ['claude'];
  return m[1].split('\n').map((l) => l.replace(/^ {4}- /, '').trim()).filter(Boolean);
}
// readYamlAutoFlag — leitura pura de um `<key>.auto` em um forge.yaml explícito (nunca o global
// FORGE_YAML implícito): usada por preToolUseWiring(root) para que a leitura dependa só do
// argumento, nunca do cwd/argv de quem importou o módulo (achado de correção da #130, MEDIUM-1).
function readYamlAutoFlag(yamlPath, key) {
  try {
    const y = readFileSync(yamlPath, 'utf8');
    const m = y.match(new RegExp(`^${key}:\\n(?:[ ].*\\n)*?[ ]+auto:[ ]*(true|false)`, 'm'));
    return m ? m[1] === 'true' : false;
  } catch { return false; }
}

// preToolUseWiring(root) — exportação nomeada e estável (#130, achado de correção HIGH-1): a
// função que MONTA a fiação PreToolUse/SessionStart/SessionEnd, como um objeto puro, sem
// escrever nada em disco e sem depender do ROOT/cwd de quem importou o módulo — só do `root`
// explícito recebido. É esta função, e não `reconcile` (que escreve), que a #125 e a #160 leem
// para comparar contra o `.claude/settings.json` já materializado (issue #130: `const wiring =
// mod.preToolUseWiring(root)`). `GENERATORS.claude` chama esta mesma função para gerar o
// settings.json real, então as duas leituras nunca divergem.
export function preToolUseWiring(root) {
  const forgeYaml = join(root, '.forge', 'forge.yaml');
  const hooks = { PreToolUse: [{ matcher: 'Bash', hooks: [{ type: 'command', command: '$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh' }] }] };
  const handoffAuto = readYamlAutoFlag(forgeYaml, 'handoff');
  const ledgerAuto = readYamlAutoFlag(forgeYaml, 'ledger');
  const liaisonAuto = readYamlAutoFlag(forgeYaml, 'liaison');
  // SessionStart injeta o handoff, os itens do ledger e/ou o resumo do inbox do liaison — o hook
  // decide o quê lendo o forge.yaml, então basta um dos flags para materializá-lo.
  if (handoffAuto || ledgerAuto || liaisonAuto) {
    hooks.SessionStart = [{ hooks: [{ type: 'command', command: '$CLAUDE_PROJECT_DIR/.forge/hooks/session/on-session-start.sh' }] }];
  }
  // SessionEnd só regenera o scaffold do handoff (o ledger é regenerado a cada mutação).
  if (handoffAuto) {
    hooks.SessionEnd = [{ hooks: [{ type: 'command', command: '$CLAUDE_PROJECT_DIR/.forge/hooks/session/on-session-end.sh' }] }];
  }
  return hooks;
}

function writeActive(names) {
  let y = readFileSync(FORGE_YAML, 'utf8');
  const block = '  adapters:\n' + names.map((n) => `    - ${n}`).join('\n') + '\n';
  const re = /^  adapters:\n(?:    - .*\n)+/m;
  y = re.test(y) ? y.replace(re, block) : y.replace(/^(harness:\n)/m, `$1${block}`);
  writeIfChanged(FORGE_YAML, y);
}

// ── lockfile per generation unit ─────────────────────────────────────────────
function makeLock() {
  const entries = [];
  const api = {
    entries,
    emit(destAbs, content, srcAbs = null) {
      writeIfChanged(destAbs, content);
      // O bit de execução é parte do artefato, não metadado descartável. Uma skill pode trazer
      // `scripts/` (o motor determinístico que ela invoca); projetado sem +x, o script funciona
      // no canônico `.forge/` e falha com "permission denied" no adapter — maquinaria entregue
      // quebrada, e a diferença só aparece quando alguém a executa. Espelha SÓ o bit de
      // execução do fonte; nunca amplia permissão de leitura ou escrita.
      if (srcAbs && existsSync(srcAbs) && (statSync(srcAbs).mode & 0o111)) {
        chmodSync(destAbs, statSync(destAbs).mode | 0o111);
      }
      entries.push({ dest: relative(ROOT, destAbs), src: srcAbs ? relative(ROOT, srcAbs) : null, sha256: sha256(Buffer.from(content)) });
    },
    linkToAgentsMd(linkName) {
      const p = join(ROOT, linkName);
      if (COPY_LINKS) { api.emit(p, projectAgentsMd(), join(FORGE, 'FORGE.md')); return; }
      if (exists(p)) {
        const st = lstatSync(p);
        if (st.isSymbolicLink() && readlinkSync(p) === 'AGENTS.md') {
          entries.push({ dest: linkName, src: 'AGENTS.md', sha256: 'symlink' });
          return;
        }
        unlinkSync(p);
      }
      symlinkSync('AGENTS.md', p);
      entries.push({ dest: linkName, src: 'AGENTS.md', sha256: 'symlink' });
    },
  };
  return api;
}
function readLockDests(name) {
  const p = join(ADAPTERS_DIR, `${name}.lock.yaml`);
  if (!existsSync(p)) return [];
  return [...readFileSync(p, 'utf8').matchAll(/^ {2}- dest: (.*)$/gm)].map((m) => m[1]);
}
function writeLock(name, lock) {
  lock.entries.sort((a, b) => a.dest.localeCompare(b.dest));
  const out = [
    '# Generated by sync-adapters.mjs — drift detection input for forge doctor (§15).',
    `adapter: ${name}`,
    'files:',
    ...lock.entries.map((e) =>
      [`  - dest: ${e.dest}`, e.src ? `    src: ${e.src}` : null, `    sha256: ${e.sha256}`].filter(Boolean).join('\n')),
    '',
  ].join('\n');
  writeIfChanged(join(ADAPTERS_DIR, `${name}.lock.yaml`), out);
}

// ── shared projections ───────────────────────────────────────────────────────
const commandFiles = () =>
  walk(join(FORGE, 'commands')).filter((f) => f.endsWith('.md') && basename(f) !== 'README.md');
const skillFiles = () => walk(join(FORGE, 'skills'));

function emitAgentsCommands(lock) {
  for (const src of commandFiles()) lock.emit(join(ROOT, '.agents/commands/forge', basename(src)), readFileSync(src, 'utf8'), src);
}
function emitAgentsSkills(lock) {
  for (const src of skillFiles()) {
    const rel = relative(join(FORGE, 'skills'), src);
    lock.emit(join(ROOT, '.agents/skills', rel), readFileSync(src, 'utf8'), src);
  }
}

// ── core (always generated) ──────────────────────────────────────────────────
function generateCore(lock) {
  lock.emit(join(ROOT, 'AGENTS.md'), projectAgentsMd(), join(FORGE, 'FORGE.md'));
}

// ── adapter generators ───────────────────────────────────────────────────────
const GENERATORS = {
  claude(lock) {
    // Slash commands /forge:* NÃO são projetados em .claude/commands/ (contract C1, revisado): o
    // Claude Code (>= 2.x) descontinuou o namespace via subdiretório ali — comandos soltos viram
    // /<arquivo>, sem o prefixo `forge:`. Os /forge:* canônicos passam a vir de um PLUGIN
    // (name: forge), instalado por `npx forge-harness install-plugin` (auto no init) ou pelo
    // marketplace git. Gerador: template/.forge/scripts/lib/plugin-build.mjs.
    for (const tree of ['agents', 'skills']) {
      for (const src of walk(join(FORGE, tree))) {
        lock.emit(join(ROOT, '.claude', tree, relative(join(FORGE, tree), src)), readFileSync(src, 'utf8'), src);
      }
    }
    const hooks = preToolUseWiring(ROOT);
    lock.emit(join(ROOT, '.claude/settings.json'), JSON.stringify({ hooks }, null, 2) + '\n');
    lock.linkToAgentsMd('CLAUDE.md');
  },
  codex(_lock) { /* consumes the canonical AGENTS.md (core) — no extra target (§15) */ },
  gemini(lock) { lock.linkToAgentsMd('GEMINI.md'); },
  qwen(lock) { emitAgentsCommands(lock); lock.linkToAgentsMd('QWEN.md'); },
  'forge-cli'(lock) { emitAgentsCommands(lock); emitAgentsSkills(lock); },
  'agents-skills'(lock) { emitAgentsSkills(lock); },
  kiro(lock) {
    const steering = `# Forge — steering for Kiro

> Generated from .forge/FORGE.md by \`forge sync-adapters\`. Do not edit. Re-run sync after
> editing .forge/**.

Project: **${val('project.display')}** (\`${val('project.name')}\`) — ${val('project.description')}

Rules for working in this repository:

1. The canonical source of governance and specs is **\`.forge/\`**. Read \`AGENTS.md\` (root)
   for the operational guide and \`.forge/FORGE.md\` for full governance.
2. **Never create or use \`.kiro/specs/\`** — the spec lifecycle lives in
   \`.forge/specs/active/\` and \`.forge/product/current/\` (single source of truth, §15).
3. Conventions are enforced by \`.forge/rules/\`; validate work with
   \`bash .forge/scripts/doctor.sh --report\` before declaring done.
4. Worktrees live under \`.forge/worktrees/<change-id>/\`; branches \`feature/<change-id>\`
   target \`develop\`.
`;
    lock.emit(join(ROOT, '.kiro/steering/forge.md'), steering, join(FORGE, 'FORGE.md'));
  },
  cursor(lock) {
    const mdc = `---
description: Forge Project Harness — canonical governance pointer (source of truth .forge/)
alwaysApply: true
---

This repository uses the Forge Project Harness. The canonical source is \`.forge/\`; the
operational guide is \`AGENTS.md\` (root). Follow \`.forge/rules/\` conventions; specs live in
\`.forge/specs/active/\` (never edit \`.forge/product/current/\` by hand). Identifiers in
English; docs in Portugues Brasileiro; money as integer cents; no AI co-authorship in commits.
Validate with \`bash .forge/scripts/doctor.sh --report\` before declaring work done.
`;
    lock.emit(join(ROOT, '.cursor/rules/forge.mdc'), mdc, join(FORGE, 'FORGE.md'));
  },
};

// Deterministic order; core is implicit and always first.
const ORDER = ['claude', 'codex', 'gemini', 'qwen', 'forge-cli', 'agents-skills', 'kiro', 'cursor'];
const KNOWN = new Set(ORDER);

// ── reconcile (generate active + prune deactivated) ──────────────────────────
// NÃO exportada (achado de correção #130, MEDIUM-4): a iteração 1 exportava esta função para
// #160/#125 acionarem a reconciliação sem depender do CLI, mas nenhuma delas precisa — as duas
// importam `preToolUseWiring(root)` (acima), a leitura PURA e parametrizada, para comparar sem
// escrever. `reconcile` nunca foi exportada em `origin/develop` antes desta issue, e exportá-la
// agora exporia uma escrita implícita no ROOT do módulo (derivado de --root/cwd de quem importa,
// pré-existente à #130 — já em 480ac52) para qualquer futuro import: um `mod.reconcile([...])`
// chamado com cwd na raiz de outro projeto reconciliaria ESSE projeto, o mesmo dano que a #130
// fecha para o import simples. Mantida como função de módulo, só para o galho principal (abaixo)
// chamar. Se um consumidor real precisar de reconciliação programática, o desenho correto é uma
// função parametrizada pela raiz explícita (`reconcileAt(root, names)`), a abrir como item de
// ledger próprio quando esse consumidor existir — não esta.
//
// process.exit só dentro do galho principal (achado de correção #130, HIGH-2): as duas
// validações abaixo LANÇAM, nunca chamam `process.exit` diretamente — quem chama `reconcile`
// programaticamente (import, não CLI) recebe uma exceção catchable, nunca tem o processo morto
// à força. O galho principal, ao final do arquivo, é quem converte a exceção em `FAIL (...)` +
// `exit(1)` para o uso via CLI.
function reconcile(activeNames) {
  if (!existsSync(join(FORGE, 'FORGE.md'))) {
    throw new CliError(`no .forge/FORGE.md under ${ROOT} — run /forge:init first`);
  }
  for (const n of activeNames) {
    if (!KNOWN.has(n)) throw new CliError(`unknown adapter '${n}' — known: ${ORDER.join(', ')}`);
  }
  const active = ORDER.filter((n) => activeNames.includes(n)); // canonical order

  const coreLock = makeLock();
  generateCore(coreLock);
  writeLock('core', coreLock);

  const activeDests = new Set(coreLock.entries.map((e) => e.dest));
  const prevDestsByAdapter = new Map();   // lockfile dests BEFORE regeneration (for stale prune)
  for (const name of active) {
    prevDestsByAdapter.set(name, readLockDests(name));
    const lock = makeLock();
    GENERATORS[name](lock);
    writeLock(name, lock);
    lock.entries.forEach((e) => activeDests.add(e.dest));
    console.log(`OK ${name} adapter synced (${lock.entries.length} targets)`);
  }

  // prune STALE dests of still-active adapters: paths an adapter emitted before but no longer does
  // (e.g. .claude/commands/forge/* after C1 moved /forge:* to the plugin). Remove only if no active
  // adapter/core now owns the path. Keeps upgrades clean without a manual sweep; idempotent (a fresh
  // tree has no prior lockfile, so nothing to prune, and a second run finds nothing stale).
  let prunedStale = 0;
  for (const name of active) {
    for (const dest of prevDestsByAdapter.get(name) || []) {
      if (activeDests.has(dest)) continue;
      const abs = join(ROOT, dest);
      if (exists(abs)) { try { unlinkSync(abs); prunedStale++; } catch { /* already gone */ } }
    }
  }

  // prune deactivated adapters: remove their dests not owned by any active adapter/core
  let pruned = 0;
  for (const file of readdirSync(ADAPTERS_DIR)) {
    if (!file.endsWith('.lock.yaml')) continue;
    const name = file.replace('.lock.yaml', '');
    if (name === 'core' || active.includes(name)) continue;
    const lockText = readFileSync(join(ADAPTERS_DIR, file), 'utf8');
    for (const m of lockText.matchAll(/^ {2}- dest: (.*)$/gm)) {
      const dest = m[1];
      if (activeDests.has(dest)) continue;
      const abs = join(ROOT, dest);
      if (exists(abs)) { unlinkSync(abs); pruned++; }
    }
    unlinkSync(join(ADAPTERS_DIR, file));
    console.log(`OK ${name} adapter pruned (deactivated)`);
  }
  for (const dir of ['.claude', '.agents', '.cursor', '.kiro']) removeEmptyDirs(join(ROOT, dir));

  const totalPruned = pruned + prunedStale;
  console.log(`OK reconcile complete: ${active.length} active [${active.join(', ')}]${totalPruned ? `, ${totalPruned} files pruned` : ''}`);
}

// ── main guard (#130) ────────────────────────────────────────────────────────
// Sem isto, importar o módulo (`import(...)`) para ler uma exportação executava o bloco de
// entrada por igual — reconciliando os 70 arquivos do consumidor como efeito colateral do
// import. `realpathSync` nos DOIS lados: `sync-adapters.sh` invoca por `exec node
// ".../lib/sync-adapters.mjs"`, e comparar string crua (`import.meta.url` vs `process.argv[1]`
// sem normalizar) diria "não sou o principal" também para essa invocação legítima, desarmando
// o gerador em vez de só desarmar o import — exatamente a armadilha que a retratação da issue
// #130 registra (uma versão anterior usava `require('node:fs')` dentro de ESM; o
// `ReferenceError` caía no `catch` e o resultado era `false` também na invocação direta).
function isMainModule() {
  try {
    if (!process.argv[1]) return false;
    return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
}

// ── entry ────────────────────────────────────────────────────────────────────
// process.exit só dentro deste galho (achado de correção #130, HIGH-2): TODA validação abaixo
// (e as de `reconcile`, chamada de dentro do try) lança `Error`; este é o ÚNICO lugar do arquivo
// que converte exceção em `console.error('FAIL (...)')` + `process.exit(1)`, e só roda quando o
// arquivo é o principal — nunca quando é importado.
if (isMainModule()) {
  try {
    // Checagem de .forge/FORGE.md na PRIMEIRA linha do galho principal (achado de correção #130,
    // MEDIUM-1/MEDIUM-2): antes rodava só dentro de reconcile(), então --set chamava writeActive()
    // (gravando forge.yaml) ANTES de chegar lá, e o modo default/--adapter all chamava
    // readActive() primeiro — que lê forge.yaml e falha com ENOENT cru se .forge/ nem existir,
    // vazando uma mensagem diferente da amigável ("no .forge/FORGE.md ... — run /forge:init
    // first") e, no caso do --set, mutando o consumidor no próprio caminho de falha (a mesma
    // classe de defeito que a #130 fecha para o bloco de entrada). Checar aqui garante mensagem e
    // ordem idênticas nos três modos, e nenhuma escrita antes de validar.
    if (!existsSync(join(FORGE, 'FORGE.md'))) {
      throw new CliError(`no .forge/FORGE.md under ${ROOT} — run /forge:init first`);
    }
    if (SET !== null) {
      const names = SET.split(',').map((s) => s.trim()).filter(Boolean);
      if (names.length === 0) throw new CliError('--set needs at least one adapter');
      for (const n of names) {
        if (!KNOWN.has(n)) throw new CliError(`unknown adapter '${n}' — known: ${ORDER.join(', ')}`);
      }
      writeActive(ORDER.filter((n) => names.includes(n)));
      reconcile(names);
    } else if (ADAPTER === 'all' || ADAPTER === null) {
      reconcile(readActive());
    } else {
      // regenerate a single adapter (no prune, no active-list change); core first — checagem de
      // FORGE.md já rodou acima, no topo do galho principal; não duplicar aqui.
      if (!KNOWN.has(ADAPTER)) throw new CliError(`unknown adapter '${ADAPTER}' — known: ${ORDER.join(', ')}, all`);
      const coreLock = makeLock();
      generateCore(coreLock);
      writeLock('core', coreLock);
      const lock = makeLock();
      GENERATORS[ADAPTER](lock);
      writeLock(ADAPTER, lock);
      console.log(`OK ${ADAPTER} adapter synced (${lock.entries.length} targets)`);
    }
  } catch (e) {
    // Só um CliError (validação intencional) vira FAIL de uma linha; qualquer outra exceção
    // (bug interno, EACCES, ENOTDIR de um .forge/ corrompido) imprime o stack completo primeiro
    // — o diagnóstico que o Node dava por padrão antes deste try/catch existir (achado de
    // correção #130, LOW-1).
    if (!(e instanceof CliError)) console.error(e.stack || String(e));
    console.error(`FAIL (${e.message})`);
    process.exit(1);
  }
}
