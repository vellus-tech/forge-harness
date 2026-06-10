#!/usr/bin/env node
// sync-adapters — projects .forge/** into tool-specific adapters (W1.2: claude only;
// W1.4 generalizes to codex/qwen/kiro/gemini/cursor/agents-skills via manifest-driven logic).
//
// Dependency-free by design (runs in target projects without node_modules). The FORGE.md
// frontmatter is read via targeted extraction for a structure owned and schema-validated by
// the Forge itself (forge.schema.json via doctor/workspace CI) — not a general YAML parser.
//
// Deterministic output: no timestamps; lockfile entries sorted by path; running twice yields
// byte-identical results (idempotency is a tested gate).
//
// Usage: node sync-adapters.mjs --adapter claude [--root <project-root>] [--copy-links]
import {
  readFileSync, writeFileSync, mkdirSync, readdirSync, statSync,
  existsSync, symlinkSync, lstatSync, unlinkSync, readlinkSync
} from 'node:fs';
import { createHash } from 'node:crypto';
import { join, relative, basename, dirname } from 'node:path';

// ── args ─────────────────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
const opt = (name, dflt) => {
  const i = argv.indexOf(`--${name}`);
  return i >= 0 ? argv[i + 1] : dflt;
};
const ADAPTER = opt('adapter', 'claude');
const ROOT = opt('root', process.cwd());
const COPY_LINKS = argv.includes('--copy-links');
const FORGE = join(ROOT, '.forge');

if (ADAPTER !== 'claude') {
  console.error(`FAIL (adapter '${ADAPTER}' not implemented yet — W1.4)`);
  process.exit(1);
}
if (!existsSync(join(FORGE, 'FORGE.md'))) {
  console.error(`FAIL (no .forge/FORGE.md under ${ROOT} — run /forge:init first)`);
  process.exit(1);
}

// ── helpers ──────────────────────────────────────────────────────────────────
const sha256 = (buf) => 'sha256:' + createHash('sha256').update(buf).digest('hex');
const ensure = (dir) => mkdirSync(dir, { recursive: true });
const writeIfChanged = (path, content) => {
  if (existsSync(path) && readFileSync(path, 'utf8') === content) return;
  ensure(dirname(path));
  writeFileSync(path, content);
};

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

// Targeted frontmatter extraction: top-level "section:" then 2-space-indented "key: value".
function fmExtract(md) {
  const m = md.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return {};
  const lines = m[1].split('\n');
  const out = {};
  let section = null;
  for (const line of lines) {
    const top = line.match(/^([a-z_]+):\s*(.*)$/);
    const sub = line.match(/^ {2}([a-z_]+):\s*(.*)$/);
    if (top) { section = top[1]; if (top[2]) out[section] = top[2]; }
    else if (sub && section) out[`${section}.${sub[1]}`] = sub[2];
  }
  return out;
}

const lockEntries = [];
const emit = (destAbs, content, srcAbs = null) => {
  writeIfChanged(destAbs, content);
  lockEntries.push({
    dest: relative(ROOT, destAbs),
    src: srcAbs ? relative(ROOT, srcAbs) : null,
    sha256: sha256(Buffer.from(content)),
  });
};

// ── 1. commands → .claude/commands/forge/ + deprecated wrappers ─────────────
const commandFiles = walk(join(FORGE, 'commands')).filter(
  (f) => f.endsWith('.md') && basename(f) !== 'README.md'
);
for (const src of commandFiles) {
  const name = basename(src, '.md');
  const content = readFileSync(src, 'utf8');
  emit(join(ROOT, '.claude/commands/forge', `${name}.md`), content, src);
  const wrapper = `---
description: "[DEPRECATED] Alias de /forge:${name} mantido pelo contrato de compatibilidade (C1); remocao prevista na W8.3. Prefira /forge:${name}."
---

Este comando foi renomeado para \`/forge:${name}\`.

Execute exatamente as instrucoes de \`.claude/commands/forge/${name}.md\` com os mesmos argumentos recebidos ($ARGUMENTS), sem alterar o comportamento. Ao concluir, informe ao usuario que este alias sera removido e que o nome atual e \`/forge:${name}\`.
`;
  emit(join(ROOT, '.claude/commands', `${name}.md`), wrapper, src);
}
// commands README (catalog pointer)
const cmdReadmeSrc = join(FORGE, 'commands', 'README.md');
if (existsSync(cmdReadmeSrc)) {
  emit(join(ROOT, '.claude/commands/forge', 'README.md'), readFileSync(cmdReadmeSrc, 'utf8'), cmdReadmeSrc);
}

