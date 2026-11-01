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
//                                   Sem --base, usa, entre origin/develop, develop, origin/main,
//                                   main, origin/master e master, a de merge-base mais próximo.
//   --merge-range <A..B>            derivado do merge (chamado só pelo hook); nunca cria o arquivo.
//
// Deduplicação, sempre por seção + texto dentro de [Unreleased]:
//   - modos do comando (explícito, --subject, --path): uma entrada já presente na mesma seção, com
//     ou sem o sufixo "(<hash>)" do hook, não é gravada de novo;
//   - --merge-range (hook): a chave por commit continua sendo o hash (REQ-03 — dois commits
//     distintos com o mesmo subject geram duas entradas); além disso, o commit é pulado quando a
//     mesma seção já tem a entrada SEM hash, gravada pelo comando na branch, para que comando e hook
//     não registrem a mesma mudança duas vezes quando o texto coincide.
//
// Mapeamento tipo->seção (pt-BR), alinhado a rules/conventions/conventional-commits.md:
//   feat -> Adicionado; fix -> Corrigido; perf -> Corrigido (DIV-01). Demais tipos não geram entrada.
//
// Terminador de linha: o arquivo é processado em LF e regravado com o terminador original (CRLF é
// preservado), para que as seções já publicadas continuem byte a byte idênticas.
//
// Requer git ≥ 2.24 (usa --end-of-options no git log).
//
// Uso: changelog-engine.mjs --root <dir> [--changelog <path-relativo-opcional>] <modo...>
import { readFileSync, writeFileSync, existsSync, renameSync, realpathSync, statSync, chmodSync, unlinkSync } from 'node:fs';
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
    // err = só o stderr do git: vazio quando o git sai ≠ 0 sem diagnóstico (ex.: rev-parse -q
    // --verify de uma referência inexistente); o erro de spawn (git ausente) entra como texto.
    const err = e && e.stderr ? String(e.stderr).trim() : (e && e.code === 'ENOENT' ? String(e.message) : '');
    return { ok: false, out: '', err };
  }
}

const UNRELEASED_RE = /^##\s*\[Unreleased\]/im;

function hasUnreleased(md) {
  return UNRELEASED_RE.test(md);
}

