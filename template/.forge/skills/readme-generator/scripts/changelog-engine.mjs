#!/usr/bin/env node
// changelog-engine.mjs — motor único de rascunho de CHANGELOG (Keep a Changelog, pt-BR).
//
// Consumidores: /forge:update-changelog (modo explícito e derivado) e o hook post-merge (modo
// --merge-range). Sem dependências externas de npm — só built-ins node:fs/node:path/node:child_process.
//
// Modos (mutuamente exclusivos):
//   --type <t> --description <d>   explícito: grava uma entrada literal na seção mapeada de <t>.
//   --subject "<msg>"               derivado de um único subject de Conventional Commits (squash).
//   --path <componente> [--base <ref>]
//                                   derivado: varre os commits do componente no intervalo
//                                   merge-base(<base>, HEAD)..HEAD — só o que a branch atual trouxe,
//                                   nunca o histórico inteiro (que já está em versões publicadas).
//                                   Sem --base, usa a primeira referência existente entre
//                                   origin/develop, develop, origin/main, main, origin/master, master.
//   --merge-range <A..B>            derivado do merge (chamado só pelo hook); nunca cria o arquivo.
//
// Deduplicação (todos os modos): uma entrada cujo texto já existe como item de lista dentro de
// [Unreleased] não é gravada de novo. O sufixo "(<hash>)" que o modo --merge-range acrescenta é
// ignorado na comparação, para que o comando (que grava sem hash, na branch) e o hook (que grava com
// hash, depois do merge) não registrem a mesma mudança duas vezes. No --merge-range o sufixo
// "(<hash>)" continua sendo também chave de idempotência (REQ-03).
//
// Mapeamento tipo->seção (pt-BR), alinhado a rules/conventions/conventional-commits.md:
//   feat -> Adicionado; fix -> Corrigido; perf -> Corrigido (DIV-01). Demais tipos não geram entrada.
//
// Terminador de linha: o arquivo é processado em LF e regravado com o terminador original (CRLF é
// preservado), para que as seções já publicadas continuem byte a byte idênticas.
//
// Uso: changelog-engine.mjs --root <dir> [--changelog <path-relativo-opcional>] <modo...>
import { readFileSync, writeFileSync, existsSync, renameSync } from 'node:fs';
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

const DEFAULT_BASES = ['origin/develop', 'develop', 'origin/main', 'main', 'origin/master', 'master'];

const DEFAULT_HEADER = `# Changelog

Todas as mudanças notáveis deste projeto são documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), e este projeto adere a [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Unreleased]
`;

const RELEASE_PLEASE_MSG = 'release-please-config.json presente — a entrada de release vem do título do PR, CHANGELOG.md intocado';

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

function fail(msg, code = 1) {
  console.error(`FAIL: ${msg}`);
  process.exit(code);
}

