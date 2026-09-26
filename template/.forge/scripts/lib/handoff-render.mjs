// handoff-render — deterministic renderer for .forge/HANDOFF.md (sections 1-3, 5).
// Reads the active change state (manifest/progress/deferrals) and fills the handoff template.
// The narrative delta (section 4) is preserved across regenerations when already filled, so a
// rule-based hook run never destroys a delta written by /forge:handoff.
//
// REGRA DE BYTES AUTORAIS (#120, 4ª rodada — causa raiz, escrita uma vez em vez de corrigida
// sintoma a sintoma a cada achado novo):
//
//   1. O render é uma função pura dos dados do change (manifest/progress/deferrals + git + FORGE.md).
//   2. "Bytes autorais" de um HANDOFF.md anterior são os bytes que esse render não explica. O ideal
//      seria comparar contra o render que o gerador teria produzido a partir do MESMO estado
//      anterior — mas esse estado não é recuperável aqui (só o arquivo resultante existe). A
//      aproximação usada é: a diferença entre o arquivo anterior e o render dos dados ATUAIS,
//      restrita às regiões que o template não gera — (a) o slot NARRATIVE-DELTA inteiro, BRUTO, sem
//      trim e sem atalho de placeholder (qualquer texto ali é autoral, mesmo que comece com o
//      prefixo do placeholder "_(A preencher"); e (b) todo byte fora da estrutura literal do
//      template, verificado contra uma "forma" (regex) derivada do próprio template em que cada
//      `{{CAMPO}}` vira um coringa e o resto é casado ao pé da letra.
//   3. Backup byte-idêntico + WARN acontecem se e somente se algum byte autoral não sobrevive no
//      arquivo novo. Consequências que seguem direto da regra, não de guardas ad-hoc: uma mudança
//      só nos campos gerados (HEAD, data, progresso) sempre casa com a forma do template e nunca
//      dispara backup nem WARN; um arquivo sem os marcadores nunca casa (a forma exige o texto
//      literal dos marcadores) e sempre dispara "sem marcadores"; e o WARN nunca aponta "fora do
//      bloco" quando a perda é no slot — isso é garantido por construção, porque o slot bruto é
//      sempre copiado para a frente ANTES de qualquer decisão de backup, nunca depois nem
//      condicionado a como o texto começa ou termina.
//
// Driven by env (set by handoff-gen.sh): HANDOFF_DIR, HANDOFF_TPL, FORGE_ROOT, HANDOFF_ID,
// HANDOFF_BRANCH, HANDOFF_SHA, HANDOFF_DATE, HANDOFF_TEST, HANDOFF_TYPECHECK, HANDOFF_LINT.
// Deterministic: no wall clock (uses HEAD commit date passed in), stable field order. The backup
// filename is prefixed by the deterministic HEAD commit date (HANDOFF_DATE, slugified — never wall
// clock) followed by a hash of the previous file's bytes: the date makes backups sortable by name
// in the chronological order they were made for, and the hash keeps the dedupe property — a rerun
// over the exact same previous bytes under the exact same HANDOFF_DATE overwrites the same path
// instead of growing forge-backups/ without bound, while previous content that genuinely differs
// (new state, new lost text) still gets its own file.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, dirname, resolve as resolvePath } from 'node:path';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { parseYamlSubset } from './yaml-lite.mjs';

const env = process.env;
const dir = env.HANDOFF_DIR;
const root = env.FORGE_ROOT;
const out = join(root, '.forge', 'HANDOFF.md');

const readJson = (p) => { try { return JSON.parse(readFileSync(p, 'utf8')); } catch { return null; } };
const dash = (v) => (v === undefined || v === null || v === '' ? 'n/d' : String(v));

const manifest = parseYamlSubset(readFileSync(join(dir, 'manifest.yaml'), 'utf8'));
const progress = readJson(join(dir, 'progress.json')) || {};
const deferrals = readJson(join(dir, 'deferrals.json'));

const open = Array.isArray(deferrals)
  ? deferrals.filter((d) => d && d.status === 'open').map((d) => d.id)
  : (deferrals && Array.isArray(deferrals.deferrals)
      ? deferrals.deferrals.filter((d) => d && d.status === 'open').map((d) => d.id)
      : []);

const map = {
  CHANGE_ID: dash(env.HANDOFF_ID),
  TYPE: dash(manifest.type),
  SCALE: dash(manifest.scale),
  PHASE: dash(manifest.status),
  BRANCH: dash(env.HANDOFF_BRANCH),
  SHA: dash(env.HANDOFF_SHA),
  DATE: dash(env.HANDOFF_DATE),
  WAVE: dash(progress.current_wave),
  STORIES_DONE: dash(progress.done_stories ?? 0),
  STORIES_TOTAL: dash(progress.total_stories ?? 0),
  TASKS_DONE: dash(progress.done_tasks ?? 0),
  TASKS_TOTAL: dash(progress.total_tasks ?? 0),
  OPEN_DEFERRALS: open.length ? open.join(', ') : 'nenhum',
  RUNTIME_TEST: dash(env.HANDOFF_TEST),
  RUNTIME_TYPECHECK: dash(env.HANDOFF_TYPECHECK),
  RUNTIME_LINT: dash(env.HANDOFF_LINT),
};

const rawTpl = readFileSync(env.HANDOFF_TPL, 'utf8');
let content = rawTpl;
for (const [k, v] of Object.entries(map)) content = content.replaceAll(`{{${k}}}`, v);

function slugDate(v) {
  const s = (v || '').replace(/[^0-9A-Za-z]+/g, '-').replace(/^-+|-+$/g, '');
  return s || 'sem-data';
}

