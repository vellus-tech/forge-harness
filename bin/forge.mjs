#!/usr/bin/env node
// forge-harness — bootstrap CLI (`npx forge-harness init`).
//
// Node port of installer/install.sh so the bootstrap is cross-platform and zero-install: `npx`
// fetches this package (the whole template/ tree travels inside the tarball), runs this once,
// and exits. There is no global install and no node_modules in the target — after init, all the
// ongoing tooling lives in the project's own .forge/scripts/ (bash wrappers over node libs).
//
// Mirrors install.sh step-for-step: copy template/.forge → <target>/.forge, replace the UPPERCASE
// placeholders (except under .forge/templates/, whose placeholders are meant to survive), patch
// .gitignore idempotently, wire git core.hooksPath, drop the staging CI workflow, then reconcile
// the chosen adapters via the project's own lib/sync-adapters.mjs.
//
// Zero runtime deps (node builtins only). Requires Node >= 20.
//
// Usage:
//   npx forge-harness init [--target <dir>] [--name <display>] [--slug <kebab>]
//                          [--desc <one-line>] [--adapters claude,codex,...]
//                          [--force] [--no-symlink] [--yes]
//
// Interactive when run in a TTY and core metadata is missing; --yes (or a non-TTY stdin) takes
// the derived defaults without prompting. Exit codes: 0 ok · 2 usage · 3 .forge already exists.
import {
  cpSync, existsSync, readFileSync, writeFileSync, mkdirSync, readdirSync,
  renameSync, appendFileSync,
} from 'node:fs';
import { join, resolve, dirname, basename, relative, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import { createInterface } from 'node:readline/promises';
import { homedir } from 'node:os';

const HERE = dirname(fileURLToPath(import.meta.url));     // <pkg>/bin
const PKG_ROOT = resolve(HERE, '..');                     // <pkg>
const TEMPLATE_FORGE = join(PKG_ROOT, 'template', '.forge');
const GITIGNORE_PATCH = join(PKG_ROOT, 'installer', 'gitignore.patch');
const STAGING_YML = join(PKG_ROOT, 'template', 'github', 'workflows', 'staging.yml');
const GI_MARKER = '# >>> forge (managed) >>>';
const ADAPTERS = ['claude', 'codex', 'gemini', 'qwen', 'cursor', 'kiro', 'forge-cli', 'agents-skills'];

const pkgVersion = () => {
  try { return JSON.parse(readFileSync(join(PKG_ROOT, 'package.json'), 'utf8')).version; }
  catch { return '0.0.0'; }
};

// ── arg parsing ────────────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
const flags = { force: false, forceContent: false, noSymlink: false, noPlugin: false, yes: false, help: false, version: false, dryRun: false, noBackup: false };
const vals = { target: '', source: '', slug: '', name: '', desc: '', adapters: '', out: '' };
let cmd = '';
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  switch (a) {
    case 'init': cmd = 'init'; break;
    case 'update': cmd = 'update'; break;
    case 'install-plugin': cmd = 'install-plugin'; break;
    case '--dry-run': flags.dryRun = true; break;              // update: mostra o que mudaria, sem escrever
    case '--no-backup': flags.noBackup = true; break;          // update: não cria .forge.bak-N
    case '--out': vals.out = argv[++i] ?? ''; break;            // install-plugin: destino do plugin
    case '--force': flags.force = true; break;
    case '--force-content': flags.force = true; flags.forceContent = true; break;
    case '--no-symlink': flags.noSymlink = true; break;
    case '--no-plugin': flags.noPlugin = true; break;          // init: não auto-instala o plugin forge
    case '-y': case '--yes': flags.yes = true; break;
    case '-h': case '--help': flags.help = true; break;
    case '-v': case '--version': flags.version = true; break;
    case '--target': vals.target = argv[++i] ?? ''; break;
    case '--source': vals.source = argv[++i] ?? ''; break;     // advanced: override template/.forge
    case '--slug': vals.slug = argv[++i] ?? ''; break;
    case '--name': vals.name = argv[++i] ?? ''; break;
    case '--desc': vals.desc = argv[++i] ?? ''; break;
    case '--adapters': vals.adapters = argv[++i] ?? ''; break;
    default:
      if (a.startsWith('-')) fail(`argumento desconhecido: ${a}`, 2);
      else if (!cmd) cmd = a;                                  // tolerate bare subcommand spelling
      else fail(`argumento posicional inesperado: ${a}`, 2);
  }
}