function ensureUnreleased(md) {
  if (hasUnreleased(md)) return md;
  const firstH2 = md.search(/^##\s+/m);
  const insertAt = firstH2 >= 0 ? firstH2 : md.length;
  return md.slice(0, insertAt) + '## [Unreleased]\n\n' + md.slice(insertAt);
}

// Delimita o bloco [Unreleased] ({start, end}) ou null quando ausente.
function unreleasedBounds(md) {
  const start = md.search(UNRELEASED_RE);
  if (start < 0) return null;
  const nextH2 = md.slice(start + 1).search(/^##\s+/m);
  const end = nextH2 >= 0 ? start + 1 + nextH2 : md.length;
  return { start, end };
}

// Sufixo de idempotência " (<hash>)" gravado pelo --merge-range: hash abreviado hexadecimal com ao
// menos uma letra, para não confundir com um número entre parênteses no texto ("lote (2024999)").
const HASH_SUFFIX_RE = /\s+\((?=[0-9a-f]*[a-f])[0-9a-f]{7,40}\)\s*$/;

function splitEntry(text) {
  const hashed = HASH_SUFFIX_RE.test(text);
  return { text: text.replace(HASH_SUFFIX_RE, '').trim(), hashed };
}

// Chaves "<seção>|<texto>" dos itens de lista já presentes em [Unreleased]: `all` (com ou sem
// hash) e `unhashed` (só as gravadas sem hash, isto é, pelo comando).
function unreleasedKeys(md) {
  const all = new Set();
  const unhashed = new Set();
  const b = unreleasedBounds(md);
  if (!b) return { all, unhashed };
  let section = '';
  for (const line of md.slice(b.start, b.end).split('\n')) {
    const h3 = line.match(/^###\s+(.+?)\s*$/);
    if (h3) { section = h3[1]; continue; }
    const m = line.match(/^[-*]\s+(.+)$/);
    if (!m) continue;
    const { text, hashed } = splitEntry(m[1]);
    all.add(`${section}|${text}`);
    if (!hashed) unhashed.add(`${section}|${text}`);
  }
  return { all, unhashed };
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

// Escrita atômica (temporário + rename) com o terminador original. Grava no alvo real (um
// CHANGELOG.md symlink continua symlink e o alvo recebe a entrada) e preserva o modo do arquivo.
function writeChangelog(changelogPath, md, eol) {
  const out = eol === '\r\n' ? md.replace(/\n/g, '\r\n') : md;
  const target = existsSync(changelogPath) ? realpathSync(changelogPath) : changelogPath;
  const mode = existsSync(target) ? statSync(target).mode & 0o7777 : null;
  const tmp = `${target}.tmp-${process.pid}`;
  try {
    writeFileSync(tmp, out);
    if (mode !== null) chmodSync(tmp, mode);
    renameSync(tmp, target);
  } catch (e) {
    try { if (existsSync(tmp)) unlinkSync(tmp); } catch { /* limpeza best-effort */ }
    fail(`escrita de '${changelogPath}' falhou: ${e && e.message ? e.message : e}`, 1);
  }
}

function hasReleasePlease(componentRoot) {
  return existsSync(join(componentRoot, 'release-please-config.json'));
}

// Filtra as entradas já presentes em [Unreleased] e devolve {section: lines} só com o que é novo,
// mais o total. `hashed` = lote do --merge-range (ver o cabeçalho: lá a chave por commit é o hash,
// e o texto só é comparado com entradas sem hash).
function dedupe(md, entriesBySection, { hashed }) {
  const { all, unhashed } = unreleasedKeys(md);
  const seen = hashed ? unhashed : all;
  const fresh = {};
  let total = 0;
  for (const [section, lines] of Object.entries(entriesBySection)) {
    for (const line of lines) {
      const key = `${section}|${splitEntry(line.replace(/^[-*]\s+/, '')).text}`;
      if (seen.has(key)) continue;
      if (!hashed) seen.add(key);
      (fresh[section] = fresh[section] || []).push(line);
      total++;
    }
  }
  return { fresh, total };
}

function applyEntries(changelogPath, entriesBySection, { allowCreate, hashed = false }) {
  const doc = readChangelog(changelogPath, { allowCreate });
  if (!doc) return 0;
  const { fresh, total } = dedupe(doc.md, entriesBySection, { hashed });
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
  // Entre as bases existentes, a de merge-base mais próximo de HEAD (menos commits no intervalo):
  // uma develop parada há meses não pode arrastar para [Unreleased] o que já saiu por main.
  let best = null;
  for (const ref of DEFAULT_BASES) {
    const r = gitRun(root, ['rev-parse', '-q', '--verify', `${ref}^{commit}`]);
    if (!r.ok || !r.out) continue;
    const mb = gitRun(root, ['merge-base', ref, 'HEAD']);
    if (!mb.ok || !mb.out) continue;
    const n = gitRun(root, ['rev-list', '--count', `${mb.out}..HEAD`]);
    const count = n.ok ? Number(n.out) : Infinity;
    if (!best || count < best.count) best = { ref, count };
  }
  if (!best) fail(`nenhuma base encontrada (${DEFAULT_BASES.join(', ')}) — informe --base <ref>`, 2);
  return best.ref;
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
    // -q --verify: "HEAD não é merge" sai rc 1 sem stderr (no-op legítimo); qualquer outra falha
    // (fora de repositório, .git ilegível) tem stderr e não pode sair como sucesso.
    const p2 = gitRun(root, ['rev-parse', '-q', '--verify', 'HEAD^2']);
    if (!p2.ok && p2.err) fail(`não foi possível ler HEAD^2 em '${root}': ${p2.err}`, 1);
    if (!p2.ok || !p2.out) process.exit(0); // no-op: HEAD não é merge
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

  const total = applyEntries(changelogPath, entriesBySection, { allowCreate: false, hashed: true });
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
