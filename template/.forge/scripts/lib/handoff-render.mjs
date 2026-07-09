// handoff-render — deterministic renderer for .forge/HANDOFF.md (sections 1-3, 5).
// Reads the active change state (manifest/progress/deferrals) and fills the handoff template.
// The narrative delta (section 4) is preserved across regenerations when already filled, so a
// rule-based hook run never destroys a delta written by /forge:handoff.
//
// Driven by env (set by handoff-gen.sh): HANDOFF_DIR, HANDOFF_TPL, FORGE_ROOT, HANDOFF_ID,
// HANDOFF_BRANCH, HANDOFF_SHA, HANDOFF_DATE, HANDOFF_TEST, HANDOFF_TYPECHECK, HANDOFF_LINT.
// Deterministic: no wall clock (uses HEAD commit date passed in), stable field order.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
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

// Preserve an already-written narrative delta (idempotent regen).
const START = '<!-- FORGE:NARRATIVE-DELTA:START -->';
const END = '<!-- FORGE:NARRATIVE-DELTA:END -->';
if (existsSync(out)) {
  const prev = readFileSync(out, 'utf8');
  const ps = prev.indexOf(START), pe = prev.indexOf(END);
  const cs = content.indexOf(START), ce = content.indexOf(END);
  if (ps >= 0 && pe > ps && cs >= 0 && ce > cs) {
    const prevBody = prev.slice(ps + START.length, pe).trim();
    const placeholder = content.slice(cs + START.length, ce).trim();
    // Only preserve if the previous body is a real delta (not the template placeholder).
    if (prevBody && !prevBody.startsWith('_(A preencher') && prevBody !== placeholder) {
      content = content.slice(0, cs + START.length) + '\n' + prevBody + '\n' + content.slice(ce);
    }
  }
}

writeFileSync(out, content);
