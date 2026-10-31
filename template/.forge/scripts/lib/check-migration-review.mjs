#!/usr/bin/env node
// forge check migration-review (REQ-05, rule data/migration-review.md): detecta migration
// tocada sem evidência de parecer de revisão especializada (data-engineer/data-relational).
// Zero-dependência: só node:fs/node:path/node:child_process.
//
// Modos:
//   check-migration-review.mjs range <rev-range> [--evidence <path>]
//   check-migration-review.mjs --path <dir> [--evidence <path>]
//
// `range` é o modo de push/CI: resolve os arquivos tocados via `git diff --name-only
// base..head` (forma base..head) ou `git diff-tree --root -r --name-only <sha>` (forma de
// sha/ref único, sem pai conhecido — nunca `git diff --name-only <sha>`, que compara contra a
// árvore de trabalho). A evidência é lida do BLOB no commit de destino (`git show
// <head>:migration-review.md`), nunca do disco — um `migration-review.md` editado e não
// commitado, ou pertencente a outra branch checked-out, não deve fazer o gate passar.
//
// `--path <dir>` é o modo ad-hoc/manual (revisão de um diretório específico materializado,
// ex.: o clone que o especialista está revisando): caminhamento recursivo próprio (não o
// collect() de source-scan.mjs, que filtra só por extname, não por glob de path) e evidência
// lida do disco (`<dir>/migration-review.md`) — aqui não há "commit sendo enviado", é
// inspeção direta.
//
// O script não analisa o SQL em si — só a forma/presença da linha de evidência. A qualidade
// do parecer é responsabilidade humana/agente (rule §"Quem revisa").
import { readFileSync, existsSync, statSync, readdirSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { spawnSync } from 'node:child_process';

// Padrões de path de migration (default, fixos; sem leitura de config externa nesta
// entrega — extensão é editar esta constante). dbmate/Rails/node-pg-migrate, EF Core,
// Flyway, Alembic.
const MIGRATION_PATTERNS = [
  /(^|\/)db\/migrate\//,
  /(^|\/)db\/migrations\//,
  /(^|\/)migrations\//,
  /(^|\/)Migrations\/[^/]+\.cs$/,
  /(^|\/)src\/main\/resources\/db\/migration\//,
  /(^|\/)alembic\/versions\//,
];

// Mesmos diretórios ignorados por valor que source-scan.mjs usa (DEFAULT_SKIP) — não
// importado dele, para não acoplar à API de extensão do coletor genérico.
const SKIP_DIRS = new Set([
  'node_modules', '.git', 'dist', 'build', 'out', 'bin', 'obj', '.forge', 'coverage',
  '.next', 'vendor', 'storybook-static', 'wwwroot', '_archive', 'TestResults',
  '.vs', '.idea', '.venv', '__pycache__', '.turbo', '.cache',
]);

function isMigrationPath(p) {
  const norm = p.split(sep).join('/');
  return MIGRATION_PATTERNS.some((re) => re.test(norm));
}

function run(cmd, args, opts = {}) {
  return spawnSync(cmd, args, { encoding: 'utf8', ...opts });
}

function parseArgs(argv) {
  const out = { mode: null, arg: null, evidence: null };
  let i = 0;
  if (argv[i] === 'range') { out.mode = 'range'; out.arg = argv[i + 1]; i += 2; }
  else if (argv[i] === '--path') { out.mode = 'path'; out.arg = argv[i + 1]; i += 2; }
  else { out.mode = null; }
  while (i < argv.length) {
    if (argv[i] === '--evidence') { out.evidence = argv[i + 1]; i += 2; }
    else { i += 1; }
  }
  return out;
}

// Casa cada linha de evidência: "- [x] <path>" (revisada) ou
// "- [exception] <path> item=<N> backlog=<ref> [adr=<ref>]" (exceção). item= é restrito a
// 1-13 (os itens do checklist da rule) — fora disso a linha simplesmente não casa esta regex
// e a migration fica sem evidência válida (achado de round de verify: (\d{1,2}) aceitava
// item=0/item=99). Ordem exigida na linha é item= antes de backlog= antes de adr=, documentada
// na rule (seção "Exceção") — uma ordem diferente não casa e é tratada como evidência ausente.
const LINE_REVIEWED_RE = /^\s*-\s*\[x\]\s+(\S+)/;
const LINE_EXCEPTION_RE = /^\s*-\s*\[exception\]\s+(\S+)\s+item=(1[0-3]|[1-9])\s+backlog=(\S+)(?:\s+adr=(\S+))?/;

function parseEvidence(text) {
  // path -> { kind: 'reviewed' } | { kind: 'exception', item, backlog, adr }
  const map = new Map();
  for (const line of text.split('\n')) {
    let m = line.match(LINE_REVIEWED_RE);
    if (m) { map.set(m[1], { kind: 'reviewed' }); continue; }
    m = line.match(LINE_EXCEPTION_RE);
    if (m) {
      map.set(m[1], { kind: 'exception', item: m[2], backlog: m[3], adr: m[4] || null });
    }
  }
  return map;
}

function evaluate(path, evidenceMap) {
  const entry = evidenceMap.get(path);
  if (!entry) return { ok: false, reason: 'sem evidência (nem revisada nem exceção)' };
  if (entry.kind === 'reviewed') return { ok: true, msg: null };
  // exceção — válida só com backlog presente, e com adr presente quando item=2
  if (!entry.backlog) return { ok: false, reason: 'exceção sem backlog= (evidência inválida)' };
  if (entry.item === '2' && !entry.adr) {
    return { ok: false, reason: 'exceção do item 2 sem adr= (evidência inválida)' };
  }
  return { ok: true, msg: `exceção item ${entry.item}, backlog ${entry.backlog}` };
}

function walkDir(dir, acc = []) {
  if (!existsSync(dir)) return acc;
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) {
      if (!SKIP_DIRS.has(e.name)) walkDir(join(dir, e.name), acc);
    } else {
      acc.push(join(dir, e.name));
    }
  }
  return acc;
}