const HELP = `forge-harness ${pkgVersion()} — Spec-Driven Development harness

Uso:
  npx forge-harness init [opções]
  npx forge-harness update [--dry-run] [--no-backup] [--no-plugin] [--target <dir>]
  npx forge-harness install-plugin [--out <dir>]

Instala o harness Forge (.forge/) no projeto-alvo: fonte única projetada para
múltiplos agentes (Claude, Codex, Cursor, …), com code graph nativo e validadores
deterministas. Roda uma vez; depois tudo vive em .forge/scripts/ do projeto.

O subcomando install-plugin materializa o plugin Claude Code "forge" (slash commands
/forge:*) em ~/.claude/skills/forge (auto-load na próxima sessão). Necessário porque o
Claude Code (>= 2.x) reserva o namespace ':' para plugins — comandos soltos em
.claude/commands/ não geram /forge:*. O plugin é global; o engine .forge/ por projeto
continua vindo de 'init'.

Opções:
  --target <dir>        diretório do projeto (padrão: diretório atual)
  --name <display>      nome de exibição do projeto
  --slug <kebab>        slug em kebab-case (padrão: derivado do nome/pasta)
  --desc <texto>        descrição em 1 linha
  --adapters <lista>    adapters a instalar, separados por vírgula (padrão: claude)
                        disponíveis: ${ADAPTERS.join(', ')}
  --out <dir>           (install-plugin) destino do plugin (padrão: ~/.claude/skills/forge)
  --force               se .forge já existe, faz backup (.forge.bak-N) e sobrescreve.
                        Se houver trabalho de produto (specs/ADRs/docs), pede confirmação
                        (interativo) ou bloqueia (não-interativo) — prefira o update cirúrgico
  --force-content       sobrescreve mesmo com trabalho de produto presente (ainda faz backup)
  --no-symlink          materializa CLAUDE/QWEN/GEMINI.md como cópias (sem symlink)
  --no-plugin           (init/update) não auto-instala o plugin /forge:*
  --dry-run             (update) lista o que mudaria sem escrever nada
  --no-backup           (update) não cria .forge.bak-N (o .forge já é versionado em git)
  -y, --yes             não-interativo: usa os padrões derivados sem perguntar
  -h, --help            mostra esta ajuda
  -v, --version         mostra a versão

Interativo quando há TTY e faltam dados; caso contrário usa os padrões.`;

