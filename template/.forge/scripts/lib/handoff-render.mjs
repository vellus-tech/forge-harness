// handoff-render — deterministic renderer for .forge/HANDOFF.md (sections 1-3, 5).
// Reads the active change state (manifest/progress/deferrals) and fills the handoff template.
// The narrative delta (section 4) is preserved across regenerations when already filled, so a
// rule-based hook run never destroys a delta written by /forge:handoff.
//
// The property this file exists to guarantee (#120, plan section "Gate que fica"): for any
// previous HANDOFF.md — with or without a NARRATIVE-DELTA marker pair, with arbitrary bytes
// outside that pair — the previous bytes are always recoverable after a generation, either in the
// new file itself (the delta body, when it maps onto the new render) or in a byte-identical
// backup. This holds independently of whether a marker pair exists, because the render never
// reproduces anything outside the slot verbatim: sections 1-3 and 5 are always re-rendered from
// current state (so a plain state change, e.g. a new HEAD sha, differs from the previous render
// too), and /forge:handoff itself still writes narrative rounds outside the marker slot in
// production (aligning /forge:handoff to the marker contract is Onda 8, out of scope here) — the
// exact byte class #120 was filed over. So "no marker pair" and "marker pair present but content
// outside it changed" are both cases where bytes would otherwise be discarded silently, and both
// go through the same backup path below. Only the delta body between START/END is ever merged
// forward; everything else that would be lost is backed up, never silently dropped.
//
// Driven by env (set by handoff-gen.sh): HANDOFF_DIR, HANDOFF_TPL, FORGE_ROOT, HANDOFF_ID,
// HANDOFF_BRANCH, HANDOFF_SHA, HANDOFF_DATE, HANDOFF_TEST, HANDOFF_TYPECHECK, HANDOFF_LINT.
// Deterministic: no wall clock (uses HEAD commit date passed in), stable field order. The backup
// filename is derived from a hash of the previous file's bytes (not wall clock): it is a side
// artifact, never read back by this script, so naming it by content — rather than by time — is
// what keeps a rerun over unchanged previous bytes from growing forge-backups/ without bound; a
// previous file whose bytes genuinely differ (new state, new lost text) still gets its own file.
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

let content = readFileSync(env.HANDOFF_TPL, 'utf8');
for (const [k, v] of Object.entries(map)) content = content.replaceAll(`{{${k}}}`, v);

// Backs up the previous HANDOFF.md before any of it is discarded (#120). Mirrors the backup
// resolution the `update` flow uses since #76 (bin/forge.mjs): git-dir-relative and outside the
// working tree whenever one is resolvable (so it works from a linked worktree too, and never shows
// up in `git status` or gets swept by a gate that scans the tree), with a same-directory fallback
// for a non-git target. Takes the previous file as a raw Buffer, never the utf8-decoded string:
// decoding invalid UTF-8 replaces bad bytes with U+FFFD, and re-encoding that string back to disk
// changes the byte count and breaks the "byte-idêntico" contract for any HANDOFF.md that isn't
// clean UTF-8 (e.g. saved once from Latin-1/CP1252, or carrying a stray byte). The file name is the
// sha256 of the previous bytes (not a timestamp): a rerun that would discard the exact same
// previous content — e.g. two /forge:handoff-less session-end hooks back to back with no state
// change and no new text outside the slot — overwrites the same path with identical bytes instead
// of growing forge-backups/ with one file per call; previous content that actually differs (new
// state, new lost text) always hashes to a different path, so it always gets its own file. Returns
// the absolute backup path and the exact byte length of what was saved, read from the buffer, not
// from a decoded string.
function backupPreviousHandoff(root, prevBuf) {
  const bytes = prevBuf.length;
  const hash = createHash('sha256').update(prevBuf).digest('hex').slice(0, 16);
  let gitDir = null;
  try {
    gitDir = resolvePath(root, execFileSync('git', ['-C', root, 'rev-parse', '--git-dir'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim());
  } catch { gitDir = null; }
  const backupPath = gitDir
    ? join(gitDir, 'forge-backups', `handoff-${hash}.md`)
    : join(root, '.forge', `HANDOFF.md.bak-${hash}`);
  mkdirSync(dirname(backupPath), { recursive: true });
  writeFileSync(backupPath, prevBuf);
  return { path: backupPath, bytes };
}

// Preserve an already-written narrative delta (idempotent regen), and back up whatever the render
// would otherwise silently discard — inside the marker slot that only holds the placeholder, or
// everywhere outside it, marker pair present or not (#120; see the header comment above for why
// both cases share one backup path).
const START = '<!-- FORGE:NARRATIVE-DELTA:START -->';
const END = '<!-- FORGE:NARRATIVE-DELTA:END -->';
let backupInfo = null;
if (existsSync(out)) {
  const prevBuf = readFileSync(out);
  const prev = prevBuf.toString('utf8');
  const ps = prev.indexOf(START), pe = prev.indexOf(END);
  const cs = content.indexOf(START), ce = content.indexOf(END);
  const bothHaveMarkers = ps >= 0 && pe > ps && cs >= 0 && ce > cs;
  let wouldLoseBytes;
  if (bothHaveMarkers) {
    // Capture the slot's outer boundaries BEFORE any merge below reassigns `content` — the merge
    // changes the string length between cs and ce (prevBody vs. placeholder rarely match in size),
    // so slicing the post-merge string with the pre-merge `ce` would land on the wrong offset and
    // compare garbage. Prefix/suffix text itself is untouched by the merge either way.
    const contentPrefix = content.slice(0, cs);
    const contentSuffix = content.slice(ce + END.length);
    const prevBody = prev.slice(ps + START.length, pe).trim();
    const placeholder = content.slice(cs + START.length, ce).trim();
    // Only preserve if the previous body is a real delta (not the template placeholder).
    if (prevBody && !prevBody.startsWith('_(A preencher') && prevBody !== placeholder) {
      content = content.slice(0, cs + START.length) + '\n' + prevBody + '\n' + content.slice(ce);
    }
    // The slot itself is handled above (preserved in-file, or it was only ever the placeholder —
    // nothing to lose there either way). What is NOT handled above is everything outside the slot:
    // sections 1-3 and 5 are always re-rendered fresh from current state, so anything the previous
    // file had there — a stale state snapshot, or free text /forge:handoff wrote past the slot
    // instead of inside it (the exact production pattern #120 was filed over) — is about to be
    // overwritten. Compare what was outside the slot in prev against what will be outside it in
    // the new render; if they differ, those bytes would be lost and need the same backup as the
    // no-marker case below.
    const prevOutside = prev.slice(0, ps) + prev.slice(pe + END.length);
    const newOutside = contentPrefix + contentSuffix;
    wouldLoseBytes = prevOutside !== newOutside;
  } else {
    // No usable markers to map the existing file onto the new render (or the render has no marker
    // slot at all): the whole previous file is unmapped, so any difference from the new render
    // would discard it outright.
    wouldLoseBytes = prev !== content;
  }
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