// ── 2. agents + skills → 1:1 projection ─────────────────────────────────────
for (const tree of ['agents', 'skills']) {
  for (const src of walk(join(FORGE, tree))) {
    const rel = relative(join(FORGE, tree), src);
    emit(join(ROOT, '.claude', tree, rel), readFileSync(src, 'utf8'), src);
  }
}

// ── 3. settings.json — C5: ONLY the worktree-guard is wired ─────────────────
const settings = {
  hooks: {
    PreToolUse: [
      {
        matcher: 'Bash',
        hooks: [
          {
            type: 'command',
            command: '$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh',
          },
        ],
      },
    ],
  },
};
emit(join(ROOT, '.claude/settings.json'), JSON.stringify(settings, null, 2) + '\n');

// ── 4. AGENTS.md — operational projection of FORGE.md (§7.2 / §7.4) ─────────
const forgeMd = readFileSync(join(FORGE, 'FORGE.md'), 'utf8');
const fm = fmExtract(forgeMd);
const tpl = readFileSync(join(FORGE, 'templates', 'AGENTS.md'), 'utf8');
const fillEmpty = (v) => (v === undefined || v === null ? '' : v);
const projected = tpl
  .replaceAll('{{PROJECT_NAME}}', fillEmpty(fm['project.name']))
  .replaceAll('{{PROJECT_DISPLAY}}', fillEmpty(fm['project.display']))
  .replaceAll('{{PROJECT_DESCRIPTION}}', fillEmpty(fm['project.description']))
  .replaceAll('{{REPO_SLUG}}', fillEmpty(fm['project.repo_slug']))
  .replaceAll('{{DEFAULT_BRANCH}}', fillEmpty(fm['project.default_branch']))
  .replaceAll('{{JIRA_KEY}}', '')
  .replaceAll('{{JIRA_SITE}}', '')
  .replaceAll('{{ISSUER}}', '')
  .replaceAll('{{RUN_CMD}}', fillEmpty(fm['runtime.run']))
  .replaceAll('{{TEST_CMD}}', fillEmpty(fm['runtime.test']))
  .replaceAll('{{TYPECHECK_CMD}}', fillEmpty(fm['runtime.typecheck']))
  .replaceAll('{{LINT_CMD}}', fillEmpty(fm['runtime.lint']));
emit(join(ROOT, 'AGENTS.md'), projected, join(FORGE, 'FORGE.md'));

// ── 5. CLAUDE.md / QWEN.md / GEMINI.md → AGENTS.md ───────────────────────────
for (const link of ['CLAUDE.md', 'QWEN.md', 'GEMINI.md']) {
  const p = join(ROOT, link);
  if (COPY_LINKS) {
    emit(p, projected, join(FORGE, 'FORGE.md'));
    continue;
  }
  if (existsSync(p) || (() => { try { lstatSync(p); return true; } catch { return false; } })()) {
    const st = lstatSync(p);
    if (st.isSymbolicLink() && readlinkSync(p) === 'AGENTS.md') {
      lockEntries.push({ dest: link, src: 'AGENTS.md', sha256: 'symlink' });
      continue;
    }
    unlinkSync(p);
  }
  symlinkSync('AGENTS.md', p);
  lockEntries.push({ dest: link, src: 'AGENTS.md', sha256: 'symlink' });
}

// ── 6. lockfile (deterministic: sorted, no timestamps) ──────────────────────
lockEntries.sort((a, b) => a.dest.localeCompare(b.dest));
const lock = [
  '# Generated by sync-adapters.mjs — drift detection input for forge doctor (§15).',
  'adapter: claude',
  'files:',
  ...lockEntries.map((e) =>
    [`  - dest: ${e.dest}`, e.src ? `    src: ${e.src}` : null, `    sha256: ${e.sha256}`]
      .filter(Boolean)
      .join('\n')
  ),
  '',
].join('\n');
writeIfChanged(join(FORGE, 'adapters', 'claude.lock.yaml'), lock);

console.log(`OK claude adapter synced (${lockEntries.length} targets) under ${ROOT}`);