// Backs up the previous HANDOFF.md before any of it is discarded (#120). Mirrors the backup
// resolution the `update` flow uses since #76 (bin/forge.mjs): git-dir-relative and outside the
// working tree whenever one is resolvable (so it works from a linked worktree too, and never shows
// up in `git status` or gets swept by a gate that scans the tree), with a same-directory fallback
// for a non-git target. Takes the previous file as a raw Buffer, never the utf8-decoded string:
// decoding invalid UTF-8 replaces bad bytes with U+FFFD, and re-encoding that string back to disk
// changes the byte count and breaks the "byte-idêntico" contract for any HANDOFF.md that isn't
// clean UTF-8 (e.g. saved once from Latin-1/CP1252, or carrying a stray byte). Returns the absolute
// backup path and the exact byte length of what was saved, read from the buffer, not a decoded
// string.
function backupPreviousHandoff(root, prevBuf) {
  const bytes = prevBuf.length;
  const hash = createHash('sha256').update(prevBuf).digest('hex').slice(0, 16);
  const stamp = `${slugDate(env.HANDOFF_DATE)}-${hash}`;
  let gitDir = null;
  try {
    gitDir = resolvePath(root, execFileSync('git', ['-C', root, 'rev-parse', '--git-dir'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim());
  } catch { gitDir = null; }
  const backupPath = gitDir
    ? join(gitDir, 'forge-backups', `handoff-${stamp}.md`)
    : join(root, '.forge', `HANDOFF.md.bak-${stamp}`);
  mkdirSync(dirname(backupPath), { recursive: true });
  writeFileSync(backupPath, prevBuf);
  return { path: backupPath, bytes };
}

function escapeRegex(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

// Builds the "shape" a template can produce: literal text escaped as-is, `{{CAMPO}}` tokens turned
// into wildcards (fields are single-line values, so `[^\n]*` is enough — none of them legitimately
// contain a newline). This is what tells a state-only difference (any value at a field's position)
// apart from an authorial byte (anything that isn't literal template text or a field's position).
function buildShape(rawText) {
  return rawText
    .split(/(\{\{[A-Z_]+\}\})/)
    .map((part) => (/^\{\{[A-Z_]+\}\}$/.test(part) ? '[^\\n]*' : escapeRegex(part)))
    .join('');
}

const START = '<!-- FORGE:NARRATIVE-DELTA:START -->';
const END = '<!-- FORGE:NARRATIVE-DELTA:END -->';
const rawCs = rawTpl.indexOf(START), rawCe = rawTpl.indexOf(END);
const tplHasSlot = rawCs >= 0 && rawCe > rawCs;

// The "outside" shape: everything the template produces outside the slot must match this, for any
// field values and ANY slot content (the slot is handled separately, on its own raw bytes, below).
// When the template has no slot at all, the whole document is "outside". A previous file lacking
// the literal START/END markers can never match a shape that requires them, so "sem marcadores"
// falls out of this same check instead of needing a separate branch.
const outsideShape = tplHasSlot
  ? `${buildShape(rawTpl.slice(0, rawCs + START.length))}[\\s\\S]*${buildShape(rawTpl.slice(rawCe))}`
  : buildShape(rawTpl);
const outsideShapeRegex = new RegExp(`^${outsideShape}$`);

// Preserve an already-written narrative delta (idempotent regen), and back up whatever the render
// would otherwise silently discard (#120; see the header comment above for the full rule).
let backupInfo = null;
if (existsSync(out)) {
  const prevBuf = readFileSync(out);
  const prev = prevBuf.toString('utf8');
  const ps = prev.indexOf(START), pe = prev.indexOf(END);
  const cs = content.indexOf(START), ce = content.indexOf(END);
  const bothHaveMarkers = ps >= 0 && pe > ps && cs >= 0 && ce > cs;

  if (bothHaveMarkers) {
    // RAW slot body, no trim, no placeholder shortcut: the only thing that means "nothing to
    // preserve here" is the previous slot being byte-for-byte the template's own raw placeholder —
    // anything else, however it starts or ends, is authorial and is copied forward as-is.
    const prevSlotRaw = prev.slice(ps + START.length, pe);
    const tplSlotRaw = rawTpl.slice(rawCs + START.length, rawCe);
    if (prevSlotRaw !== tplSlotRaw) {
      content = content.slice(0, cs + START.length) + prevSlotRaw + content.slice(ce);
    }
  }

  // Whatever isn't accounted for above (the slot, always preserved raw when both files have
  // markers) has to match the template's shape for any authorial byte outside it to be ruled out —
  // a plain state change (new HEAD sha, new progress numbers) always matches, because the shape
  // wildcards every field position; a previous file that lacks the marker pair the current
  // template requires never matches, so it always counts as loss too.
  const wouldLoseBytes = !outsideShapeRegex.test(prev);

  // If the previous bytes already equal what will be written there is nothing to lose, so no
  // backup; likewise an empty previous file (0 bytes) has nothing to recover, so it is skipped too
  // — the backup and WARN exist to make real prior content recoverable, not to leave a trace on
  // every run.
  if (wouldLoseBytes && prevBuf.length > 0) {
    backupInfo = { ...backupPreviousHandoff(root, prevBuf), bothHaveMarkers };
  }
}

writeFileSync(out, content);
if (backupInfo) {
  const reason = backupInfo.bothHaveMarkers
    ? 'HANDOFF.md com conteúdo fora do bloco NARRATIVE-DELTA'
    : 'HANDOFF.md sem marcadores NARRATIVE-DELTA';
  process.stderr.write(
    `WARN: ${reason} — conteúdo anterior (${backupInfo.bytes} bytes) salvo em ${backupInfo.path}\n`,
  );
}
