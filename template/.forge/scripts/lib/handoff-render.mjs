// handoff-render — deterministic renderer for .forge/HANDOFF.md (sections 1-3, 5).
// Reads the active change state (manifest/progress/deferrals) and fills the handoff template.
// The narrative delta (section 4) is preserved across regenerations when already filled, so a
// rule-based hook run never destroys a delta written by /forge:handoff.
//
// When the existing file has no NARRATIVE-DELTA marker pair (e.g. legacy content, or a handoff
// whose narrative was appended outside the marker slot instead of between START and END), the
// preserve check above cannot map what to keep — but that is not the same as there being nothing to
// keep (#120). Before overwriting, the previous bytes are backed up so they stay recoverable even
// though they are not merged into the new render. See backupPreviousHandoff() below.
//
// Known limitation, deliberately out of scope for #120 (see the plan's DA-09 and the Onda 8
// roadmap item on aligning /forge:handoff to the marker contract): once the file DOES have a
// marker pair, only the body between START and END is protected. Text appended outside that slot
// on a later run — the same misuse this file's markers exist to prevent, still possible if
// /forge:handoff or a hook writes there instead of between the markers — is regenerated over
// silently, with no backup and no WARN, exactly like before #120. See the control scenario for
// this in tests/w60-handoff-gen-gate.sh (marked as a known limitation, not a regression).
//
// Driven by env (set by handoff-gen.sh): HANDOFF_DIR, HANDOFF_TPL, FORGE_ROOT, HANDOFF_ID,
// HANDOFF_BRANCH, HANDOFF_SHA, HANDOFF_DATE, HANDOFF_TEST, HANDOFF_TYPECHECK, HANDOFF_LINT.
// Deterministic: no wall clock (uses HEAD commit date passed in), stable field order. The backup
// filename does use wall clock + a random suffix (it is a side artifact, never read back by this
// script, so it does not affect the render's determinism guarantee).
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, dirname, resolve as resolvePath } from 'node:path';
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
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

// Backs up the previous HANDOFF.md before it is discarded (#120). Mirrors the backup resolution
// the `update` flow uses since #76 (bin/forge.mjs): git-dir-relative and outside the working tree
// whenever one is resolvable (so it works from a linked worktree too, and never shows up in
// `git status` or gets swept by a gate that scans the tree), with a same-directory fallback for a
// non-git target. Takes the previous file as a raw Buffer, never the utf8-decoded string: decoding
// invalid UTF-8 replaces bad bytes with U+FFFD, and re-encoding that string back to disk changes
// the byte count and breaks the "byte-idêntico" contract for any HANDOFF.md that isn't clean UTF-8
// (e.g. saved once from Latin-1/CP1252, or carrying a stray byte). Returns the absolute backup path
// and the exact byte length of what was saved, read from the buffer, not from a decoded string.
function backupPreviousHandoff(root, prevBuf) {
  const bytes = prevBuf.length;
  const stamp = `${new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 14)}-${randomUUID().slice(0, 8)}`;
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

// Preserve an already-written narrative delta (idempotent regen).
const START = '<!-- FORGE:NARRATIVE-DELTA:START -->';
const END = '<!-- FORGE:NARRATIVE-DELTA:END -->';
let backupInfo = null;
if (existsSync(out)) {
  const prevBuf = readFileSync(out);
  const prev = prevBuf.toString('utf8');
  const ps = prev.indexOf(START), pe = prev.indexOf(END);
  const cs = content.indexOf(START), ce = content.indexOf(END);
  if (ps >= 0 && pe > ps && cs >= 0 && ce > cs) {
    const prevBody = prev.slice(ps + START.length, pe).trim();
    const placeholder = content.slice(cs + START.length, ce).trim();
    // Only preserve if the previous body is a real delta (not the template placeholder).
    if (prevBody && !prevBody.startsWith('_(A preencher') && prevBody !== placeholder) {
      content = content.slice(0, cs + START.length) + '\n' + prevBody + '\n' + content.slice(ce);
    }
  } else if (prev !== content && prevBuf.length > 0) {
    // No usable markers to map the existing file onto the new render (or the render has no marker
    // slot at all) — the trigger for backing up is "no marker pair found (in prev or in the new
    // render)", not a broader "content would be lost" check (see the header comment above and the
    // known-limitation scenario in the w60 gate). If the previous bytes already equal what will be
    // written there is nothing to lose, so no backup; likewise an empty previous file (0 bytes) has
    // nothing to recover, so it is skipped too — the backup and WARN exist to make real prior
    // content recoverable, not to leave a trace on every run.
    backupInfo = backupPreviousHandoff(root, prevBuf);
  }
}

writeFileSync(out, content);
if (backupInfo) {
  process.stderr.write(
    `WARN: HANDOFF.md sem marcadores NARRATIVE-DELTA — conteúdo anterior (${backupInfo.bytes} bytes) salvo em ${backupInfo.path}\n`,
  );
}