function fail(msg, code = 1) { console.error(`FAIL (${msg})`); process.exit(code); }
// Recursively collect every file path under dir (used by init's placeholder pass and update's overlay).
function walk(dir, acc = []) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) walk(p, acc); else acc.push(p);
  }
  return acc;
}
function slugify(s) {
  return String(s).toLowerCase().normalize('NFD').replace(/\p{Diacritic}/gu, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');  // strip combining marks, then kebab
}

// Detect human product work that --force would bury in a backup: active/archived specs and
// product docs (ADRs, capabilities, PRDs…). A fresh template has none of this — specs/active and
// specs/archived hold only .gitkeep, and product/ ships just CHANGELOG.md — so plain
// template/greenfield re-installs read as empty and are never blocked.
function scanProductContent(forge) {
  const subdirs = (d) => {
    try { return readdirSync(d, { withFileTypes: true }).filter((e) => e.isDirectory()).length; }
    catch { return 0; }
  };
  const countMdExcept = (dir, except) => {
    let n = 0;
    const walk = (d) => {
      let es; try { es = readdirSync(d, { withFileTypes: true }); } catch { return; }
      for (const e of es) {
        const p = join(d, e.name);
        if (e.isDirectory()) walk(p);
        else if (e.name.endsWith('.md') && !except.includes(e.name)) n++;
      }
    };
    walk(dir);
    return n;
  };
  const specsActive = subdirs(join(forge, 'specs', 'active'));
  const specsArchived = subdirs(join(forge, 'specs', 'archived'));
  const productDocs = countMdExcept(join(forge, 'product'), ['CHANGELOG.md']);  // template ships only CHANGELOG.md
  return { specsActive, specsArchived, productDocs, total: specsActive + specsArchived + productDocs };
}

// Materializa o plugin Claude Code "forge" a partir dos comandos canônicos do pacote
// (template/.forge/commands), via a MESMA lib que o harness usa (plugin-build.mjs). Global.
async function installPlugin(out) {
  const lib = join(TEMPLATE_FORGE, 'scripts', 'lib', 'plugin-build.mjs');
  const { collectCommands, planForgePlugin, writePlugin } = await import(pathToFileURL(lib).href);
  const dest = out || join(homedir(), '.claude', 'skills', 'forge');
  const version = pkgVersion();
  const files = planForgePlugin({ commands: collectCommands(join(TEMPLATE_FORGE, 'commands')), version });
  writePlugin(dest, files);
  return { dest, version, count: files.length - 1 };
}

// Diretórios de MAQUINARIA — substituíveis pelo template novo (overlay aditivo). Nenhum carrega
// placeholder <PROJECT_*> (verificado). Fora desta lista, tudo é dado do projeto e é preservado:
// specs/ product/ custom/ evals/ graph/ worktrees/ runners.yaml FORGE.md constitution.md context.md.
const MACHINERY_DIRS = ['agents', 'commands', 'contracts', 'hooks', 'schemas', 'scripts', 'skills', 'templates', 'rules'];

// Recolhe os arquivos que o overlay tocaria (maquinaria), como pares [rel, srcAbs].
function machineryFiles(src) {
  const out = [];
  for (const d of MACHINERY_DIRS) {
    const base = join(src, d);
    if (!existsSync(base)) continue;
    for (const f of walk(base)) {
      if (basename(f) === '.DS_Store') continue;
      out.push([relative(src, f), f]);
    }
  }
  // adapters: só as declarações *.yaml, nunca os *.lock.yaml (regenerados por sync-adapters)
  const adaptersDir = join(src, 'adapters');
  if (existsSync(adaptersDir)) {
    for (const e of readdirSync(adaptersDir)) {
      if (e.endsWith('.yaml') && !e.endsWith('.lock.yaml')) out.push([join('adapters', e), join(adaptersDir, e)]);
    }
  }
  const readme = join(src, 'README.md');
  if (existsSync(readme)) out.push(['README.md', readme]);
  return out;
}

// Só o campo harness.template_version é atualizado no forge.yaml — adapters e flags ficam intactos.
function bumpTemplateVersion(forge, version) {
  const p = join(forge, 'forge.yaml');
  if (!existsSync(p)) return false;
  const cur = readFileSync(p, 'utf8');
  let next;
  if (/^(\s*)template_version:.*$/m.test(cur)) {
    next = cur.replace(/^(\s*)template_version:.*$/m, `$1template_version: "${version}"`);
  } else if (/^harness:\s*$/m.test(cur)) {
    next = cur.replace(/^(harness:\s*\n)/m, `$1  template_version: "${version}"\n`);
  } else {
    return false;
  }
  if (next !== cur) writeFileSync(p, next);
  return next !== cur;
}

async function updateHarness() {
  const target = resolve(vals.target || process.cwd());
  const forge = join(target, '.forge');
  if (!existsSync(join(forge, 'forge.yaml')))
    fail(`.forge não encontrado em ${target} — use \`npx forge-harness init\` para instalar`, 3);

  const src = vals.source ? resolve(vals.source) : TEMPLATE_FORGE;
  const version = pkgVersion();
  const files = machineryFiles(src);

  // dry-run: lista o que mudaria (conteúdo diferente ou arquivo novo), sem escrever nada.
  if (flags.dryRun) {
    const changes = [];
    for (const [rel, srcAbs] of files) {
      const dst = join(forge, rel);
      if (!existsSync(dst)) changes.push(`+ ${rel}`);
      else if (readFileSync(srcAbs, 'utf8') !== readFileSync(dst, 'utf8')) changes.push(`~ ${rel}`);
    }
    const fy = join(forge, 'forge.yaml');
    if (existsSync(fy) && !new RegExp(`template_version:\\s*"?${version}"?`).test(readFileSync(fy, 'utf8')))
      changes.push('~ forge.yaml (template_version)');
    console.log(`forge update — dry-run (${target})`);
    console.log(changes.length ? changes.sort().join('\n') : '(nada a atualizar — já na versão do template)');
    console.log(`\n${changes.length} mudança(s) de arquivo. Rode sem --dry-run para aplicar.`);
    console.log('(a aplicação também reconcilia adapters/plugin/hooksPath/.gitignore — não previstos acima)');
    return;
  }

  const work = scanProductContent(forge);

  // backup por CÓPIA (o update edita in place; não move como o init --force). Pulável com --no-backup.
  if (!flags.noBackup) {
    let n = 1; while (existsSync(`${forge}.bak-${n}`)) n++;
    cpSync(forge, `${forge}.bak-${n}`, { recursive: true, filter: (p) => basename(p) !== '.DS_Store' });
    console.log(`backup: .forge copiado para .forge.bak-${n}`);
  }

  // overlay aditivo: sobrescreve mesmos paths, adiciona novos, NUNCA deleta extras do projeto.
  let written = 0;
  for (const [rel, srcAbs] of files) {
    const dst = join(forge, rel);
    mkdirSync(dirname(dst), { recursive: true });
    cpSync(srcAbs, dst);
    written++;
  }
  console.log(`maquinaria: ${written} arquivo(s) de template aplicados (overlay aditivo)`);

  // orphan-check defensivo: nenhum arquivo de maquinaria deve conter <PROJECT_*> após overlay
  const isTemplated = (f) => /\.(md|ya?ml)$/.test(f);
  const underTemplates = (f) => relative(forge, f).split(sep).includes('templates');
  const orphans = files
    .map(([rel]) => join(forge, rel))
    .filter((f) => isTemplated(f) && !underTemplates(f) && /<PROJECT_[A-Z_]*>/.test(readFileSync(f, 'utf8')));
  if (orphans.length) fail(`${orphans.length} arquivo(s) de maquinaria com placeholders <PROJECT_*> — template inválido?`, 1);

  // forge.yaml: só template_version
  if (bumpTemplateVersion(forge, version)) console.log(`forge.yaml: template_version -> ${version}`);

  // gitignore managed block (idempotente)
  const gi = join(target, '.gitignore');
  const giCur = existsSync(gi) ? readFileSync(gi, 'utf8') : '';
  if (!giCur.includes(GI_MARKER)) { appendFileSync(gi, readFileSync(GITIGNORE_PATCH, 'utf8')); console.log('gitignore: bloco forge adicionado'); }

  // core.hooksPath (corrige projetos que apontam para .git/hooks)
  let isRepo = false;
  try { execFileSync('git', ['-C', target, 'rev-parse', '--git-dir'], { stdio: 'ignore' }); isRepo = true; } catch { /* not a repo */ }
  if (isRepo) {
    let cur = '';
    try { cur = execFileSync('git', ['-C', target, 'config', '--get', 'core.hooksPath'], { encoding: 'utf8' }).trim(); } catch { /* unset */ }
    if (cur !== '.forge/hooks/git') {
      execFileSync('git', ['-C', target, 'config', 'core.hooksPath', '.forge/hooks/git'], { stdio: 'ignore' });
      console.log(`git: core.hooksPath -> .forge/hooks/git${cur ? ` (era ${cur})` : ''}`);
    }
  }

  // reconcilia adapters ativos (sem --set: preserva a lista do projeto)
  const syncMjs = join(forge, 'scripts', 'lib', 'sync-adapters.mjs');
  execFileSync(process.execPath, [syncMjs, '--root', target, '--adapter', 'all'], { stdio: 'inherit' });

  // plugin global /forge:* (idempotente) quando claude ativo e não --no-plugin
  const activeAdapters = (readFileSync(join(forge, 'forge.yaml'), 'utf8').match(/^ {4}- (.+)$/gm) || []).map((l) => l.replace(/^ {4}- /, '').trim());
  if (activeAdapters.includes('claude') && !flags.noPlugin) {
    try { const r = await installPlugin(''); console.log(`plugin: 'forge' v${r.version} → ${r.dest} (${r.count} comandos /forge:*)`); }
    catch (e) { console.log(`plugin: não instalado (${e?.message || e})`); }
  }

  // post-check
  try { execFileSync('bash', [join(forge, 'scripts', 'doctor.sh'), '--report'], { stdio: 'inherit' }); } catch { /* doctor exit 1 = diag ausente, não-fatal aqui */ }

  const preserved = work.total > 0 ? `${work.specsActive} spec(s) ativo(s), ${work.specsArchived} arquivado(s), ${work.productDocs} doc(s) de produto preservados` : 'sem trabalho de produto a preservar';
  console.log(`\n✔ Forge atualizado em ${target} (template v${version})`);
  console.log(`  ${preserved}`);
  if (!flags.noBackup) console.log('  backup em .forge.bak-N (remova quando validar; o .forge é versionado em git)');
}

async function main() {
  if (flags.version) { console.log(pkgVersion()); return; }
  if (flags.help || (cmd && cmd !== 'init' && cmd !== 'update' && cmd !== 'install-plugin')) { console.log(HELP); return; }

  if (!existsSync(join(TEMPLATE_FORGE, 'FORGE.md')))
    fail(`template não encontrado em ${TEMPLATE_FORGE} (pacote corrompido?)`, 1);

  // update — atualização cirúrgica do harness num projeto que já tem .forge/ (overlay aditivo da
  // maquinaria; preserva specs/product/config). O oposto do init: exige .forge existente.
  if (cmd === 'update') { await updateHarness(); return; }

  // install-plugin — instala o plugin global, independente de um projeto-alvo.
  if (cmd === 'install-plugin') {
    let r;
    try { r = await installPlugin(vals.out ? resolve(vals.out) : ''); }
    catch (e) { fail(e?.message || String(e), 1); }
    console.log(`✔ plugin 'forge' v${r.version} instalado em ${r.dest}`);
    console.log(`  ${r.count} comandos /forge:* — ative com /reload-plugins ou abra uma nova sessão do Claude Code.`);
    console.log('  O plugin é global; o engine .forge/ por projeto vem de `npx forge-harness init`.');
    return;
  }

  // resolve target
  const target = resolve(vals.target || process.cwd());
  mkdirSync(target, { recursive: true });
  const baseSlug = slugify(basename(target)) || 'projeto';

  const forge = join(target, '.forge');
  const interactive = !flags.yes && process.stdin.isTTY && process.stdout.isTTY;

  // 1. overwrite guard — never clobber an existing .forge without --force, and never let --force
  // silently bury real product work. A fresh template scans as empty, so greenfield/template
  // re-installs are unaffected; a project with specs/ADRs/docs requires explicit confirmation.
  if (existsSync(forge)) {
    if (!flags.force) fail(`.forge já existe em ${target} — re-execute com --force para backup e sobrescrita`, 3);
    const work = scanProductContent(forge);
    if (work.total > 0 && !flags.forceContent) {
      const parts = [
        work.specsActive && `${work.specsActive} spec(s) ativo(s)`,
        work.specsArchived && `${work.specsArchived} spec(s) arquivado(s)`,
        work.productDocs && `${work.productDocs} doc(s) de produto`,
      ].filter(Boolean).join(', ');
      console.error(`\n⚠️  O .forge em ${target} contém trabalho de produto (${parts}).`);
      console.error('   --force moveria tudo para .forge.bak-N e instalaria o template limpo por cima.');
      console.error('   Para ATUALIZAR preservando seu conteúdo, prefira o update cirúrgico:');
      console.error('   copie só o que mudou e rode .forge/scripts/sync-adapters.sh (sem --force).\n');
      if (!interactive)
        fail('sobrescrita bloqueada para proteger conteúdo de produto — reexecute com --force-content para confirmar (ainda faz backup)', 3);
      const rl = createInterface({ input: process.stdin, output: process.stdout });
      const ans = (await rl.question(`   Para sobrescrever mesmo assim, digite "${baseSlug}" (ENTER aborta): `)).trim();
      rl.close();
      if (ans !== baseSlug) fail('sobrescrita cancelada — nada foi alterado', 3);
    }
    let n = 1; while (existsSync(`${forge}.bak-${n}`)) n++;
    renameSync(forge, `${forge}.bak-${n}`);
    const preserved = work.total > 0 ? ` (${work.total} item(ns) de produto preservados no backup)` : '';
    console.log(`backup: .forge anterior movido para .forge.bak-${n}${preserved}`);
  }

  // 2. gather identity — interactive when TTY and not --yes, else derive defaults
  let { name, slug, desc, adapters } = vals;
  if (interactive && (!name || !slug || !desc || !adapters)) {
    const rl = createInterface({ input: process.stdin, output: process.stdout });
    const ask = async (q, d) => (((await rl.question(`${q}${d ? ` [${d}]` : ''}: `)).trim()) || d);
    console.log(`\n🔨 forge-harness — init em ${target}\n`);
    name = name || await ask('Nome do projeto (display)', basename(target));
    slug = slug || await ask('Slug (kebab-case)', slugify(name) || baseSlug);
    desc = desc || await ask('Descrição (1 linha)', `Projeto ${name}`);
    adapters = adapters || await ask(`Adapters (${ADAPTERS.join(', ')})`, 'claude');
    rl.close();
    console.log('');
  }
  slug = slug || slugify(name) || baseSlug;
  name = name || slug;
  desc = desc || `Projeto ${name}`;
  adapters = (adapters || 'claude').split(',').map((s) => s.trim()).filter(Boolean).join(',');

  // validate adapter names early (sync-adapters would also reject, but a clear message is kinder)
  const unknown = adapters.split(',').filter((a) => !ADAPTERS.includes(a));
  if (unknown.length) fail(`adapter(s) desconhecido(s): ${unknown.join(', ')} — válidos: ${ADAPTERS.join(', ')}`, 2);

  // 2. install canonical tree (skip macOS cruft on the way in)
  const src = vals.source ? resolve(vals.source) : TEMPLATE_FORGE;
  cpSync(src, forge, { recursive: true, filter: (p) => basename(p) !== '.DS_Store' });

  // 3. placeholders — UPPERCASE only, and never under .forge/templates/ (those keep their tokens)
  const repls = [
    [/<PROJECT_SLUG>/g, slug], [/<PROJECT_NAME>/g, name],
    [/<PROJECT_DESCRIPTION>/g, desc], [/<INSTALLED_AT>/g, 'installed'],
  ];
  const isTemplated = (f) => /\.(md|ya?ml)$/.test(f);
  const underTemplates = (f) => relative(forge, f).split(sep).includes('templates');
  for (const f of walk(forge)) {
    if (!isTemplated(f) || underTemplates(f)) continue;
    const before = readFileSync(f, 'utf8');
    let after = before;
    for (const [re, to] of repls) after = after.replace(re, to);
    if (after !== before) writeFileSync(f, after);
  }
  const orphans = walk(forge).filter((f) => isTemplated(f) && !underTemplates(f) && /<PROJECT_[A-Z_]*>/.test(readFileSync(f, 'utf8')));
  if (orphans.length) fail(`${orphans.length} arquivo(s) ainda contêm placeholders <PROJECT_*>`, 1);

  // 4. .gitignore patch (idempotent via marker)
  const gi = join(target, '.gitignore');
  const giCur = existsSync(gi) ? readFileSync(gi, 'utf8') : '';
  if (!giCur.includes(GI_MARKER)) {
    appendFileSync(gi, readFileSync(GITIGNORE_PATCH, 'utf8'));
    console.log('gitignore: bloco forge adicionado');
  }

  // 5. git hooks path (only when the target is a git repo)
  let isRepo = false;
  try { execFileSync('git', ['-C', target, 'rev-parse', '--git-dir'], { stdio: 'ignore' }); isRepo = true; } catch { /* not a repo */ }
  if (isRepo) {
    execFileSync('git', ['-C', target, 'config', 'core.hooksPath', '.forge/hooks/git'], { stdio: 'ignore' });
    console.log('git: core.hooksPath -> .forge/hooks/git');
  } else {
    console.log("git: não é um repositório — hooks não configurados (rode 'git init' + doctor depois)");
  }

  // 6. CI workflow (§20.2) — only for repos using the GitHub Actions layout
  if (existsSync(join(target, '.github')) || existsSync(join(target, '.git'))) {
    const wfDir = join(target, '.github', 'workflows');
    mkdirSync(wfDir, { recursive: true });
    const dst = join(wfDir, 'staging.yml');
    if (!existsSync(dst) && existsSync(STAGING_YML)) {
      cpSync(STAGING_YML, dst);
      console.log('ci: staging.yml instalado (roda só em push para staging)');
    }
  }

  // 7. adapters — install ONLY the chosen set; records them as active in forge.yaml
  const syncMjs = join(forge, 'scripts', 'lib', 'sync-adapters.mjs');
  const syncArgs = [syncMjs, '--root', target, '--set', adapters];
  if (flags.noSymlink) syncArgs.push('--copy-links');
  execFileSync(process.execPath, syncArgs, { stdio: 'inherit' });

  // 8. plugin /forge:* — quando o adapter claude está ativo, auto-instala o plugin global (os
  // slash commands /forge:* vêm dele, não de .claude/commands/ — ver contracts C1). Idempotente.
  // Pulável com --no-plugin (CI/testes não devem tocar ~/.claude). Falha é não-fatal.
  let pluginNote = '';
  const wantsClaude = adapters.split(',').includes('claude');
  if (wantsClaude && !flags.noPlugin) {
    try {
      const r = await installPlugin('');
      console.log(`plugin: 'forge' v${r.version} → ${r.dest} (${r.count} comandos /forge:*)`);
      pluginNote = '  # /forge:* já instalado — rode /reload-plugins ou abra nova sessão do Claude Code';
    } catch (e) {
      console.log(`plugin: não instalado (${e?.message || e})`);
      pluginNote = '  # instale os /forge:*: npx forge-harness install-plugin';
    }
  } else if (wantsClaude) {
    pluginNote = '  # instale os /forge:*: npx forge-harness install-plugin  (ou /plugin marketplace add vellus-tech/forge-harness)';
  }

  console.log(`\n✔ Forge instalado em ${target}`);
  console.log(`  slug: ${slug} · adapters: ${adapters}\n`);
  console.log('Próximos passos:');
  if (target !== process.cwd()) console.log(`  cd ${target}`);
  console.log('  bash .forge/scripts/doctor.sh        # detecta a stack + diagnostica o ambiente');
  console.log('  # no seu agente (Claude Code/Codex/…): /forge:status  e  /forge:spec new');
  if (pluginNote) console.log(pluginNote);
  console.log('  # codebase existente? peça ao agente para preencher o bloco runtime: do .forge/FORGE.md\n');
}

main().catch((e) => fail(e?.message || String(e), 1));