function resolveRangeFiles(rangeArg) {
  // base..head (diff de duas pontas) ou base...head (diff simétrico de três pontos) — o
  // pre-push nunca gera a forma de três pontos (só base..head ou sha único), mas o script
  // aceita como modo manual/ad-hoc. Extrai o head com split em 2-3 pontos (/\.{2,3}/), não em
  // '..' literal: "a...b".split('..') fragmentava errado (['a', '.b']), extraindo ".b" como
  // head em vez de "b" (achado de round de verify — bug latente, nunca acionado pelo pre-push).
  if (/\.{2,3}/.test(rangeArg)) {
    const res = run('git', ['diff', '--name-only', rangeArg]);
    if (res.status !== 0) {
      return { error: true, stderr: res.stderr || '' };
    }
    const files = res.stdout.split('\n').filter(Boolean);
    const parts = rangeArg.split(/\.{2,3}/).filter(Boolean);
    const head = parts[parts.length - 1];
    return { error: false, files, head };
  }
  // sha/ref único, sem pai conhecido — git diff-tree --root -r --name-only <sha>
  const res = run('git', ['diff-tree', '--root', '-r', '--name-only', rangeArg]);
  if (res.status !== 0) {
    return { error: true, stderr: res.stderr || '' };
  }
  const files = res.stdout.split('\n').filter(Boolean).filter((f) => f !== rangeArg);
  return { error: false, files, head: rangeArg };
}

function readEvidenceFromBlob(head, evidencePath) {
  const res = run('git', ['show', `${head}:${evidencePath}`]);
  if (res.status !== 0) return null; // blob ausente ⇒ tratado como ausente
  return res.stdout;
}

function readEvidenceFromDisk(path) {
  if (!existsSync(path)) return null;
  return readFileSync(path, 'utf8');
}

function formatResult(migrations, evidenceText) {
  const evidenceMap = parseEvidence(evidenceText || '');
  const fails = [];
  const passMsgs = [];
  for (const m of migrations) {
    const r = evaluate(m, evidenceMap);
    if (!r.ok) fails.push(`${m}: ${r.reason}`);
    else if (r.msg) passMsgs.push(r.msg);
  }
  if (fails.length) {
    return { ok: false, text: `FAIL (${fails.join('; ')})` };
  }
  if (passMsgs.length) {
    // Texto exato do critério de aceite para o caso comum (uma exceção): "PASS (exceção item
    // N, backlog X)", sem prefixo de path (achado de round de verify — a versão anterior
    // sempre prefixava "<path>: "). Com mais de uma exceção no mesmo range, a mensagem junta
    // as duas sem path — ambiguidade aceita nesse caso raro; o script não analisa o SQL, só a
    // forma da evidência, e qual migration está em exceção já está registrado no próprio
    // migration-review.md para quem precisar auditar.
    return { ok: true, text: `PASS (${passMsgs.join('; ')})` };
  }
  return { ok: true, text: 'PASS' };
}

function main() {
  const argv = process.argv.slice(2);
  const { mode, arg, evidence } = parseArgs(argv);

  if (mode === 'range') {
    if (!arg) {
      console.log('FAIL (usage: check-migration-review.mjs range <rev-range> [--evidence <path>])');
      process.exit(1);
    }
    const resolved = resolveRangeFiles(arg);
    if (resolved.error) {
      console.log(`FAIL (range inválido: ${arg})`);
      process.exit(1);
    }
    const migrations = resolved.files.filter(isMigrationPath);
    if (!migrations.length) {
      console.log('PASS (sem migration)');
      process.exit(0);
    }
    const evidencePath = evidence || 'migration-review.md';
    const evidenceText = readEvidenceFromBlob(resolved.head, evidencePath);
    const result = formatResult(migrations, evidenceText);
    console.log(result.text);
    process.exit(result.ok ? 0 : 1);
  }

  if (mode === 'path') {
    if (!arg) {
      console.log('FAIL (usage: check-migration-review.mjs --path <dir> [--evidence <path>])');
      process.exit(1);
    }
    if (!existsSync(arg) || !statSync(arg).isDirectory()) {
      console.log(`FAIL (diretório não encontrado: ${arg})`);
      process.exit(1);
    }
    const allFiles = walkDir(arg);
    const migrations = allFiles
      .map((f) => relative(arg, f).split(sep).join('/'))
      .filter(isMigrationPath);
    if (!migrations.length) {
      console.log('PASS (sem migration)');
      process.exit(0);
    }
    const evidencePath = evidence ? evidence : join(arg, 'migration-review.md');
    const evidenceText = readEvidenceFromDisk(evidencePath);
    const result = formatResult(migrations, evidenceText);
    console.log(result.text);
    process.exit(result.ok ? 0 : 1);
  }

  console.log('FAIL (usage: check-migration-review.mjs range <rev-range> | --path <dir>)');
  process.exit(1);
}

main();
