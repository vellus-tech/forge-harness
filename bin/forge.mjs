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
  renameSync, appendFileSync, rmSync, realpathSync,
} from 'node:fs';
import { join, resolve, dirname, basename, relative, sep } from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import { createInterface } from 'node:readline/promises';
import { homedir } from 'node:os';

const HERE = dirname(fileURLToPath(import.meta.url));     // <pkg>/bin
const PKG_ROOT = resolve(HERE, '..');                     // <pkg>
const TEMPLATE_FORGE = join(PKG_ROOT, 'template', '.forge');
const GITIGNORE_PATCH = join(PKG_ROOT, 'installer', 'gitignore.patch');
const GITATTRIBUTES_PATCH = join(PKG_ROOT, 'installer', 'gitattributes.patch');
// FORGE_REMOVED_MANIFEST: override para os gates de teste injetarem tombstones sintéticas.
const REMOVED_MANIFEST = process.env.FORGE_REMOVED_MANIFEST || join(PKG_ROOT, 'installer', 'removed-files.txt');
const STAGING_YML = join(PKG_ROOT, 'template', 'github', 'workflows', 'staging.yml');
const RED_FIRST_YML = join(PKG_ROOT, 'template', 'github', 'workflows', 'red-first.yml');
const GI_MARKER = '# >>> forge (managed) >>>';
const GI_MARKER_END = '# <<< forge (managed) <<<';
const ADAPTERS = ['claude', 'codex', 'gemini', 'qwen', 'cursor', 'kiro', 'forge-cli', 'agents-skills'];

/**
 * Aplica um managed-block (mesmo mecanismo para .gitignore e .gitattributes — issue #80)
 * RECONCILIANDO, não só acrescentando.
 *
 * O comportamento anterior do .gitignore era append-once (`if (!cur.includes(MARKER)) append`):
 * quem já tinha o bloco nunca recebia padrão novo, e o harness passou a depender disso para
 * entregar correções — o backup do update, o cache local e as negações do store do liaison
 * ficaram presos no template, sem chegar a nenhum consumidor instalado. Um bloco marcado como
 * "managed" que congela na primeira escrita não é gerenciado; é um comentário.
 *
 * O que fica fora dos marcadores é do usuário e nunca é tocado — inclusive para dedup: padrão que
 * o projeto já lista por conta própria não é repetido dentro do bloco.
 */
function applyManagedBlock(target, filename, patchPath, label) {
  const fp = join(target, filename);
  const patch = readFileSync(patchPath, 'utf8');
  const cur = existsSync(fp) ? readFileSync(fp, 'utf8') : '';

  const pIni = patch.indexOf(GI_MARKER);
  const pFim = patch.indexOf(GI_MARKER_END);
  if (pIni === -1 || pFim === -1) { console.log(`${label}: patch sem marcadores — bloco não aplicado`); return; }
  const blocoPatch = patch.slice(pIni, pFim + GI_MARKER_END.length);

  const ini = cur.indexOf(GI_MARKER);
  const fim = cur.indexOf(GI_MARKER_END);
  if (ini !== -1 && (fim === -1 || fim < ini)) {
    // Marcador de abertura sem fechamento: reescrever aqui poderia comer regra do projeto.
    console.log(`${label}: bloco forge com marcadores inconsistentes — não reconciliado (conserte à mão)`);
    return;
  }

  const antes = ini === -1 ? cur : cur.slice(0, ini);
  const depois = ini === -1 ? '' : cur.slice(fim + GI_MARKER_END.length);

  // Dedup só contra o que está FORA do bloco: um brownfield que já lista `.DS_Store` (ou já
  // declara `merge=union` num path equivalente) não ganha entrada duplicada.
  const fora = new Set(
    `${antes}\n${depois}`.split('\n').map((l) => l.replace(/\s+$/, '')).filter((l) => l.trim() && !l.trimStart().startsWith('#')),
  );
  const bloco = blocoPatch
    .split('\n')
    .filter((l) => {
      const t = l.replace(/\s+$/, '');
      if (!t.trim() || t.trimStart().startsWith('#')) return true;
      return !fora.has(t);
    })
    .join('\n');

  if (ini === -1) {
    const sep = !cur || cur.endsWith('\n') ? '' : '\n';
    writeFileSync(fp, `${cur}${sep}\n${bloco}\n`);
    console.log(`${label}: bloco forge adicionado`);
    return;
  }
  const novo = `${antes}${bloco}${depois}`;
  if (novo === cur) return;
  writeFileSync(fp, novo);
  console.log(`${label}: bloco forge reconciliado`);
}

function applyGitignoreBlock(target) {
  applyManagedBlock(target, '.gitignore', GITIGNORE_PATCH, 'gitignore');
}

// .gitattributes (issue #80) — merge=union no log append-only do liaison, POR REMETENTE. O gate
// que detecta (post-merge) e bloqueia (pre-push) a duplicação — o único modo de falha do union —
// mora em .forge/scripts/check-liaison-log-integrity.sh; ver installer/gitattributes.patch.
function applyGitattributesBlock(target) {
  applyManagedBlock(target, '.gitattributes', GITATTRIBUTES_PATCH, 'gitattributes');
}

const pkgVersion = () => {
  try { return JSON.parse(readFileSync(join(PKG_ROOT, 'package.json'), 'utf8')).version; }
  catch { return '0.0.0'; }
};

// ── arg parsing ────────────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
const flags = { force: false, forceContent: false, noSymlink: false, noPlugin: false, yes: false, help: false, version: false, dryRun: false, noBackup: false, overwriteDrift: false };
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
    case '--overwrite-drift': flags.overwriteDrift = true; break; // update: aceita o template sobre a deriva local
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
  npx forge-harness update [--dry-run] [--no-backup] [--overwrite-drift] [--no-plugin] [--target <dir>]
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
  --overwrite-drift     (update) sobrescreve, com backup, a maquinaria em deriva local (fora de agents/rules/skills/templates, sem exceção declarada, sem prova de intocado pelo machinery.lock nem por uma versão publicada do template) — por padrão ela é preservada e a versão nova do template vai para .forge/cache/template-pendente/
  -y, --yes             não-interativo: usa os padrões derivados sem perguntar
  -h, --help            mostra esta ajuda
  -v, --version         mostra a versão

