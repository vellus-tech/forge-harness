#!/usr/bin/env node
// changelog-engine.mjs — motor único de rascunho de CHANGELOG (Keep a Changelog, pt-BR).
//
// Consumidores: /forge:update-changelog (modo explícito e derivado) e o hook post-merge (modo
// --merge-range). Sem dependências externas de npm — só built-ins node:fs/node:path/node:child_process.
//
// Modos (mutuamente exclusivos):
//   --type <t> --description <d>   explícito: grava uma entrada literal na seção mapeada de <t>.
//   --subject "<msg>"               derivado de um único subject de Conventional Commits (squash).
//   --path <componente>             derivado: varre o intervalo de commits do componente.
//   --merge-range <A..B>            derivado do merge (chamado só pelo hook); nunca cria o arquivo.
//
// Mapeamento tipo->secao (pt-BR), alinhado a rules/conventions/conventional-commits.md:
//   feat -> Adicionado; fix -> Corrigido; perf -> Corrigido (DIV-01). Demais tipos não geram entrada.
//
// Uso: changelog-engine.mjs --root <dir> [--changelog <path-relativo-opcional>] <modo...>
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';

const SECTION_HEADERS = {
  added: 'Adicionado',
  changed: 'Alterado',
  deprecated: 'Depreciado',
  removed: 'Removido',
  fixed: 'Corrigido',
  security: 'Segurança',
};

// Conventional Commits -> seção pt-BR. Só feat/fix/perf geram entrada (DIV-02): refactor/revert/
// chore/docs/style/test/build/ci ficam de fora deliberadamente.
const CC_SECTION = { feat: 'Adicionado', fix: 'Corrigido', perf: 'Corrigido' };
const CC_RE = /^(\w+)(?:\(([^)]*)\))?(!)?:\s*(.+)$/;

const DEFAULT_HEADER = `# Changelog

Todas as mudanças notáveis deste projeto são documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e este projeto adere a [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Unreleased]
`;

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith('--')) {
        out[key] = true;
      } else {
        out[key] = next;
        i++;
      }
    } else {
      out._.push(a);
    }
  }
  return out;
}

function git(root, args) {
  try {
    return execFileSync('git', ['-C', root, ...args], { encoding: 'utf8' }).trim();
  } catch {
    return '';
  }
}

function hasUnreleased(md) {
  return /^##\s*\[Unreleased\]/m.test(md);
}

