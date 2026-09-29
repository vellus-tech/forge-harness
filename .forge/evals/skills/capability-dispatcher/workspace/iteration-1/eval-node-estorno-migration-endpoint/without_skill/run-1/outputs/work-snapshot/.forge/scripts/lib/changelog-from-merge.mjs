#!/usr/bin/env node
// changelog-from-merge — realiza a parte "changelog" do hook post-merge (§20.4).
// Após um merge, acumula no CHANGELOG.md RAIZ (formato Keep a Changelog, seção
// [Unreleased]) as mudanças dos commits convencionais introduzidos pelo branch
// mergeado. Determinista e idempotente (pula commits cujo short-hash já consta).
//
// No-op seguro quando: não há CHANGELOG.md na raiz, ou HEAD não é um merge, ou o
// branch mergeado não tem commits convencionais elegíveis. Nunca commita nada —
// apenas edita o arquivo e informa que há mudança pendente de commit.
//
// Uso: changelog-from-merge.mjs <repo-root> [--range A..B]
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';

const root = process.argv[2] || '.';
const rangeArg = process.argv.indexOf('--range');
const changelog = join(root, 'CHANGELOG.md');

const git = (args) => {
  try { return execFileSync('git', ['-C', root, ...args], { encoding: 'utf8' }).trim(); }
  catch { return ''; }
};

if (!existsSync(changelog)) { process.exit(0); } // no-op: sem changelog raiz

// range: commits do branch mergeado (segundo pai .. ) que não estão no primeiro pai.
let range = rangeArg >= 0 ? process.argv[rangeArg + 1] : null;
if (!range) {
  const p2 = git(['rev-parse', '-q', '--verify', 'HEAD^2']);
  if (!p2) process.exit(0); // no-op: HEAD não é merge
  range = 'HEAD^1..HEAD^2';
}

const raw = git(['log', '--no-merges', '--format=%h%x1f%s', range]);
if (!raw) process.exit(0);

// Conventional Commits → seções Keep a Changelog. Só tipos relevantes ao usuário.
const SECTION = { feat: 'Added', fix: 'Fixed', perf: 'Changed', refactor: 'Changed', revert: 'Changed' };
const CC = /^(\w+)(?:\([^)]*\))?(!)?:\s*(.+)$/;

let md = readFileSync(changelog, 'utf8');
const added = []; // {section, line}
for (const row of raw.split('\n')) {
  const [hash, subject] = row.split('\x1f');
  if (!hash || !subject) continue;
  if (md.includes(`(${hash})`)) continue;            // idempotência: já registrado
  const m = subject.match(CC);
  if (!m) continue;
  const section = SECTION[m[1].toLowerCase()];
  if (!section) continue;                            // chore/test/ci/build/docs/style → ignora
  const breaking = m[2] === '!' ? ' **[BREAKING]**' : '';
  added.push({ section, line: `- ${m[3]}${breaking} (${hash})` });
}
if (added.length === 0) process.exit(0);

// Garante a seção "## [Unreleased]" logo após o preâmbulo (antes do 1º "## " versionado).
if (!/^##\s*\[Unreleased\]/m.test(md)) {
  const firstH2 = md.search(/^##\s+/m);
  const insertAt = firstH2 >= 0 ? firstH2 : md.length;
  md = md.slice(0, insertAt) + '## [Unreleased]\n\n' + md.slice(insertAt);
}

// Insere cada linha sob "### <Section>" dentro do bloco [Unreleased].
const unrelStart = md.search(/^##\s*\[Unreleased\]/m);
const after = md.slice(unrelStart);
const nextH2 = after.slice(1).search(/^##\s+/m); // próximo "## " após o cabeçalho Unreleased
const blockEnd = nextH2 >= 0 ? unrelStart + 1 + nextH2 : md.length;
let block = md.slice(unrelStart, blockEnd);

for (const section of ['Added', 'Changed', 'Fixed']) {
  const lines = added.filter((a) => a.section === section).map((a) => a.line);
  if (!lines.length) continue;
  const reSec = new RegExp(`(^###\\s*${section}\\s*\\n)`, 'm');
  if (reSec.test(block)) {
    block = block.replace(reSec, `$1${lines.join('\n')}\n`);
  } else {
    block = block.replace(/\n*$/, '\n') + `\n### ${section}\n${lines.join('\n')}\n`;
  }
}
md = md.slice(0, unrelStart) + block + md.slice(blockEnd);
writeFileSync(changelog, md);
console.log(`changelog: ${added.length} entrada(s) adicionada(s) a [Unreleased] no CHANGELOG.md (commit pendente)`);