Interativo quando há TTY e faltam dados; caso contrário usa os padrões.`;

function fail(msg, code = 1) { console.error(`FAIL (${msg})`); process.exit(code); }

// Resolve o CHECKOUT PRINCIPAL de um caminho que pode ser um worktree linkado. `--git-common-dir`
// devolve o `.git` compartilhado por todos os worktrees; o diretório que o contém é o tronco.
// `--path-format=absolute` (git >= 2.31) é necessário porque, no próprio checkout principal,
// `--git-common-dir` devolveria `.git` relativo — e o dirname disso seria o worktree corrente,
// exatamente o que se quer evitar. Degrada para `--show-toplevel` em git antigo.
function mainCheckoutOf(target) {
  try {
    const common = execFileSync('git', ['-C', target, 'rev-parse', '--path-format=absolute', '--git-common-dir'], { encoding: 'utf8' }).trim();
    if (common && common.startsWith(sep)) return dirname(common);
  } catch { /* git < 2.31, ou não é repositório */ }
  try { return execFileSync('git', ['-C', target, 'rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim() || target; } catch { return target; }
}

// Aponta core.hooksPath para os hooks do TRONCO, por caminho ABSOLUTO — usado por init e update.
//
// Por absoluto: core.hooksPath vive no .git/config, que é compartilhado por todos os worktrees, e
// um valor RELATIVO é resolvido por cada worktree contra a PRÓPRIA árvore — que carrega a cópia
// antiga dos hooks daquela branch. O efeito é que um hook novo, versionado e já mergeado, não
// bloqueia nada em nenhum worktree ativo, e a única evidência disso é o commit proibido passando
// em silêncio. Um caminho absoluto para o tronco faz todo worktree executar o hook do tronco.
//
// O preço é que o valor passa a ser específico da máquina e do caminho do clone: mover ou
// renomear o diretório quebra o apontamento. Como core.hooksPath JÁ era config local não
// versionada (some num clone novo, some num runner de CI), o preço é de grau, não de espécie — e
// o doctor passa a verificar e a acusar o apontamento quebrado.
//
// Nunca sobrescreve um hooksPath customizado de verdade (`.githooks` e afins). O valor legado
// relativo `.forge/hooks/git` NÃO conta como customizado: ele é nosso, e é o defeito — esse é
// migrado para absoluto com a razão impressa.
const HOOKS_PATH_LEGACY = '.forge/hooks/git';
function wireHooksPath(target) {
  let isRepo = false;
  try { execFileSync('git', ['-C', target, 'rev-parse', '--git-dir'], { stdio: 'ignore' }); isRepo = true; } catch { /* not a repo */ }
  if (!isRepo) { console.log("git: não é um repositório — hooks não configurados (rode 'git init' + doctor depois)"); return; }
  const root = mainCheckoutOf(target);
  const desired = join(root, '.forge', 'hooks', 'git');
  let cur = '';
  try { cur = execFileSync('git', ['-C', target, 'config', '--get', 'core.hooksPath'], { encoding: 'utf8' }).trim(); } catch { /* unset */ }
  if (cur === desired) return; // já correto, no-op
  if (cur && cur !== HOOKS_PATH_LEGACY) {
    console.log(`git: core.hooksPath já customizado para '${cur}' — preservado (não sobrescrito).`);
    console.log(`  Os hooks do Forge (.forge/hooks/git/*) não estão ativos; encadeie-os no seu hook`);
    console.log('  customizado se quiser o gate de pre-push de docs e o guard de pre-commit de worktree.');
    return;
  }
  execFileSync('git', ['-C', target, 'config', 'core.hooksPath', desired], { stdio: 'ignore' });
  if (cur === HOOKS_PATH_LEGACY) {
    console.log(`git: core.hooksPath '${HOOKS_PATH_LEGACY}' -> '${desired}' (absoluto — worktrees passam a rodar os hooks do tronco)`);
  } else {
    console.log(`git: core.hooksPath -> ${desired}`);
  }
}

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
const MACHINERY_DIRS = ['agents', 'capabilities', 'commands', 'contracts', 'hooks', 'schemas', 'scripts', 'skills', 'templates', 'rules'];

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

// Diretórios ENRIQUECÍVEIS — maquinaria que projetos legitimamente customizam (diretivas de owner
// em rules/, gates extras em agents de review, skills locais). O overlay NÃO os sobrescreve às
// cegas (issue #16: o update reverteu diretivas de owner em rules/agents de dois consumidores).
// Decisão por arquivo, via lock de template (.forge/cache/machinery.lock — hash do TEMPLATE da
// última aplicação, não do arquivo local):
//   dst ausente ................................. escreve (arquivo novo)
//   dst == template novo ........................ no-op (já atualizado)
//   dst == hash do template ANTERIOR (lock) ..... escreve (upgrade limpo — nunca foi customizado)
//   qualquer outro caso ......................... PRESERVA e reporta (customização local)
// Sem lock (consumidor pré-rc20), o fallback é conservador: divergiu do template novo → preserva.
// `templates` entrou pela issue #71, e não é um diretório qualquer: `.forge/templates/AGENTS.md` é
// a FONTE do `AGENTS.md` da raiz — `sync-adapters.mjs` o lê e emite o arquivo do projeto a partir
// dele. Como o `update` roda `sync-adapters --adapter all` no fim, um único comando apagava a
// customização e, em seguida, regenerava o `AGENTS.md` sem ela: sem conflito, sem aviso, e
// aparecendo no output como um `~` indistinguível de qualquer atualização de maquinaria.
// Perder em silêncio o arquivo que governa o comportamento dos agentes é a classe de defeito mais
// cara que existe — o repositório continua funcionando e as regras que alguém escreveu deixam de
// ser lidas. Medido num consumidor real: 63 linhas locais contra 54 do template, com quatro regras
// de disciplina de entrega próprias, na mesma execução em que três arquivos de `rules/` e
// `skills/` eram corretamente preservados.
const ENRICHABLE_DIRS = ['agents', 'rules', 'skills', 'templates'];
const isEnrichable = (rel) => ENRICHABLE_DIRS.includes(rel.split(sep)[0]);

// Deriva local fora de ENRICHABLE_DIRS (revisão da DH-1 pelo dono, 2026-09-26). Até a 0.16.0, maquinaria própria (scripts/, hooks/, commands/, schemas/...) que divergia do template novo sem exceção declarada era sobrescrita com a linha `SOBRESCRITO (não declarado)`. O ensaio de campo da 0.16.0 mediu cerca de 40 consertos deliberados sobrescritos em cinco consumidores que nunca tinham declarado exceção (azim-crm 7, com a suíte do próprio consumidor reprovando depois). A decisão por arquivo passou a ser:
//   exceção declarada (viva ou expirada) ............................ preserva, como na #131 (inalterado)
//   com entrada no lock e sha local == lock (intocado) ............... sobrescreve, linha `ATUALIZADO`
//   sha local == versão pendente que o update anterior guardou ....... sobrescreve, linha `ATUALIZADO` (reconciliação à mão pela saída 2 do /forge:upgrade)
//   sha local em alguma versão PUBLICADA (com ou sem entrada no lock) . sobrescreve, linha `ATUALIZADO` (prova pelo histórico, ver readMachineryHistory)
//   com entrada no lock e sha local != lock, fora dos dois acima ..... PRESERVA: `PRESERVADO (deriva local)`
//   sem entrada no lock e sha local fora dos dois acima .............. PRESERVA: `PRESERVADO (sem lock para provar)`, dizendo se havia histórico de versões publicadas para consultar
//   --overwrite-drift ................................................ sobrescreve a deriva com backup, `SOBRESCRITO`
// Nos dois casos de preservação a versão nova do template vai para TEMPLATE_PENDING_REL/<rel> e o lock daquele caminho não avança. O diretório de pendentes fica sob `.forge/cache/` (ignorado pelo bloco gerenciado do .gitignore), fora de qualquer caminho que hook, runner ou sync-adapters executem ou leiam, e é reconstruído a cada aplicação real: reflete só a deriva que o último update preservou.
const TEMPLATE_PENDING_REL = '.forge/cache/template-pendente';
// `hasHistory`: havia histórico de versões publicadas para consultar (readMachineryHistory != null). Sem ele, o texto não afirma que o conteúdo está fora de toda versão publicada — só que não havia como provar.
const driftWarnLine = (n, semLock, dry, hasHistory) => `WARN: ${n} arquivo(s) de maquinaria ${dry ? 'seriam preservado(s)' : 'preservado(s)'} por deriva local`
  + `${semLock ? ` (${semLock} sem lock para provar que estava(m) intocado(s): ${hasHistory ? 'conteúdo fora de toda versão publicada do template' : 'sem histórico de versões publicadas para provar'})` : ''} — `
  + `a versão nova do template de cada um ${dry ? 'iria para' : 'está em'} ${TEMPLATE_PENDING_REL}/. Reconcilie cada arquivo: `
  + 'declare a divergência em .forge/machinery-exceptions.txt (se o conserto local deve ficar), incorpore a versão pendente à mão, '
  + 'ou aceite o template com `npx forge-harness update --overwrite-drift` (sobrescreve com backup)';

const sha256File = (p) => createHash('sha256').update(readFileSync(p)).digest('hex');

// Histórico de versões publicadas do template: `<template>/../machinery-history.json` (no pacote, `template/machinery-history.json`, ao lado de `template/.forge`), gerado por tools/build-machinery-history.mjs a partir das tags v*. Mapa caminho -> Set(sha256) de todo conteúdo que aquele caminho já teve numa versão publicada. É a prova de "intocado" quando o machinery.lock não prova (sem entrada para o caminho: consumidor que só rodou `init`, clone novo, outra máquina, porque `.forge/cache/` é ignorado pelo .gitignore gerenciado; ou entrada defasada: update feito em outra worktree que chegou por pull): um arquivo byte-idêntico a uma versão publicada nunca foi editado pelo consumidor. Sem ele, o update congelava toda a maquinaria de quem não tinha lock (medido: consumidor pristino da 0.15.0 com 22 de 22 arquivos alterados retidos, inclusive o gancho de segredos da #125). Ausente ou ilegível: sem prova, e o caminho sem entrada no lock volta ao fallback conservador (preservar).
function readMachineryHistory(src) {
  const p = join(dirname(src), 'machinery-history.json');
  if (!existsSync(p)) return null;
  try {
    const j = JSON.parse(readFileSync(p, 'utf8'));
    const map = new Map();
    for (const [rel, arr] of Object.entries(j.paths || {})) if (Array.isArray(arr)) map.set(rel, new Set(arr));
    return map;
  } catch (e) {
    console.log(`WARN: ${p} ilegível (${e.message}) — sem histórico de versões publicadas, arquivo sem entrada no machinery.lock é preservado`);
    return null;
  }
}

// Veredito de um arquivo de maquinaria própria que diverge do template novo (fora de ENRICHABLE_DIRS, sem exceção declarada), o MESMO no --dry-run e na aplicação real:
//   'lock' ........ intocado, provado pelo machinery.lock
//   'pendente' .... intocado: byte-idêntico à versão pendente que o update anterior guardou (o consumidor reconciliou à mão aceitando-a)
//   'historico' ... intocado, provado por uma versão publicada do template
//   'deriva' ...... o lock tem entrada, ela difere do local, e o local não é nenhuma versão que o harness entregou
//   'sem-lock' .... sem entrada no lock e o local não é nenhuma versão que o harness entregou, consultado o histórico de versões publicadas
//   'sem-historico' sem entrada no lock, o local não é a versão pendente e NÃO havia histórico de versões publicadas para consultar: não se sabe se é uma delas, e a linha diz isso em vez de afirmar que não é
// Todo conteúdo que o próprio harness entregou conta como intocado, com ou sem entrada no lock: o lock é por checkout (`.forge/cache/` é ignorado e `.forge/` é versionado), então fica defasado quando o update foi feito em outra worktree ou por um colega e chegou por pull, e a versão pendente aceita à mão nunca entra no lock. Deixar a entrada do lock decidir sozinha retinha como "deriva local" um arquivo que o consumidor nunca editou, e o consumidor que seguia a saída (2) do /forge:upgrade entrava num laço a cada release, com a correção do template congelada. Custo aceito (DA-27): voltar um arquivo, de propósito, a uma versão publicada mais antiga deixa de ser reconhecido como deriva — o update o atualiza com backup e linha ATUALIZADO; quem quer manter a versão antiga declara a exceção.
function driftVerdict(rel, dstHash, lock, history, pendingSha) {
  if (lock && lock.get(rel) === dstHash) return 'lock';
  if (pendingSha && pendingSha === dstHash) return 'pendente';
  const known = history && history.get(rel.split(sep).join('/'));
  if (known && known.has(dstHash)) return 'historico';
  if (lock && lock.has(rel)) return 'deriva';
  return history ? 'sem-lock' : 'sem-historico';
}
// sha256 da versão pendente que o update anterior guardou para `rel`, ou null. Lido ANTES de o update real reconstruir o diretório de pendentes.
function pendingShaOf(target, rel) {
  const p = join(target, TEMPLATE_PENDING_REL, rel);
  return existsSync(p) ? sha256File(p) : null;
}
const DRIFT_LABEL = { deriva: 'deriva local', 'sem-lock': 'sem lock para provar', 'sem-historico': 'sem lock para provar' };
const isSemLock = (verdict) => verdict === 'sem-lock' || verdict === 'sem-historico';

// Lock de maquinaria: registra o sha256 dos arquivos do TEMPLATE na versão aplicada por último —
// é a referência que permite distinguir "consumidor nunca tocou" (upgrade limpo) de "customização
// local" (preservar). Escrito pelo update a cada aplicação; formato: "<sha256>  <rel>" por linha.
function readMachineryLock(forge) {
  const p = join(forge, 'cache', 'machinery.lock');
  if (!existsSync(p)) return null;
  const map = new Map();
  let invalid = 0;
  for (const line of readFileSync(p, 'utf8').split('\n')) {
    if (!line.trim() || line.startsWith('#')) continue;
    const m = /^([0-9a-f]{64})  (.+)$/.exec(line);
    if (m) map.set(m[2], m[1]); else invalid++;
  }
  // linha ilegível = entrada perdida = fallback conservador (preserva) para aquele path — seguro,
  // mas o operador precisa saber que a integridade do lock está comprometida (escrita truncada?).
  if (invalid) console.log(`WARN: machinery.lock com ${invalid} linha(s) ilegível(is) — entradas perdidas caem no fallback conservador (preservar); o lock é reescrito ao fim deste update`);
  return map;
}
// O lock cobre TODA a maquinaria (não só ENRICHABLE_DIRS) de propósito: as entradas enriquecíveis decidem preservar-vs-sobrescrever, e as demais decidem se a divergência fora de ENRICHABLE_DIRS é refresh do template (ATUALIZADO) ou deriva local (preservada). Estreitar o escopo "para enxugar o lock" quebraria o segundo uso em silêncio.
//
// `keep` (revisão da DH-1): caminhos preservados por deriva local NÃO avançam para o sha do template novo — o lock continua registrando o que o consumidor recebeu por último (ou nada, se não havia entrada), para que o próximo update continue reconhecendo a deriva em vez de tomá-la por "intocado" e sobrescrevê-la. Map rel -> sha anterior (ou null: a linha é omitida).
function writeMachineryLock(forge, files, version, sourceNote, keep = new Map()) {
  const lines = files
    .map(([rel, srcAbs]) => [rel, keep.has(rel) ? keep.get(rel) : sha256File(srcAbs)])
    .filter(([, hash]) => hash)
    .sort((a, b) => (a[0] < b[0] ? -1 : 1))
    .map(([rel, hash]) => `${hash}  ${rel}`);
  mkdirSync(join(forge, 'cache'), { recursive: true });
  writeFileSync(join(forge, 'cache', 'machinery.lock'),
    `# forge machinery.lock — sha256 dos arquivos do template v${version} (última aplicação).\n`
    + '# Referência do update para distinguir arquivo intocado de customização/deriva local — não edite.\n'
    + (sourceNote ? `# ATENÇÃO: aplicado de --source ${sourceNote} (não o template publicado desta versão).\n` : '')
    + lines.join('\n') + '\n');
}

// Divergências DELIBERADAS entre a árvore do consumidor e a maquinaria do template (issues
// #101/#131): `.forge/machinery-exceptions.txt`, uma linha por arquivo, no formato
// "<sha256 do template no momento da declaração>  <caminho relativo a .forge/>  # razão".
// O mecanismo nasceu em campo — o axis-fare-validator já opera esse arquivo com o próprio
// `check-machinery-drift.sh` —, e a gramática aqui replica a dele por medição, não pelo formato
// literal acima: separador de colunas por espaço livre (uma ou mais), corte no primeiro `#` (o
// resto da linha é a razão; comentário-only e linha em branco são ignorados) e sha hexadecimal
// minúsculo com pelo menos 32 dígitos, não travado em 64. Qualquer token além de `<sha> <caminho>`
// malforma a linha, com ou sem `#` — igual ao parser de origem (`check-machinery-drift.sh:201-206`,
// `read -r e_sha e_rel e_resto <<< "$corpo"`; `[ -n "$e_resto" ]` marca a linha como MALFORMADA).
// Pela mesma razão, o sha é comparado por IGUALDADE ESTRITA
// contra o sha de 64 dígitos do template (`check-machinery-drift.sh:321`, `[ "${exc_sha[$EXC_IDX]}" = "$sha" ]`),
// nunca por prefixo: um sha declarado com menos de 64 dígitos (sintaxe válida, >= 32 dígitos) nunca
// é igual ao sha do template e cai sempre em EXPIRADA — a gramática aceita o comprimento truncado,
// mas a comparação nunca o trata como prefixo válido. O sha é sempre o do TEMPLATE, nunca o do
// disco: é o que permite a exceção EXPIRAR quando o template muda o arquivo de novo (DH-1 —
// expirada preserva e nomeia os dois shas, não bloqueia). Arquivo ilegível, linha malformada ou
// caminho declarado duas vezes param o update ANTES de escrever qualquer coisa, nomeando a linha —
// fail-closed, como o parser de origem: o que este parser não sabe ler não pode absolver ninguém.
// Um caminho declarado com prefixo `./` ou `.forge/` nunca bate com o `rel` real (sempre relativo
// a `.forge/`, sem prefixo), então caía em `fora-do-template` — a exceção ficava OCIOSA em
// silêncio e o conserto local do consumidor era sobrescrito sem aviso do porquê (achado do review
// adversarial, LOW). Os dois prefixos nunca aparecem num `rel` legítimo do template (nenhum
// caminho do template começa com `.` nem duplica `.forge/`), então normalizar aqui nunca colide
// com uma declaração já correta — é estritamente aditivo: só passa a enxergar declarações que
// antes eram sempre ociosas. `raw` preserva a grafia original para nomear a normalização no
// relatório, em vez de normalizar em silêncio.
function normalizeExceptionPath(rel) {
  let out = rel;
  while (out.startsWith('./')) out = out.slice(2);
  if (out.startsWith('.forge/')) out = out.slice('.forge/'.length);
  return out;
}

function readMachineryExceptions(forge) {
  const p = join(forge, 'machinery-exceptions.txt');
  const entries = new Map();
  if (!existsSync(p)) return { path: p, entries };
  let raw;
  try {
    raw = readFileSync(p, 'utf8');
  } catch (e) {
    fail(`machinery-exceptions.txt em ${p} não pôde ser lido (${e.code || e.message}) — o update para antes de escrever qualquer arquivo`, 1);
  }
  const malformed = [];
  const duplicates = [];
  raw.split('\n').forEach((line, idx) => {
    const lineNo = idx + 1;
    const hashIdx = line.indexOf('#');
    const body = (hashIdx === -1 ? line : line.slice(0, hashIdx)).trim();
    const reason = hashIdx === -1 ? '' : line.slice(hashIdx + 1).trim();
    if (!body) return; // linha em branco ou só comentário
    const tokens = body.split(/\s+/).filter(Boolean);
    const [sha, relRaw, ...resto] = tokens;
    const shaOk = typeof sha === 'string' && sha.length >= 32 && /^[0-9a-f]+$/.test(sha);
    // Qualquer token além de "<sha> <caminho>" malforma a linha, com ou sem '#' — igual ao parser
    // de origem (`check-machinery-drift.sh:201-206`: `read -r e_sha e_rel e_resto <<< "$corpo"`,
    // `[ -n "$e_resto" ]` marca MALFORMADA). `resto` já vem de `body`, que foi cortado no primeiro
    // '#' antes da tokenização — um token extra antes do '#' malforma a linha do mesmo jeito que
    // um token extra sem '#' nenhum.
    if (!shaOk || !relRaw || resto.length > 0) { malformed.push(lineNo); return; }
    const rel = normalizeExceptionPath(relRaw);
    if (entries.has(rel)) { duplicates.push({ rel, lines: [entries.get(rel).line, lineNo] }); return; }
    entries.set(rel, { sha, reason, line: lineNo, raw: relRaw !== rel ? relRaw : undefined });
  });
  if (malformed.length || duplicates.length) {
    const msgs = [];
    if (malformed.length)
      msgs.push(`${malformed.length} linha(s) malformada(s) em ${p}: linha ${malformed.join(', ')} — formato esperado "<sha256 hex do template>  <caminho relativo a .forge/>  # razão"`);
    for (const d of duplicates)
      msgs.push(`caminho declarado duas vezes em ${p}: ${d.rel} (linhas ${d.lines.join(' e ')})`);
    fail(`machinery-exceptions.txt inválido — nenhum arquivo foi escrito.\n  ${msgs.join('\n  ')}`, 1);
  }
  return { path: p, entries };
}

// Classifica CADA exceção declarada contra o universo real do template, antes de qualquer decisão
// de escrita — usada tanto pelo `--dry-run` quanto pela aplicação real, para que as duas rotas
// enxerguem a MESMA verdade sobre uma exceção declarada: a prévia mostrada ao humano antes de
// confirmar nunca pode anunciar `~ rel` (sobrescrita) para um arquivo que a aplicação real preserva.
//   viva ......... sha declarado == sha do template NOVO -> preserva (issue #131)
//   expirada ..... sha declarado != sha do template novo -> preserva mesmo assim (DH-1),
//                  nomeando os dois shas para reexame — não bloqueia o update
//   identica ..... arquivo local já é byte-idêntico ao template novo -> nada a fazer, ociosa
//   enrichable ... caminho está em ENRICHABLE_DIRS -> a preservação por lock já cobre; a
//                  exceção aqui não se aplica e é reportada como ociosa
//   nao-instalado  caminho existe no template mas ainda não neste consumidor -> ociosa (o
//                  arquivo VAI ser instalado pelo overlay; a exceção não impede isso)
//   fora-do-template  caminho declarado que o template atual não tem -> ociosa
//   tombstone-preservado  caminho que o template REMOVEU e que existe no consumidor (tombstone) ->
//                  a exceção declarada barra a poda de órfãos (ver orphan-pruning); reportado uma
//                  vez só, na seção de tombstones, nunca duplicado como "ociosa"
function classifyExceptions(forge, files, exceptions, tombstoned) {
  const relSet = new Set(files.map(([rel]) => rel));
  const status = new Map();
  for (const [rel, exc] of exceptions.entries) {
    if (!relSet.has(rel)) {
      if (tombstoned && tombstoned.has(rel)) { status.set(rel, { status: 'tombstone-preservado', reason: exc.reason }); continue; }
      status.set(rel, { status: 'fora-do-template' });
      continue;
    }
    const srcAbs = files.find(([r]) => r === rel)[1];
    const newHash = sha256File(srcAbs);
    const dst = join(forge, rel);
    if (!existsSync(dst)) { status.set(rel, { status: 'nao-instalado' }); continue; }
    const dstHash = sha256File(dst);
    if (dstHash === newHash) { status.set(rel, { status: 'identica' }); continue; }
    if (isEnrichable(rel)) { status.set(rel, { status: 'enrichable' }); continue; }
    // Casamento por IGUALDADE ESTRITA, nunca por prefixo — igual ao parser de origem
    // (`check-machinery-drift.sh:321`: `[ "${exc_sha[$EXC_IDX]}" = "$sha" ]`). Uma versão anterior
    // comparava por prefixo achando que o parser de origem fazia o mesmo; não faz. Um sha declarado
    // com menos de 64 dígitos (sintaxe válida, >= 32 dígitos) nunca é igual ao sha de 64 dígitos do
    // template — cai sempre em EXPIRADA, e ainda assim preserva o arquivo (DH-1), nunca bloqueia.
    if (exc.sha === newHash) { status.set(rel, { status: 'viva', reason: exc.reason }); continue; }
    status.set(rel, { status: 'expirada', declared: exc.sha, atual: newHash });
  }
  return status;
}

// Nomeia, no relatório, quando o caminho declarado em machinery-exceptions.txt levou normalização
// de prefixo (normalizeExceptionPath) — nunca normaliza em silêncio: quem declarou
// './scripts/doctor.sh' vê a própria grafia ao lado da forma que o update de fato usou para casar
// contra o template.
function excRawNote(exceptions, rel) {
  const exc = exceptions.entries.get(rel);
  return exc && exc.raw ? ` (declarado como '${exc.raw}')` : '';
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

// Tombstones: paths de maquinaria (relativos a .forge/) que o template REMOVEU ou RENOMEOU entre
// versões — lidos de installer/removed-files.txt (versionado junto com o bin/template). O overlay
// aditivo nunca deletava, então um arquivo renomeado sobrevivia como órfão (ex.: commands/graph/
// build.md mantendo o slash command stale /forge:build após virar /forge:codegraph). A deleção é
// dirigida por ESTA lista curada — nunca por "tudo que não está no template", porque um consumidor
// pode legitimamente ter commands/agents/rules autorais sob .forge/ (a resolução via custom/ não é
// implementada hoje). Assim a remoção é cirúrgica e NUNCA apaga trabalho do consumidor. Invariante
// (imposta pelo gate w63): nenhum path aqui pode existir no template atual — senão o overlay o
// escreveria e a tombstone o apagaria em seguida.
function tombstonedPaths() {
  if (!existsSync(REMOVED_MANIFEST)) return [];
  return readFileSync(REMOVED_MANIFEST, 'utf8')
    .split('\n').map((l) => l.replace(/#.*$/, '').trim()).filter(Boolean);
}

// Tombstones que de fato existem no consumidor (candidatos reais a remoção neste update).
function orphansToPrune(forge) {
  return tombstonedPaths().filter((rel) => existsSync(join(forge, rel))).sort();
}

// Divide um forge.yaml em blocos por chave de topo (linha `chave:` na coluna 0). O bloco carrega a
// linha da chave + toda a continuação indentada/comentada até a próxima chave de topo.
function topLevelYamlBlocks(text) {
  const blocks = new Map();
  let key = null, buf = [];
  const flush = () => { if (key !== null) blocks.set(key, buf.join('\n')); };
  for (const line of text.split('\n')) {
    const m = /^([A-Za-z_][A-Za-z0-9_]*):/.exec(line);
    if (m) { flush(); key = m[1]; buf = [line]; }
    else if (key !== null) buf.push(line);
  }
  flush();
  return blocks;
}

// Chaves de topo do forge.yaml do template ausentes no do projeto (só seções inteiras novas, ex.:
// `autonomy:` de uma versão nova). Um bloco com QUALQUER placeholder UPPERCASE (`<PROJECT_*>`,
// `<INSTALLED_AT>`, …) não é mesclado — o update não conhece slug/nome para resolver, então não
// injeta token cru no YAML; entra em `skipped` para o chamador avisar (não some em silêncio).
function newForgeKeys(src, forge) {
  const dstPath = join(forge, 'forge.yaml');
  const srcPath = join(src, 'forge.yaml');
  if (!existsSync(dstPath) || !existsSync(srcPath)) return { blocks: new Map(), keys: [], skipped: [] };
  const dstKeys = new Set(topLevelYamlBlocks(readFileSync(dstPath, 'utf8')).keys());
  const srcBlocks = topLevelYamlBlocks(readFileSync(srcPath, 'utf8'));
  const keys = [], skipped = [];
  for (const key of srcBlocks.keys()) {
    if (dstKeys.has(key)) continue;
    if (/<[A-Z][A-Z0-9_]*>/.test(srcBlocks.get(key))) { skipped.push(key); continue; }
    keys.push(key);
  }
  return { blocks: srcBlocks, keys, skipped };
}

// Merge ADITIVO das chaves de topo novas do template para o forge.yaml do projeto: acrescenta os
// blocos inteiros que faltam, preservando byte-a-byte tudo que o projeto já tinha. NÃO toca chaves
// existentes nem sub-chaves (limite honesto: só seções de topo ausentes — o caso comum de feature
// nova). Retorna { added, skipped } — added mescladas, skipped puladas por placeholder (o chamador avisa).
// Blocos cujo valor do TEMPLATE é para repositório NOVO e seria hostil num repositório existente
// (issue #77). O comentário do bloco `secrets` no forge.yaml do template já documentava a regra —
// `block` é o modo de repositório novo ou já saneado, e um repositório existente "HERDA warn ao
// atualizar o harness, porque o gate não é opt-in e chegar travando o time no primeiro dia é como
// um gate vira --no-verify de hábito". O mecanismo que deveria produzir esse `warn` pela AUSÊNCIA
// do bloco era justamente o que criava o bloco, com `block` dentro.
//
// Medido em quatro consumidores reais: nenhum tinha o bloco antes, e num deles o gate acusa seis
// ocorrências pré-existentes — credenciais em `.env.example`, `docker-compose.yml`, um YAML de
// contrato, e um cabeçalho PEM num arquivo de teste. Hoje não bloqueiam; depois do upgrade o
// pre-commit passaria a reprovar assim que qualquer um desses arquivos fosse tocado, e o autor não
// fez nada errado nem sabe que a política mudou, porque a mudança veio embutida num upgrade de
// maquinaria.
const APPEND_SOFTEN = new Map([
  ['secrets', [[/^(\s*enforce:\s*)block\b/m, '$1warn']]],
]);

// #142: recurso do heavy-mutex resolvido pela MESMA lib e a MESMA precedência (env >
// heavy_mutex.resource do forge.yaml > default "forge-heavy-suite") que `heavy-run.sh` usa em
// produção — nunca uma reimplementação paralela em JS, que poderia divergir silenciosamente da
// lib (é exatamente o tipo de gêmeo-mentiroso que criou a partição da issue). Só RESOLVE, nunca
// adquire: `forge_heavy_mutex_path` não cria diretório de lock nenhum (mesma garantia de
// isolamento do gate w154 sobre `_fhm_resolve_root`) — chamável em qualquer ponto do update sem
// tocar a exclusão real da máquina.
//
// Devolve `{ resource, path }` no sucesso e `{ resource: null, path: null, reason }` em qualquer
// falha (lib ausente, raiz inutilizável — rc 69 do próprio `_fhm_resolve_root`, symlink recusado
// etc.): a linha informativa do update é best-effort e nunca pode derrubar a aplicação por causa
// dela, mas o chamador tem o MOTIVO para avisar em voz alta em vez de sumir a linha em silêncio
// (uma resolução que falha não pode produzir o mesmo "nada aconteceu"
// que uma chave inexistente).
//
// `resource` vem DIRETO da lib (`_fhm_resource`), nunca derivado de `basename(path)`: um recurso
// declarado com `/` (nome inválido, mas a lib não recusa) produziria um path com subdiretório, e
// `basename` devolveria só o último segmento — um nome resolvido diferente do que a lib realmente
// usa para nomear o lock. `forge_heavy_mutex_path` não muda a assinatura (continua imprimindo só
// `<path><TAB><proveniência>`, o formato que outros leitores da lib já esperam); esta função só
// pede o `resource` numa segunda chamada, na MESMA invocação de bash, para nunca divergir da
// resolução real de `path`.
// `opts.dryRun`: usado pela prévia de `--dry-run` para nunca criar o
// diretório-raiz do heavy-mutex. `forge_heavy_mutex_path` → `_fhm_resolve_root` faz `mkdir` quando
// a raiz DECLARADA (env ou `heavy_mutex.root` do forge.yaml) ainda não existe — comportamento
// correto na aplicação real, mas uma PRÉVIA que só deveria informar não pode ter esse efeito
// colateral no disco. Com `dryRun`, o script só resolve o `resource` (nunca cria nada) e, se a
// raiz declarada não existir, devolve o `resource` sem `path` e um motivo — nunca chama
// `forge_heavy_mutex_path` nesse caso, então o `mkdir` da lib nunca roda. Raiz não declarada
// (default `/tmp`) ou token `${TMPDIR:-/tmp}` nunca passam por `mkdir` na lib de qualquer forma
// (só checam e falham), então seguem pelo caminho normal mesmo em dry-run.
function resolveHeavyMutexPath(forge, target, opts = {}) {
  const lib = join(forge, 'scripts', 'lib', 'heavy-mutex.sh');
  if (!existsSync(lib)) return { resource: null, path: null, reason: 'lib heavy-mutex.sh ausente' };
  const script = opts.dryRun
    ? [
        '. "$0" || exit 1',
        'res="$(_fhm_resource)"',
        'root="${FORGE_HEAVY_MUTEX_ROOT:-}"',
        '[ -n "$root" ] || root="$(_fhm_yaml_root)"',
        'case "$root" in',
        '  ""|\'${TMPDIR:-/tmp}\') declroot="" ;;',
        '  /*) declroot="$root" ;;',
        '  *) declroot="" ;;',
        'esac',
        'if [ -n "$declroot" ] && [ ! -d "$declroot" ]; then',
        '  printf "%s\\t\\t%s\\n" "$res" "raiz declarada ($declroot) ainda não existe — dry-run não cria"',
        '  exit 0',
        'fi',
        'p="$(forge_heavy_mutex_path)" || exit $?',
        'printf "%s\\t%s\\t\\n" "$res" "$p"',
      ].join('\n')
    : '. "$0" && res="$(_fhm_resource)" && p="$(forge_heavy_mutex_path)" && printf "%s\\t%s\\n" "$res" "$p"';
  try {
    const out = execFileSync('bash', ['-c', script, lib], {
      cwd: target,
      env: { ...process.env, FORGE_ROOT: target },
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const [resource, path, reason] = out.trim().split('\t');
    if (!resource) return { resource: null, path: null, reason: reason || 'saída da lib incompleta' };
    if (!path) return { resource, path: null, reason: reason || 'raiz declarada ainda não existe' };
    return { resource, path };
  } catch (e) {
    const rc = e.status;
    const lastErrLine = String(e.stderr || '').trim().split('\n').filter(Boolean).pop() || '';
    const reason = rc != null ? `rc ${rc}${lastErrLine ? `: ${lastErrLine}` : ''}` : (lastErrLine || 'falha desconhecida ao invocar a lib');
    return { resource: null, path: null, reason };
  }
}

// Extrai o valor de `resource:` de um bloco `heavy_mutex:` (texto do TEMPLATE, como
// `newForgeKeys` devolve em `blocks.get('heavy_mutex')`) — usado só para nomear o que SERIA
// escrito quando a resolução real falha (WARN de resolução indeterminada) ou na prévia do
// `--dry-run`. Nunca lido do consumidor: o bloco do consumidor, quando existe, barra o merge
// inteiro antes de chegar aqui.
function templateHeavyMutexResource(blockText) {
  const m = /^[ \t]*resource:[ \t]*['"]?([^'"\n#]+?)['"]?[ \t]*(#.*)?$/m.exec(blockText || '');
  return m ? m[1].trim() : 'forge-heavy-suite';
}

function mergeNewForgeKeys(src, forge) {
  const { blocks, keys, skipped } = newForgeKeys(src, forge);
  const softened = [];
  if (keys.length) {
    const dstPath = join(forge, 'forge.yaml');
    const dstText = readFileSync(dstPath, 'utf8');
    let next = dstText.endsWith('\n') ? dstText : `${dstText}\n`;
    next += `${keys.map((k) => {
      let body = blocks.get(k).replace(/\n+$/, '');
      // ACRESCENTAR a um forge.yaml que já existia é upgrade, não init: o default hostil é
      // amaciado e o fato é REPORTADO. Um bloco que passa a bloquear algo que antes não bloqueava
      // não pode entrar em silêncio — hoje era preciso ler o YAML gerado para descobrir.
      for (const [re, rep] of (APPEND_SOFTEN.get(k) || [])) {
        if (re.test(body)) { body = body.replace(re, rep); softened.push(k); }
      }
      return body;
    }).join('\n')}\n`;
    writeFileSync(dstPath, next);
  }
  return { added: keys, skipped, softened };
}

async function updateHarness() {
  const target = resolve(vals.target || process.cwd());
  const forge = join(target, '.forge');
  // Dois diagnósticos diferentes por trás do mesmo exit 3 (REQ-FHT-037: nunca escreve neste
  // caminho, nos dois casos). `.forge/` ausente é "nunca instalado" — `init` é o remédio certo.
  // `.forge/` PRESENTE sem forge.yaml é instalação parcial, arquivo apagado, ou o dogfood do
  // próprio harness (LDG-0028) — `init` exigiria --force e faria backup+sobrescrita de specs/
  // baseline que podem existir ali, a ação errada quando só um arquivo sumiu. Nomear o artefato
  // que falta de verdade, sem prescrever a rota destrutiva.
  if (!existsSync(forge))
    fail(`.forge não encontrado em ${target} — use \`npx forge-harness init\` para instalar`, 3);
  if (!existsSync(join(forge, 'forge.yaml')))
    fail(`${target}/.forge existe mas forge.yaml não — instalação parcial, arquivo apagado, ou harness sem esse arquivo (ex.: dogfood). Não rode init (exigiria --force e sobrescreveria specs/baseline existentes) — restaure .forge/forge.yaml (do template ou do histórico do git) e rode update de novo`, 3);

  // Passo zero: recusa rodar de dentro de um worktree linkado. A maquinaria é versionada DENTRO da
  // árvore, então um update aplicado num worktree escreve `.forge/**` novo apenas naquela branch —
  // o tronco e todos os outros worktrees continuam com a versão antiga, e quem trabalha neles
  // recebe verde de gates que não estão rodando. Pior: como `core.hooksPath` vive no `.git/config`
  // COMUM, o update rodado do worktree reaponta os hooks de TODO o repositório para uma árvore que
  // é de uma branch só. Não há flag de escape: atualizar maquinaria de dentro de um worktree é
  // sempre a operação errada, e oferecer um `--allow-worktree` seria oferecer o defeito.
  // Compara caminhos CANÔNICOS: no macOS /tmp é symlink para /private/tmp e o git devolve o
  // caminho real, de modo que uma comparação textual acusaria worktree em todo repositório sob
  // /tmp. Foi o que aconteceu na primeira versão deste guard — e ele matava o gate w94 em
  // silêncio, sob `set -e`, sem imprimir motivo nenhum.
  const canon = (pth) => { try { return realpathSync(pth); } catch { return resolve(pth); } };
  const mainRoot = mainCheckoutOf(target);
  if (mainRoot && canon(mainRoot) !== canon(target)) {
    fail(`update rodado de dentro de um worktree linkado (${target}).\n` +
         `  A maquinaria é versionada na árvore: aplicá-la aqui atualizaria só esta branch, e o\n` +
         `  tronco mais os demais worktrees ficariam com a versão antiga — recebendo verde de gates\n` +
         `  que não estão rodando.\n` +
         `  Rode do checkout principal: (cd ${mainRoot} && npx forge-harness update)`, 4);
  }

  const src = vals.source ? resolve(vals.source) : TEMPLATE_FORGE;
  const version = pkgVersion();
  const files = machineryFiles(src);
  // Validado ANTES do dry-run e de qualquer escrita (backup incluso): arquivo malformado ou
  // ilegível para o processo inteiro, dry-run também.
  const exceptions = readMachineryExceptions(forge);
  // Tombstones PRESENTES no consumidor, calculado antes de qualquer escrita — nem o overlay nem o
  // backup tocam caminho tombstoned (invariante do template: tombstone nunca está no template
  // atual), então o mesmo conjunto vale aqui e no laço de poda mais abaixo.
  const tombstonedPresent = new Set(orphansToPrune(forge));
  const excStatusByRel = classifyExceptions(forge, files, exceptions, tombstonedPresent);

  // dry-run: lista o que mudaria (conteúdo diferente ou arquivo novo), sem escrever nada. Usa a
  // MESMA classificação de exceções que a aplicação real usa (ver classifyExceptions) — a prévia
  // não pode anunciar sobrescrita de arquivo que o update real preserva.
  if (flags.dryRun) {
    const changes = [];
    let driftDry = 0, driftDrySemLock = 0;
    const lockDry = readMachineryLock(forge);
    const historyDry = readMachineryHistory(src);
    for (const [rel, srcAbs] of files) {
      const dst = join(forge, rel);
      if (!existsSync(dst)) { changes.push(`+ ${rel}`); continue; }
      if (readFileSync(srcAbs, 'utf8') === readFileSync(dst, 'utf8')) continue;
      if (isEnrichable(rel)) {
        const custom = !(lockDry && lockDry.get(rel) === sha256File(dst));
        changes.push(custom ? `= ${rel} (preservado — customização local)` : `~ ${rel}`);
        continue;
      }
      const est = excStatusByRel.get(rel);
      if (est && est.status === 'viva') { changes.push(`= ${rel} (preservado — exceção declarada)${excRawNote(exceptions, rel)}`); continue; }
      if (est && est.status === 'expirada') { changes.push(`= ${rel} (preservado — EXCEÇÃO EXPIRADA: declarado ${est.declared}, template ${est.atual})${excRawNote(exceptions, rel)}`); continue; }
      const verdict = driftVerdict(rel, sha256File(dst), lockDry, historyDry, pendingShaOf(target, rel));
      if (verdict === 'lock') changes.push(`~ ${rel} (o template evoluiu — arquivo intocado localmente)`);
      else if (verdict === 'pendente') changes.push(`~ ${rel} (o template evoluiu — arquivo intocado, idêntico à versão pendente que o update anterior guardou)`);
      else if (verdict === 'historico') changes.push(`~ ${rel} (o template evoluiu — arquivo intocado, idêntico a uma versão publicada)`);
      else if (flags.overwriteDrift) changes.push(`~ ${rel} (sobrescrita não declarada — --overwrite-drift)`);
      else {
        changes.push(`= ${rel} (PRESERVADO (${DRIFT_LABEL[verdict]}) — versão nova do template iria para ${TEMPLATE_PENDING_REL}/${rel})`);
        driftDry++;
        if (isSemLock(verdict)) driftDrySemLock++;
      }
    }
    const fy = join(forge, 'forge.yaml');
    if (existsSync(fy) && !new RegExp(`template_version:\\s*"?${version}"?`).test(readFileSync(fy, 'utf8')))
      changes.push('~ forge.yaml (template_version)');
    for (const rel of orphansToPrune(forge)) {
      if (exceptions.entries.has(rel)) changes.push(`= ${rel} (tombstone pulado — exceção declarada)${excRawNote(exceptions, rel)}`);
      else changes.push(`- ${rel} (órfão — removido/renomeado no template)`);
    }
    const nk = newForgeKeys(src, forge);
    for (const key of nk.keys) {
      // #142 (LOW do review): a prévia também antecipa a identidade de lock que a aplicação real
      // vai anunciar — sem isso, `--dry-run` mostrava só "bloco novo" e o operador só descobria o
      // recurso resolvido depois de já ter aplicado.
      if (key === 'heavy_mutex') {
        const before = resolveHeavyMutexPath(forge, target, { dryRun: true });
        const depoisPrevisto = process.env.FORGE_HEAVY_MUTEX_RESOURCE || templateHeavyMutexResource(nk.blocks.get('heavy_mutex'));
        if (before && before.resource) {
          changes.push(before.resource === depoisPrevisto
            ? `~ forge.yaml (+ heavy_mutex: recurso previsto ${depoisPrevisto})`
            : `~ forge.yaml (+ heavy_mutex: recurso previsto ${before.resource} → ${depoisPrevisto})`);
        } else {
          changes.push(`~ forge.yaml (+ heavy_mutex: bloco novo — recurso previsto ${depoisPrevisto}${before && before.reason ? ` — antes não determinado (${before.reason})` : ''})`);
        }
        continue;
      }
      changes.push(`~ forge.yaml (+ ${key}: bloco novo)`);
    }
    for (const key of nk.skipped) changes.push(`! forge.yaml (${key}: seção nova exige preenchimento manual — não mesclada)`);
    console.log(`forge update — dry-run (${target})`);
    console.log(changes.length ? changes.sort().join('\n') : '(nada a atualizar — já na versão do template)');
    console.log(`\n${changes.length} mudança(s) de arquivo. Rode sem --dry-run para aplicar.`);
    console.log('(a aplicação também reconcilia adapters/plugin/hooksPath/.gitignore — não previstos acima)');
    if (driftDry) console.log(driftWarnLine(driftDry, driftDrySemLock, true, historyDry !== null));
    return;
  }

  const work = scanProductContent(forge);

  // backup por CÓPIA (o update edita in place; não move como o init --force). Pulável com --no-backup.
  // Exclui worktrees/ (working trees de git worktrees linkados — potencialmente enormes e com ponteiros
  // gitdir que quebram numa cópia) além do cruft do macOS.
  // `mostra` (destino do backup, para exibição) hoisted para fora do bloco: as linhas
  // `SOBRESCRITO (não declarado)` do overlay abaixo apontam para ele mesmo com --no-backup
  // (nesse caso, null — a mensagem por arquivo diz que não há backup).
  let mostra = null;
  if (!flags.noBackup) {
    // FORA da árvore de trabalho (issue #76). O backup vivia em `.forge.bak-N`, dentro do repo, e
    // todo gate que aceita `--path` e varre recursivamente passava a varrer também a CÓPIA — e a
    // reprovar por conteúdo que é duplicata dele mesmo. Medido num consumidor real: logo após o
    // update, `check-data-governance.sh --path .` acusava conflito de RLS; movendo o backup para
    // fora e sem mudar mais nada no mesmo commit, passava.
    //
    // O efeito chegava ao `pre-push`: o primeiro bloqueio depois do upgrade era um gate de
    // governança de dados apontando conflito, e a leitura natural do operador é que o upgrade
    // quebrou algo ou que existe um problema de conformidade real. A causa — o backup — não
    // aparecia em lugar nenhum da mensagem, e a instrução do próprio update é manter o backup até
    // validar: o caminho recomendado era o que produzia o falso positivo.
    //
    // `check-secrets.sh` era o caso mais desconfortável: um segredo já corrigido no original
    // continuava presente na cópia. E o backup também não era coberto pelo .gitignore gerenciado,
    // então num repositório que use `git add -A` ele era candidato a entrar num commit.
    //
    // `.git/` resolve tudo isso de uma vez: fora do universo de qualquer gate, fora do `git
    // status`, e continua ao lado do repositório para quem precisar restaurar.
    let gitDir = null;
    try {
      gitDir = resolve(target, execFileSync('git', ['-C', target, 'rev-parse', '--git-dir'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim());
    } catch { gitDir = null; }
    const bakRoot = gitDir ? join(gitDir, 'forge-backups') : target;
    let n = 1; while (existsSync(join(bakRoot, `forge-${n}`)) || (!gitDir && existsSync(`${forge}.bak-${n}`))) n++;
    const bakDir = gitDir ? join(bakRoot, `forge-${n}`) : `${forge}.bak-${n}`;
    mkdirSync(dirname(bakDir), { recursive: true });
    cpSync(forge, bakDir, {
      recursive: true,
      filter: (p) => basename(p) !== '.DS_Store' && !relative(forge, p).split(sep).includes('worktrees'),
    });
    mostra = gitDir ? relative(target, bakDir) : `.forge.bak-${n}`;
    console.log(`backup: .forge copiado para ${mostra}`);
    if (!gitDir) console.log('  (fora de um repositório git: o backup ficou DENTRO da árvore — remova-o antes de rodar gates com --path)');
  }

  // overlay aditivo: sobrescreve mesmos paths, adiciona novos, NUNCA deleta extras do projeto.
  // Em ENRICHABLE_DIRS a sobrescrita é condicionada ao lock de template (ver comentário da
  // constante — issue #16): customização local é preservada e reportada, nunca revertida.
  const oldLock = readMachineryLock(forge);
  const history = readMachineryHistory(src);

  // excStatusByRel já foi calculado antes do dry-run (classifyExceptions, acima) — "todo caminho
  // declarado aparece exatamente uma vez no relatório" vale porque É A MESMA classificação usada
  // pela prévia e pela aplicação real; não recalcula aqui.

  let written = 0;
  const preservedFiles = [];
  // Caminhos preservados por exceção declarada (viva ou expirada), fora de ENRICHABLE_DIRS —
  // somado a `preservedFiles` só no orphan-check de placeholders (ver abaixo). Mantido separado de
  // `preservedFiles` porque as duas listas têm reportagem própria (a seção de exceções, mais
  // abaixo, já nomeia cada uma) e misturá-las duplicaria a linha `preservados: N arquivo(s)`.
  const excPreservedFiles = [];
  const driftWarned = [];
  const overwrittenUndeclared = [];
  // Arquivo NEM enriquecível NEM coberto por exceção, que diverge do template novo, mas cujo hash
  // local bate com o `machinery.lock` da última aplicação: o consumidor nunca tocou o arquivo —
  // foi o TEMPLATE que evoluiu. Rotular isso como `SOBRESCRITO (não declarado)` seria tecnicamente
  // correto, mas, numa atualização real com dezenas de arquivos defasados, afogaria a única
  // sobrescrita local de verdade em dezenas de linhas idênticas de refresh rotineiro. Continua
  // nomeado (uma linha por arquivo, nunca em silêncio) — só que sob um rótulo (`ATUALIZADO`) que
  // não confunde "template mudou" com "sua customização foi revertida".
  const templateUpdated = [];
  // Idem, mas a prova de intocado veio da versão pendente que o update anterior guardou (reconciliação à mão) ou do histórico de versões publicadas.
  const templateUpdatedByPending = [];
  const templateUpdatedByHistory = [];
  // Deriva local preservada (ver TEMPLATE_PENDING_REL): trios [rel, srcAbs, veredito] — o srcAbs alimenta a cópia da versão pendente depois do laço, e o veredito ('deriva' ou 'sem-lock') escolhe o rótulo.
  const driftPreserved = [];
  for (const [rel, srcAbs] of files) {
    const dst = join(forge, rel);
    if (existsSync(dst)) {
      const dstHash = sha256File(dst);
      const newHash = sha256File(srcAbs);
      if (isEnrichable(rel) && dstHash !== newHash && !(oldLock && oldLock.get(rel) === dstHash)) {
        preservedFiles.push(rel);
        continue;
      }
      if (!isEnrichable(rel)) {
        const est = excStatusByRel.get(rel);
        // Exceção viva ou expirada preserva sempre (issue #131, DH-1): o updater deixa de ser
        // cego a `.forge/machinery-exceptions.txt` e para de reverter em silêncio a decisão
        // humana registrada ali, com ou sem `machinery.lock`.
        if (est && (est.status === 'viva' || est.status === 'expirada')) { excPreservedFiles.push(rel); continue; }
        if (dstHash !== newHash) {
          const verdict = driftVerdict(rel, dstHash, oldLock, history, pendingShaOf(target, rel));
          if (verdict === 'lock') {
            templateUpdated.push(rel);
          } else if (verdict === 'pendente') {
            templateUpdatedByPending.push(rel);
          } else if (verdict === 'historico') {
            templateUpdatedByHistory.push(rel);
          } else if (!flags.overwriteDrift) {
            // Nem enriquecível, nem coberto por exceção, nem provadamente intocado (pelo lock ou por uma versão publicada): é deriva local. Preserva o arquivo e guarda a versão nova do template como pendente — revisão da DH-1.
            driftPreserved.push([rel, srcAbs, verdict]);
            continue;
          } else {
            // --overwrite-drift: o operador aceitou o template sobre a deriva. Nomeado sempre, com o caminho do backup, porque o silêncio aqui é exatamente o defeito da #101.
            overwrittenUndeclared.push(rel);
            // maquinaria própria (scripts/commands/...): sobrescreve, mas fix local vira aviso — o
            // fluxo certo para fix em maquinaria é upstream no template; o backup cobre.
            if (oldLock && oldLock.has(rel) && dstHash !== oldLock.get(rel))
              driftWarned.push(rel);
          }
        }
      }
    }
    mkdirSync(dirname(dst), { recursive: true });
    cpSync(srcAbs, dst);
    written++;
  }
  console.log(`maquinaria: ${written} arquivo(s) de template aplicados (overlay aditivo)`);
  if (preservedFiles.length) {
    console.log(`preservados: ${preservedFiles.length} arquivo(s) com customização local NÃO sobrescritos:`);
    for (const rel of preservedFiles.sort()) console.log(`  = ${rel}`);
    console.log('  (se o template também mudou nesses paths, reconcilie à mão — diff contra .forge.bak-N)');
  }
  // O backup mudou para fora da árvore desde a #76 (`.git/forge-backups/`, não mais `.forge.bak-N`);
  // `mostra` já resolve o ponteiro real e é o mesmo usado pelas linhas ATUALIZADO/SOBRESCRITO abaixo.
  for (const rel of driftWarned.sort()) {
    const backupPointer = mostra ? join(mostra, rel) : '(sem backup — rodado com --no-backup)';
    console.log(`WARN: drift local em ${rel} sobrescrito pelo template (fix local em maquinaria? faça upstream; conteúdo anterior em ${backupPointer})`);
  }
  for (const rel of templateUpdated.sort()) {
    const backupPointer = mostra ? join(mostra, rel) : '(sem backup — rodado com --no-backup)';
    console.log(`ATUALIZADO: ${rel} — sem edição local (idêntico ao lock anterior); o template evoluiu; conteúdo anterior em ${backupPointer}`);
  }
  for (const rel of templateUpdatedByPending.sort()) {
    const backupPointer = mostra ? join(mostra, rel) : '(sem backup — rodado com --no-backup)';
    console.log(`ATUALIZADO: ${rel} — sem edição local (idêntico à versão pendente que o update anterior guardou); o template evoluiu; conteúdo anterior em ${backupPointer}`);
  }
  for (const rel of templateUpdatedByHistory.sort()) {
    const backupPointer = mostra ? join(mostra, rel) : '(sem backup — rodado com --no-backup)';
    console.log(`ATUALIZADO: ${rel} — sem edição local (idêntico a uma versão publicada do template); o template evoluiu; conteúdo anterior em ${backupPointer}`);
  }
  for (const rel of overwrittenUndeclared.sort()) {
    const backupPointer = mostra ? join(mostra, rel) : '(sem backup — rodado com --no-backup)';
    console.log(`SOBRESCRITO (não declarado): ${rel} — conteúdo anterior em ${backupPointer}`);
  }
  // Versões pendentes: reconstruídas a cada aplicação real, para refletir só a deriva que ESTE update preservou — um caminho reconciliado desde então (exceção declarada, arquivo igualado ao template, --overwrite-drift) sai do diretório sem limpeza manual.
  const pendingRoot = join(target, TEMPLATE_PENDING_REL);
  rmSync(pendingRoot, { recursive: true, force: true });
  driftPreserved.sort((a, b) => (a[0] < b[0] ? -1 : 1));
  for (const [rel, srcAbs, verdict] of driftPreserved) {
    const pend = join(pendingRoot, rel);
    mkdirSync(dirname(pend), { recursive: true });
    cpSync(srcAbs, pend);
    console.log(verdict === 'sem-lock'
      ? `PRESERVADO (sem lock para provar): ${rel} — o conteúdo local não é nenhuma versão publicada do template; versão nova do template em ${TEMPLATE_PENDING_REL}/${rel}`
      : verdict === 'sem-historico'
        ? `PRESERVADO (sem lock para provar): ${rel} — sem histórico de versões publicadas para provar; versão nova do template em ${TEMPLATE_PENDING_REL}/${rel}`
        : `PRESERVADO (deriva local): ${rel} — versão nova do template em ${TEMPLATE_PENDING_REL}/${rel}`);
  }

  // Relatório de exceções: todo caminho declarado em machinery-exceptions.txt aparece aqui
  // exatamente uma vez, na categoria que excStatusByRel já decidiu antes do laço. tombstone-
  // preservado é reportado só na seção de tombstones abaixo (senão o caminho apareceria duas
  // vezes — achado do review adversarial, MEDIUM).
  const excViva = [], excExpirada = [], excOciosa = [];
  for (const [rel, exc] of exceptions.entries) {
    const est = excStatusByRel.get(rel) || { status: 'fora-do-template' };
    if (est.status === 'tombstone-preservado') continue;
    if (est.status === 'viva') excViva.push({ rel, reason: exc.reason });
    else if (est.status === 'expirada') excExpirada.push({ rel, declared: est.declared, atual: est.atual });
    else if (est.status === 'identica') excOciosa.push({ rel, motivo: 'arquivo já idêntico ao template' });
    else if (est.status === 'enrichable') excOciosa.push({ rel, motivo: 'caminho enriquecível — a preservação de rules/agents/skills já cobre; exceção não se aplica' });
    else if (est.status === 'nao-instalado') excOciosa.push({ rel, motivo: 'arquivo ausente — será instalado do template; exceção não se aplica' });
    else excOciosa.push({ rel, motivo: 'caminho fora do template atual' });
  }
  if (excViva.length) {
    console.log(`exceções declaradas: ${excViva.length} arquivo(s) preservado(s) por divergência deliberada:`);
    for (const e of excViva.sort((a, b) => (a.rel < b.rel ? -1 : 1)))
      console.log(`  PRESERVADO (exceção declarada): ${e.rel} — razão: ${e.reason || '(sem razão declarada)'}${excRawNote(exceptions, e.rel)}`);
  }
  if (excExpirada.length) {
    console.log(`exceções expiradas: ${excExpirada.length} arquivo(s) com a declaração desatualizada (preservados mesmo assim):`);
    for (const e of excExpirada.sort((a, b) => (a.rel < b.rel ? -1 : 1)))
      console.log(`  EXCEÇÃO EXPIRADA: ${e.rel} — sha declarado ${e.declared}, sha do template novo ${e.atual}${excRawNote(exceptions, e.rel)}`);
  }
  if (excOciosa.length) {
    console.log(`exceções ociosas: ${excOciosa.length} declaração(ões) sem efeito nesta execução:`);
    for (const e of excOciosa.sort((a, b) => (a.rel < b.rel ? -1 : 1)))
      console.log(`  EXCEÇÃO OCIOSA: ${e.rel} — ${e.motivo}${excRawNote(exceptions, e.rel)}`);
  }
  writeMachineryLock(forge, files, version, vals.source ? src : '',
    new Map(driftPreserved.map(([rel]) => [rel, (oldLock && oldLock.get(rel)) || null])));

  // orphan-check defensivo: nenhum arquivo de maquinaria deve conter <PROJECT_*> após overlay.
  // Isento tanto `preservedFiles` (customização local em ENRICHABLE_DIRS) quanto
  // `excPreservedFiles` (exceção declarada viva ou expirada fora de ENRICHABLE_DIRS) — as duas
  // listas guardam conteúdo do CONSUMIDOR, nunca do template, e por isso não podem reprovar este
  // check. Achado MEDIUM do review adversarial: antes desta correção, só `preservedFiles` entrava
  // no conjunto isento; um arquivo preservado por exceção que contivesse `<PROJECT_*>` literal
  // (por exemplo, uma nota local com um placeholder nunca substituído de propósito) fazia o update
  // abortar com rc 1 DEPOIS de já ter escrito o overlay e o `machinery.lock`, culpando "o template"
  // por um conteúdo que era do próprio consumidor.
  const isTemplated = (f) => /\.(md|ya?ml)$/.test(f);
  const underTemplates = (f) => relative(forge, f).split(sep).includes('templates');
  // A deriva local preservada (revisão da DH-1) também é conteúdo do consumidor.
  const preservedSet = new Set([...preservedFiles, ...excPreservedFiles, ...driftPreserved.map(([rel]) => rel)]);
  const orphans = files
    .filter(([rel]) => !preservedSet.has(rel)) // conteúdo preservado é do consumidor, não do template
    .map(([rel]) => join(forge, rel))
    .filter((f) => isTemplated(f) && !underTemplates(f) && /<PROJECT_[A-Z_]*>/.test(readFileSync(f, 'utf8')));
  if (orphans.length) fail(`${orphans.length} arquivo(s) de maquinaria com placeholders <PROJECT_*> — template inválido?`, 1);

  // reconciliação de órfãos por TOMBSTONE: remove só os paths que o template sabidamente removeu/
  // renomeou (installer/removed-files.txt) e que existem no consumidor. Fecha o buraco do overlay
  // aditivo — ex.: /forge:build stale sobrevivia após o rename para /forge:codegraph — SEM apagar
  // commands/agents/rules autorais do consumidor (a deleção é curada, não "tudo fora do template").
  // Cada remoção é listada; o backup .forge.bak-N cobre.
  // A mesma invariante do overlay vale aqui (revisão do PR #17): tombstone em path ENRIQUECÍVEL
  // só deleta se o arquivo local é o template intocado (hash == lock da última aplicação);
  // customização local é mantida com aviso — remover diretiva de owner é decisão humana.
  // Achado do review adversarial (MEDIUM): exceção declarada para um caminho tombstoned era
  // relatada como "EXCEÇÃO OCIOSA — sem efeito" e, na sequência, o mesmo caminho era apagado pela
  // poda — a exceção não tinha NENHUM efeito real sobre o único ramo que poderia apagar o arquivo.
  // Exceção declarada barra a poda incondicionalmente (não depende de lock nem de sha — não há
  // "sha do template atual" para um caminho que o template já removeu).
  const stale = [];
  const keptTombstones = [];
  const keptExceptionTombstones = [];
  for (const rel of orphansToPrune(forge)) {
    if (exceptions.entries.has(rel)) {
      keptExceptionTombstones.push(rel);
      continue;
    }
    if (isEnrichable(rel) && !(oldLock && oldLock.get(rel) === sha256File(join(forge, rel)))) {
      keptTombstones.push(rel);
      continue;
    }
    stale.push(rel);
    rmSync(join(forge, rel), { force: true });
    // limpa o dir se ficou vazio (ex.: um grupo de comandos inteiro removido)
    const dir = dirname(join(forge, rel));
    try { if (existsSync(dir) && readdirSync(dir).length === 0) rmSync(dir, { recursive: true, force: true }); } catch { /* best-effort */ }
  }
  if (stale.length) {
    console.log(`órfãos: ${stale.length} arquivo(s) de maquinaria removido(s) (renomeados/removidos do template):`);
    for (const rel of stale) console.log(`  - ${rel}`);
  }
  for (const rel of keptTombstones.sort())
    console.log(`= ${rel} (tombstone pulado — customização local; o template removeu este path, remova à mão se não precisar mais)`);
  for (const rel of keptExceptionTombstones.sort()) {
    const exc = exceptions.entries.get(rel);
    console.log(`= ${rel} (tombstone pulado — exceção declarada: ${exc.reason || '(sem razão declarada)'})${excRawNote(exceptions, rel)}`);
  }

  // forge.yaml: template_version + merge aditivo de chaves de topo novas do template (ex.: autonomy:)
  if (bumpTemplateVersion(forge, version)) console.log(`forge.yaml: template_version -> ${version}`);
  // #142: recurso do heavy-mutex ANTES do merge — só quando o bloco está ausente e vai ser
  // mesclado (a única rota pela qual o update introduz o default do template em quem nunca
  // declarou nada; `resource`/`root`/`enabled` já declarados nunca são tocados, ver
  // `newForgeKeys`/DH-3). Resolvido ANTES de `mergeNewForgeKeys` escrever, contra o forge.yaml que
  // o consumidor tinha até aqui.
  //
  // Semântica de "antes" (achado LOW do review): o overlay de arquivos (mais acima, `cpSync` por
  // `rel`) já rodou quando chegamos aqui — `scripts/lib/heavy-mutex.sh` no disco já é a versão
  // NOVA do template. "Antes" significa "o forge.yaml antigo do consumidor, resolvido pela lib
  // nova", nunca "o que `heavy-run.sh` do consumidor resolvia com a lib que ele tinha até agora".
  // Se a precedência ou o default da lib mudarem entre versões, o "antes" anunciado pode não ser
  // o que o processo do consumidor via rodando minutos atrás — documentado aqui em vez de
  // reordenar a resolução para antes do overlay, que exigiria segurar uma cópia da lib antiga só
  // para este relatório informativo.
  const nkHm = newForgeKeys(src, forge);
  const hmWillMerge = nkHm.keys.includes('heavy_mutex');
  const hmBefore = hmWillMerge ? resolveHeavyMutexPath(forge, target) : null;
  const { added, skipped, softened } = mergeNewForgeKeys(src, forge);
  if (added.length) console.log(`forge.yaml: ${added.length} chave(s) de topo nova(s) do template mescladas: ${added.join(', ')}`);
  // Linha nominal (DH-3): o nome default do recurso é MANTIDO — quem já declarava outro caminho
  // de serialização (heavy_mutex.resource próprio) nunca passa por aqui, porque a chave já
  // existente barra o merge inteiro. Só o consumidor que nunca declarou nada ganha o bloco do
  // template, e a linha nomeia o que resolvia antes e o que resolve depois pela MESMA precedência
  // da lib (env > forge.yaml > default) — WARN quando os dois divergem, nunca em silêncio.
  //
  // Achado MEDIUM do review: a versão anterior só imprimia a linha quando as DUAS resoluções
  // tinham sucesso (`if (hmBefore && hmAfter)`) — uma resolução que falhasse (lib preservada por
  // machinery-exception sem `forge_heavy_mutex_path`, root inutilizável, bash ausente) fazia a
  // chave ser mesclada em SILÊNCIO TOTAL, exatamente o sintoma original da issue reproduzido pela
  // própria correção. Agora, qualquer falha em qualquer lado vira um WARN nomeando o motivo e o
  // `resource` que o bloco do template escreveu — nunca ausência de linha nenhuma.
  if (added.includes('heavy_mutex')) {
    const hmAfter = resolveHeavyMutexPath(forge, target);
    if (hmBefore && hmBefore.resource && hmAfter && hmAfter.resource) {
      const linha = `heavy_mutex: recurso resolvido ${hmBefore.resource} → ${hmAfter.resource} (lock ${hmAfter.path})`;
      console.log(hmBefore.resource === hmAfter.resource ? linha : `WARN: ${linha}`);
    } else {
      const motivo = (hmAfter && hmAfter.reason) || (hmBefore && hmBefore.reason) || 'motivo desconhecido';
      const resTemplate = templateHeavyMutexResource(nkHm.blocks.get('heavy_mutex'));
      console.log(`WARN: heavy_mutex: recurso resolvido não determinado (${motivo}) — bloco mesclado com resource: ${resTemplate}`);
    }
  }
  // Em voz alta: um bloco que muda POLÍTICA não pode entrar calado num upgrade de maquinaria.
  for (const key of (softened || [])) {
    console.log(`forge.yaml: '${key}:' entrou com enforce: warn (não block) — este repositório já existia e pode ter passivo.`);
    console.log(`  revise com: .forge/scripts/check-${key}.sh report   e troque para block quando estiver saneado`);
  }
  for (const key of skipped) console.log(`forge.yaml: seção nova '${key}:' NÃO mesclada (contém placeholder — exige preenchimento manual); revise o template`);

  // gitignore managed block — reconcilia (não é append-once; ver applyGitignoreBlock)
  applyGitignoreBlock(target);
  applyGitattributesBlock(target);

  wireHooksPath(target);

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
  if (!flags.noBackup) console.log('  backup fora da árvore, em .git/forge-backups/ (não é varrido por gate nem aparece em git status)');
  // Por último, para não se perder na rolagem do sync-adapters e do doctor.
  if (driftPreserved.length) console.log(driftWarnLine(driftPreserved.length, driftPreserved.filter(([, , v]) => isSemLock(v)).length, false, history !== null));
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

  // 4. .gitignore / .gitattributes managed blocks (reconciliam; ver applyManagedBlock)
  applyGitignoreBlock(target);
  applyGitattributesBlock(target);

  // 5. git hooks path (only when the target is a git repo)
  wireHooksPath(target);

  // 6. CI workflow (§20.2) — only for repos using the GitHub Actions layout
  if (existsSync(join(target, '.github')) || existsSync(join(target, '.git'))) {
    const wfDir = join(target, '.github', 'workflows');
    mkdirSync(wfDir, { recursive: true });
    const dst = join(wfDir, 'staging.yml');
    if (!existsSync(dst) && existsSync(STAGING_YML)) {
      cpSync(STAGING_YML, dst);
      console.log('ci: staging.yml instalado (roda só em push para staging)');
    }
    // red-first.yml — a execução de referência do replay roda num runner que o autor do PR não
    // controla (LDG-0004). Nunca sobrescreve: workflow existente é do projeto.
    const redDst = join(wfDir, 'red-first.yml');
    if (!existsSync(redDst) && existsSync(RED_FIRST_YML)) {
      cpSync(RED_FIRST_YML, redDst);
      console.log('ci: red-first.yml instalado (replay da evidência de Red em pull request)');
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