function ensureUnreleased(md) {
  if (hasUnreleased(md)) return md;
  const firstH2 = md.search(/^##\s+/m);
  const insertAt = firstH2 >= 0 ? firstH2 : md.length;
  return md.slice(0, insertAt) + '## [Unreleased]\n\n' + md.slice(insertAt);
}

// Insere `lines` sob "### <sectionHeader>" dentro do bloco [Unreleased], criando a subseção
// quando ausente. Devolve o markdown completo já atualizado.
function insertIntoUnreleased(md, sectionHeader, lines) {
  if (!lines.length) return md;
  md = ensureUnreleased(md);
  const unrelStart = md.search(/^##\s*\[Unreleased\]/m);
  const after = md.slice(unrelStart);
  const nextH2 = after.slice(1).search(/^##\s+/m);
  const blockEnd = nextH2 >= 0 ? unrelStart + 1 + nextH2 : md.length;
  let block = md.slice(unrelStart, blockEnd);

  const reSec = new RegExp(`(^###\\s*${sectionHeader}\\s*\\n)`, 'm');
  if (reSec.test(block)) {
    block = block.replace(reSec, `$1${lines.join('\n')}\n`);
  } else {
    block = block.replace(/\n*$/, '\n') + `\n### ${sectionHeader}\n${lines.join('\n')}\n`;
  }
  return md.slice(0, unrelStart) + block + md.slice(blockEnd);
}

function readOrCreate(changelogPath, { allowCreate }) {
  if (existsSync(changelogPath)) {
    return readFileSync(changelogPath, 'utf8');
  }
  if (!allowCreate) return null; // sinaliza ausência sem criar (modo merge-range)
  return DEFAULT_HEADER;
}

function hasReleasePlease(componentRoot) {
  return existsSync(join(componentRoot, 'release-please-config.json'));
}

function fail(msg, code = 1) {
  console.error(`FAIL: ${msg}`);
  process.exit(code);
}

function runExplicit(args) {
  const root = args.root || '.';
  const changelogRel = args.changelog || 'CHANGELOG.md';
  const changelogPath = join(root, changelogRel);

  if (hasReleasePlease(root)) {
    console.log('FAIL: release-please-config.json presente — a entrada de release vem do titulo do PR, CHANGELOG.md intocado');
    process.exit(2);
  }

  const type = String(args.type || '').toLowerCase();
  const sectionHeader = SECTION_HEADERS[type];
  if (!sectionHeader) {
    fail(`tipo '${args.type}' invalido (use: ${Object.keys(SECTION_HEADERS).join(', ')})`, 2);
  }
  const description = args.description;
  if (!description || typeof description !== 'string') {
    fail('--description obrigatoria no modo explicito', 2);
  }

  let md = readOrCreate(changelogPath, { allowCreate: true });
  md = insertIntoUnreleased(md, sectionHeader, [`- ${description}`]);
  writeFileSync(changelogPath, md);
  console.log(`changelog: entrada adicionada em ### ${sectionHeader} (modo explicito)`);
  process.exit(0);
}

function deriveFromSubject(subject) {
  const m = subject.match(CC_RE);
  if (!m) return null;
  const type = m[1].toLowerCase();
  const section = CC_SECTION[type];
  if (!section) return null;
  const breaking = m[3] === '!' ? ' **[BREAKING]**' : '';
  return { section, line: `- ${m[4]}${breaking}` };
}

function runDerivedSubject(args) {
  const root = args.root || '.';
  const changelogRel = args.changelog || 'CHANGELOG.md';
  const changelogPath = join(root, changelogRel);

  if (hasReleasePlease(root)) {
    console.log('FAIL: release-please-config.json presente — a entrada de release vem do titulo do PR, CHANGELOG.md intocado');
    process.exit(2);
  }

  const entry = deriveFromSubject(String(args.subject || ''));
  if (!entry) {
    console.log('changelog: subject nao elegivel (tipo sem secao mapeada) — nada a registrar');
    process.exit(0);
  }

  let md = readOrCreate(changelogPath, { allowCreate: true });
  md = insertIntoUnreleased(md, entry.section, [entry.line]);
  writeFileSync(changelogPath, md);
  console.log(`changelog: entrada derivada adicionada em ### ${entry.section} (modo --subject)`);
  process.exit(0);
}

function runDerivedPath(args) {
  const root = args.root || '.';
  const changelogRel = args.changelog || 'CHANGELOG.md';
  const changelogPath = join(root, changelogRel);
  const componentPath = args.path;

  const absComponent = join(root, componentPath);
  if (!existsSync(absComponent)) {
    fail(`componente '${componentPath}' nao existe`, 2);
  }

  if (hasReleasePlease(absComponent) || hasReleasePlease(root)) {
    console.log('FAIL: release-please-config.json presente — a entrada de release vem do titulo do PR, CHANGELOG.md intocado');
    process.exit(2);
  }

  const raw = git(root, ['log', '--no-merges', `--format=%s`, '--', componentPath]);
  const entriesBySection = {};
  if (raw) {
    for (const subject of raw.split('\n')) {
      if (!subject) continue;
      const entry = deriveFromSubject(subject);
      if (!entry) continue;
      entriesBySection[entry.section] = entriesBySection[entry.section] || [];
      entriesBySection[entry.section].push(entry.line);
    }
  }

  const hadAny = Object.keys(entriesBySection).length > 0;
  let md = readOrCreate(changelogPath, { allowCreate: true });
  for (const [section, lines] of Object.entries(entriesBySection)) {
    md = insertIntoUnreleased(md, section, lines);
  }
  writeFileSync(changelogPath, md);
  console.log(hadAny
    ? `changelog: entradas derivadas do componente '${componentPath}' adicionadas`
    : `changelog: nenhum commit elegivel em '${componentPath}' — nada a registrar`);
  process.exit(0);
}

function runMergeRange(args) {
  const root = args.root || '.';
  const changelogRel = args.changelog || 'CHANGELOG.md';
  const changelogPath = join(root, changelogRel);

  // REQ-10b: release-please presente na raiz -> no-op informativo, nunca erro.
  if (hasReleasePlease(root)) {
    console.log('changelog: release-please-config.json presente na raiz — no-op (post-merge)');
    process.exit(0);
  }

  // Modo --merge-range NUNCA cria o CHANGELOG ausente (REQ-02/REQ-14, mutuamente exclusivo com
  // os modos explícito/derivado por chamada).
  if (!existsSync(changelogPath)) {
    process.exit(0);
  }

  let range = args['merge-range'];
  if (range === true || !range) {
    const p2 = git(root, ['rev-parse', '-q', '--verify', 'HEAD^2']);
    if (!p2) process.exit(0); // no-op: HEAD não é merge
    range = 'HEAD^1..HEAD^2';
  }

  const raw = git(root, ['log', '--no-merges', '--format=%h%x1f%s', range]);
  if (!raw) process.exit(0);

  let md = readFileSync(changelogPath, 'utf8');
  const entriesBySection = {};
  for (const row of raw.split('\n')) {
    const [hash, subject] = row.split('\x1f');
    if (!hash || !subject) continue;
    if (md.includes(`(${hash})`)) continue; // idempotência: já registrado
    const m = subject.match(CC_RE);
    if (!m) continue;
    const section = CC_SECTION[m[1].toLowerCase()];
    if (!section) continue; // DIV-02: refactor/revert/chore/... não geram entrada
    const breaking = m[3] === '!' ? ' **[BREAKING]**' : '';
    entriesBySection[section] = entriesBySection[section] || [];
    entriesBySection[section].push(`- ${m[4]}${breaking} (${hash})`);
  }

  const total = Object.values(entriesBySection).reduce((n, a) => n + a.length, 0);
  if (total === 0) process.exit(0);

  for (const [section, lines] of Object.entries(entriesBySection)) {
    md = insertIntoUnreleased(md, section, lines);
  }
  writeFileSync(changelogPath, md);
  console.log(`changelog: ${total} entrada(s) adicionada(s) a [Unreleased] no CHANGELOG.md (commit pendente)`);
  process.exit(0);
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.type !== undefined || args.description !== undefined) {
    return runExplicit(args);
  }
  if (args.subject !== undefined) {
    return runDerivedSubject(args);
  }
  if (args.path !== undefined) {
    return runDerivedPath(args);
  }
  if (args['merge-range'] !== undefined) {
    return runMergeRange(args);
  }
  fail('nenhum modo reconhecido (use --type/--description, --subject, --path ou --merge-range)', 2);
}

main();