// Executa git e distingue "sem saída" (ok, out vazio) de "git falhou" (ok=false) — uma falha do git
// nunca pode virar "nada a registrar" por vacuidade.
function gitRun(root, args) {
  try {
    const out = execFileSync('git', ['-C', root, ...args], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
    return { ok: true, out };
  } catch (e) {
    const err = e && e.stderr ? String(e.stderr).trim() : String(e && e.message ? e.message : e);
    return { ok: false, out: '', err };
  }
}

function git(root, args) {
  return gitRun(root, args).out;
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

// Delimita o bloco [Unreleased] ({start, end}) ou null quando ausente.
function unreleasedBounds(md) {
  const start = md.search(/^##\s*\[Unreleased\]/m);
  if (start < 0) return null;
  const nextH2 = md.slice(start + 1).search(/^##\s+/m);
  const end = nextH2 >= 0 ? start + 1 + nextH2 : md.length;
  return { start, end };
}

// Texto normalizado de um item de lista, sem o sufixo de idempotência " (<hash>)".
function entryKey(text) {
  return text.replace(/\s+\([0-9a-f]{7,40}\)\s*$/, '').trim();
}

// Conjunto de chaves dos itens de lista já presentes em [Unreleased].
function unreleasedKeys(md) {
  const keys = new Set();
  const b = unreleasedBounds(md);
  if (!b) return keys;
  for (const line of md.slice(b.start, b.end).split('\n')) {
    const m = line.match(/^[-*]\s+(.+)$/);
    if (m) keys.add(entryKey(m[1]));
  }
  return keys;
}

// Insere `lines` sob "### <sectionHeader>" dentro do bloco [Unreleased], criando a subseção
// quando ausente. Devolve o markdown completo já atualizado. O texto das entradas é dado (subject
// de commit, descrição do usuário): a substituição usa função, nunca string, para que padrões como
// $&, $' ou $1 no texto não sejam interpretados por String.prototype.replace.
function insertIntoUnreleased(md, sectionHeader, lines) {
  if (!lines.length) return md;
  md = ensureUnreleased(md);
  const { start, end } = unreleasedBounds(md);
  let block = md.slice(start, end);
  const payload = lines.join('\n') + '\n';

  const reSec = new RegExp(`(^###\\s*${sectionHeader}\\s*\\n)`, 'm');
  if (reSec.test(block)) {
    block = block.replace(reSec, (header) => header + payload);
  } else {
    const trailingNext = end < md.length;
    block = block.replace(/\n*$/, '\n') + `\n### ${sectionHeader}\n${payload}` + (trailingNext ? '\n' : '');
  }
  return md.slice(0, start) + block + md.slice(end);
}

// Lê o CHANGELOG normalizado para LF e devolve o terminador original para a regravação.
function readChangelog(changelogPath, { allowCreate }) {
  if (existsSync(changelogPath)) {
    const raw = readFileSync(changelogPath, 'utf8');
    const eol = raw.includes('\r\n') ? '\r\n' : '\n';
    return { md: raw.replace(/\r\n/g, '\n'), eol };
  }
  if (!allowCreate) return null; // sinaliza ausência sem criar (modo merge-range)
  return { md: DEFAULT_HEADER, eol: '\n' };
}

// Escrita atômica (temporário + rename) com o terminador original.
function writeChangelog(changelogPath, md, eol) {
  const out = eol === '\r\n' ? md.replace(/\n/g, '\r\n') : md;
  const tmp = `${changelogPath}.tmp-${process.pid}`;
  writeFileSync(tmp, out);
  renameSync(tmp, changelogPath);
}

function hasReleasePlease(componentRoot) {
  return existsSync(join(componentRoot, 'release-please-config.json'));
}

// Filtra as entradas já presentes em [Unreleased] (e as repetidas no próprio lote) e devolve
// {section: lines} só com o que é novo, mais o total.
function dedupe(md, entriesBySection) {
  const seen = unreleasedKeys(md);
  const fresh = {};
  let total = 0;
  for (const [section, lines] of Object.entries(entriesBySection)) {
    for (const line of lines) {
      const key = entryKey(line.replace(/^[-*]\s+/, ''));
      if (seen.has(key)) continue;
      seen.add(key);
      (fresh[section] = fresh[section] || []).push(line);
      total++;
    }
  }
  return { fresh, total };
}

function applyEntries(changelogPath, entriesBySection, { allowCreate }) {
  const doc = readChangelog(changelogPath, { allowCreate });
  if (!doc) return 0;
  const { fresh, total } = dedupe(doc.md, entriesBySection);
  if (total === 0) return 0;
  let md = doc.md;
  for (const [section, lines] of Object.entries(fresh)) {
    md = insertIntoUnreleased(md, section, lines);
  }
  writeChangelog(changelogPath, md, doc.eol);
  return total;
}

function runExplicit(args) {
  const root = args.root || '.';
  const changelogRel = args.changelog || 'CHANGELOG.md';
  const changelogPath = join(root, changelogRel);

  if (hasReleasePlease(root)) fail(RELEASE_PLEASE_MSG, 2);

  const type = String(args.type || '').toLowerCase();
  const sectionHeader = SECTION_HEADERS[type];
  if (!sectionHeader) {
    fail(`tipo '${args.type}' inválido (use: ${Object.keys(SECTION_HEADERS).join(', ')})`, 2);
  }
  const description = args.description;
  if (!description || typeof description !== 'string') {
    fail('--description obrigatória no modo explícito', 2);
  }

  const n = applyEntries(changelogPath, { [sectionHeader]: [`- ${description}`] }, { allowCreate: true });
  console.log(n
    ? `changelog: entrada adicionada em ### ${sectionHeader} (modo explícito)`
    : `changelog: entrada já presente em [Unreleased] — nada a registrar (modo explícito)`);
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

  if (hasReleasePlease(root)) fail(RELEASE_PLEASE_MSG, 2);

  const entry = deriveFromSubject(String(args.subject === true ? '' : args.subject || ''));
  if (!entry) {
    console.log('changelog: subject não elegível (tipo sem seção mapeada) — nada a registrar');
    process.exit(0);
  }

  const n = applyEntries(changelogPath, { [entry.section]: [entry.line] }, { allowCreate: true });
  console.log(n
    ? `changelog: entrada derivada adicionada em ### ${entry.section} (modo --subject)`
    : 'changelog: entrada já presente em [Unreleased] — nada a registrar (modo --subject)');
  process.exit(0);
}

function resolveBase(root, explicitBase) {
  if (explicitBase && explicitBase !== true) {
    if (String(explicitBase).startsWith('-')) fail(`--base '${explicitBase}' inválida`, 2);
    const r = gitRun(root, ['rev-parse', '-q', '--verify', `${explicitBase}^{commit}`]);
    if (!r.ok || !r.out) fail(`--base '${explicitBase}' não resolve para um commit`, 2);
    return explicitBase;
  }
  for (const ref of DEFAULT_BASES) {
    const r = gitRun(root, ['rev-parse', '-q', '--verify', `${ref}^{commit}`]);
    if (r.ok && r.out) return ref;
  }
  fail(`nenhuma base encontrada (${DEFAULT_BASES.join(', ')}) — informe --base <ref>`, 2);
  return null;
}

function runDerivedPath(args) {
  const root = args.root || '.';
  const changelogRel = args.changelog || 'CHANGELOG.md';
  const changelogPath = join(root, changelogRel);
  const componentPath = args.path;

  if (typeof componentPath !== 'string' || !componentPath) {
    fail('--path exige o caminho do componente', 2);
  }
  const absComponent = join(root, componentPath);
  if (!existsSync(absComponent)) {
    fail(`componente '${componentPath}' não existe`, 2);
  }

  if (hasReleasePlease(absComponent) || hasReleasePlease(root)) fail(RELEASE_PLEASE_MSG, 2);

  const inRepo = gitRun(root, ['rev-parse', '--is-inside-work-tree']);
  if (!inRepo.ok || inRepo.out !== 'true') {
    fail(`'${root}' não é um repositório git — impossível derivar commits do componente (${inRepo.err || 'sem detalhe'})`, 2);
  }
  const base = resolveBase(root, args.base);
  const mb = gitRun(root, ['merge-base', base, 'HEAD']);
  if (!mb.ok || !mb.out) fail(`merge-base entre '${base}' e HEAD não encontrado (${mb.err || 'sem detalhe'})`, 2);

  const log = gitRun(root, ['log', '--no-merges', '--format=%s', `${mb.out}..HEAD`, '--', componentPath]);
  if (!log.ok) fail(`git log falhou ao varrer '${componentPath}': ${log.err}`, 2);

  const entriesBySection = {};
  for (const subject of log.out ? log.out.split('\n') : []) {
    if (!subject) continue;
    const entry = deriveFromSubject(subject);
    if (!entry) continue;
    (entriesBySection[entry.section] = entriesBySection[entry.section] || []).push(entry.line);
  }

  const n = Object.keys(entriesBySection).length
    ? applyEntries(changelogPath, entriesBySection, { allowCreate: true })
    : 0;
  console.log(n
    ? `changelog: ${n} entrada(s) derivada(s) do componente '${componentPath}' (desde ${base}) adicionada(s)`
    : `changelog: nenhum commit elegível novo em '${componentPath}' desde ${base} — nada a registrar`);
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

  const log = gitRun(root, ['log', '--no-merges', '--format=%h%x1f%s', '--end-of-options', range]);
  if (!log.ok) fail(`git log falhou para o intervalo '${range}': ${log.err}`, 1);
  if (!log.out) process.exit(0);

  const { md } = readChangelog(changelogPath, { allowCreate: false });
  const entriesBySection = {};
  for (const row of log.out.split('\n')) {
    const [hash, subject] = row.split('\x1f');
    if (!hash || !subject) continue;
    if (md.includes(`(${hash})`)) continue; // idempotência: já registrado
    const entry = deriveFromSubject(subject);
    if (!entry) continue; // DIV-02: refactor/revert/chore/... não geram entrada
    (entriesBySection[entry.section] = entriesBySection[entry.section] || []).push(`${entry.line} (${hash})`);
  }

  const total = applyEntries(changelogPath, entriesBySection, { allowCreate: false });
  if (total === 0) process.exit(0);
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
