#!/usr/bin/env node
// forge validate spec — minimal version (W2.0/W2.1; full version arrives in W3.1).
// Zero-dependency (Node >= 20). Validates ONE active change folder:
//   1. manifest.yaml parses (supported subset) and conforms to the rules of
//      spec-manifest.schema.json, re-implemented deterministically here.
//   2. artifacts required by type/scale/status exist (doc §10.3 + §12).
//   3. approvals.yaml (when present) conforms to approvals.schema.json rules
//      (§12.1: non-approve requires reason; supersede names successor; iteration 1..3).
//   4. status=verified requires verification.yaml (§12).
// Output: single line "OK <id>" (exit 0) or "FAIL (<reasons>)" (exit 1). Usage:
//   node validate-spec.mjs <path-to-change-dir>
//
// YAML subset accepted (the format emitted by the forge scripts): 2-space
// indentation, `key: value` scalars, nested maps (one level), `key: []` inline
// empty lists, `- scalar` items, and `- key: value` object-list items with
// continuation lines. No inline maps, no multiline strings, no anchors.
import { readFileSync, existsSync } from 'node:fs';
import { join, basename, resolve } from 'node:path';

const dir = process.argv[2];
if (!dir) { console.log('FAIL (usage: validate-spec.mjs <change-dir>)'); process.exit(1); }
const root = resolve(dir);
const errors = [];

// ── tiny YAML subset parser ──────────────────────────────────────────────────
function parseScalar(raw) {
  const s = raw.trim();
  if (s === '' || s === 'null' || s === '~') return null;
  if (s === '[]') return [];
  if (s === 'true') return true;
  if (s === 'false') return false;
  if (/^-?[0-9]+$/.test(s)) return parseInt(s, 10);
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) return s.slice(1, -1);
  return s;
}

function parseYamlSubset(text) {
  const lines = text.split('\n').map((l) => l.replace(/\t/g, '  '))
    .filter((l) => l.trim() && !l.trim().startsWith('#'));
  const doc = {};
  const frames = [{ indent: -1, obj: doc }];
  let lastKey = null, lastKeyOwner = null, lastKeyIndent = -1;
  let listCtx = null; // { dashIndent, arr }

  for (const rawLine of lines) {
    const indent = rawLine.length - rawLine.trimStart().length;
    const line = rawLine.trim();

    if (line === '-' || line.startsWith('- ')) {
      if (!listCtx || indent !== listCtx.dashIndent) {
        if (lastKey === null || indent <= lastKeyIndent) throw new Error(`stray list item: "${line}"`);
        if (!Array.isArray(lastKeyOwner[lastKey])) lastKeyOwner[lastKey] = [];
        listCtx = { dashIndent: indent, arr: lastKeyOwner[lastKey] };
      }
      const rest = line === '-' ? '' : line.slice(2);
      const m = rest.match(/^([A-Za-z0-9_]+):(.*)$/);
      if (m) {
        // object item: "- key: value" — continuation lines (deeper indent) extend it
        const item = {};
        item[m[1]] = parseScalar(m[2]);
        listCtx.arr.push(item);
        while (frames.length > 1 && indent <= frames[frames.length - 1].indent) frames.pop();
        frames.push({ indent, obj: item });
        lastKey = m[1]; lastKeyOwner = item; lastKeyIndent = indent;
      } else {
        listCtx.arr.push(parseScalar(rest));
      }
      continue;
    }

    if (listCtx && indent <= listCtx.dashIndent) listCtx = null;
    while (frames.length > 1 && indent <= frames[frames.length - 1].indent) frames.pop();
    const container = frames[frames.length - 1].obj;

    const m = line.match(/^([A-Za-z0-9_]+):(.*)$/);
    if (!m) throw new Error(`unparseable line: "${line}"`);
    const [, key, rest] = m;

    if (rest.trim() === '') {
      container[key] = {}; // provisional: becomes [] if "- " items follow
      frames.push({ indent, obj: container[key] });
    } else {
      container[key] = parseScalar(rest);
    }
    lastKey = key; lastKeyOwner = container; lastKeyIndent = indent;
  }
  return doc;
}

// ── load manifest ────────────────────────────────────────────────────────────
const manifestPath = join(root, 'manifest.yaml');
if (!existsSync(manifestPath)) { console.log('FAIL (manifest.yaml missing)'); process.exit(1); }
let man;
try { man = parseYamlSubset(readFileSync(manifestPath, 'utf8')); }
catch (e) { console.log(`FAIL (manifest.yaml: ${e.message})`); process.exit(1); }

// ── schema rules (mirror of spec-manifest.schema.json) ──────────────────────
const TYPES = ['feature', 'bugfix', 'refactor', 'greenfield', 'brownfield'];
const MODES = ['greenfield', 'brownfield', 'feature-only'];
const RIGORS = ['spec-anchored', 'spec-first', 'spec-as-source'];
const STATUSES = ['idea', 'proposed', 'requirements-ready', 'design-ready', 'tasks-ready',
  'implementing', 'implemented', 'verified', 'archived',
  'blocked', 'abandoned', 'rejected', 'superseded', 'reopened', 'rolled-back'];
const GATE_KEYS = ['requirements_reviewed', 'design_reviewed', 'tasks_reviewed',
  'implementation_verified', 'human_archive_approval'];
const DATE_RE = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/;

for (const k of ['id', 'type', 'mode', 'rigor', 'scale', 'status', 'created_at', 'updated_at', 'owner', 'gates'])
  if (man[k] === undefined || man[k] === null) errors.push(`missing required field: ${k}`);

if (man.id && !/^[a-z0-9][a-z0-9-]*[a-z0-9]$/.test(String(man.id))) errors.push(`id not kebab-case: ${man.id}`);
if (man.id && basename(root) !== String(man.id)) errors.push(`id "${man.id}" != folder name "${basename(root)}"`);
if (man.type && !TYPES.includes(man.type)) errors.push(`type invalid: ${man.type} (allowed: ${TYPES.join('|')})`);
if (man.mode && !MODES.includes(man.mode)) errors.push(`mode invalid: ${man.mode} (allowed: ${MODES.join('|')})`);
if (man.rigor && !RIGORS.includes(man.rigor)) errors.push(`rigor invalid: ${man.rigor} (allowed: ${RIGORS.join('|')})`);
if (man.scale !== undefined && man.scale !== null && (!Number.isInteger(man.scale) || man.scale < 0 || man.scale > 4))
  errors.push(`scale must be integer 0..4: ${man.scale}`);
if (man.status && !STATUSES.includes(man.status)) errors.push(`status invalid: ${man.status}`);
for (const k of ['created_at', 'updated_at'])
  if (man[k] && !DATE_RE.test(String(man[k]))) errors.push(`${k} not YYYY-MM-DD: ${man[k]}`);
if (man.gates && typeof man.gates === 'object' && !Array.isArray(man.gates))
  for (const g of GATE_KEYS)
    if (typeof man.gates[g] !== 'boolean') errors.push(`gates.${g} must be boolean`);

if (man.quick_plan && man.quick_plan.enabled === true) {
  const sp = man.quick_plan.skipped_phases;
  if (!Array.isArray(sp) || sp.length === 0) errors.push('quick_plan.enabled requires non-empty skipped_phases');
  const just = man.quick_plan.justification;
  if (typeof just !== 'string' || just.trim().length < 8) errors.push('quick_plan.enabled requires justification (>= 8 chars)');
}

// ── artifact rules: type/scale/status (doc §10.3 + §12) ─────────────────────
const REQ_ARTIFACT = { bugfix: 'bugfix.md', refactor: 'refactor.md' };
const reqArtifact = REQ_ARTIFACT[man.type] || 'requirements.md';
const has = (f) => existsSync(join(root, f));

const STATUS_ORDER = ['idea', 'proposed', 'requirements-ready', 'design-ready', 'tasks-ready',
  'implementing', 'implemented', 'verified', 'archived'];
const onMainPath = STATUS_ORDER.includes(man.status);
const reached = (s) => onMainPath && STATUS_ORDER.indexOf(man.status) >= STATUS_ORDER.indexOf(s);
const scale = Number.isInteger(man.scale) ? man.scale : 2;

if (onMainPath && man.status !== 'idea' && !has('proposal.md'))
  errors.push('proposal.md missing (required from status=proposed onward)');
if (reached('requirements-ready') && scale >= 1 && !has(reqArtifact))
  errors.push(`${reqArtifact} missing (required from requirements-ready onward at scale ${scale})`);
if (man.status === 'design-ready' && !has('design.md'))
  errors.push('design.md missing (status design-ready requires it)');
if (reached('tasks-ready')) {
  if (!has('tasks.md')) errors.push('tasks.md missing (required from tasks-ready onward)');
  if (scale >= 2 && man.type !== 'bugfix' && !has('design.md'))
    errors.push(`design.md missing (scale ${scale} requires the design phase from tasks-ready onward)`);
  if (scale >= 1 && !has(reqArtifact))
    errors.push(`${reqArtifact} missing (scale ${scale} requires the requirements phase from tasks-ready onward)`);
}
if (reached('verified') && !has('verification.yaml'))
  errors.push('verification.yaml missing (status verified requires recorded evidence — §12)');

// ── approvals.yaml rules (§12.1 — mirror of approvals.schema.json) ──────────
const approvalsPath = join(root, 'approvals.yaml');
if (existsSync(approvalsPath)) {
  let ap;
  try { ap = parseYamlSubset(readFileSync(approvalsPath, 'utf8')); }
  catch (e) { errors.push(`approvals.yaml: ${e.message}`); ap = null; }
  if (ap) {
    const APPROVAL_GATES = [...GATE_KEYS, 'close'];
    const DECISIONS = ['approve', 'review', 'reject', 'supersede', 'abandon', 'block'];
    const list = Array.isArray(ap.approvals) ? ap.approvals : null;
    if (!list) errors.push('approvals.yaml: top-level "approvals" list missing');
    else list.forEach((e, i) => {
      const at = `approvals[${i}]`;
      if (!e || typeof e !== 'object') { errors.push(`${at}: not an object`); return; }
      if (!APPROVAL_GATES.includes(e.gate)) errors.push(`${at}: gate invalid: ${e.gate}`);
      if (!DECISIONS.includes(e.decision)) errors.push(`${at}: decision invalid: ${e.decision}`);
      if (!e.decided_by) errors.push(`${at}: decided_by missing`);
      if (!e.decided_at) errors.push(`${at}: decided_at missing`);
      if (e.decision && e.decision !== 'approve' && !(typeof e.reason === 'string' && e.reason.trim().length >= 3))
        errors.push(`${at}: decision "${e.decision}" requires reason (§12.1)`);
      if (e.decision === 'supersede' && !e.superseded_by)
        errors.push(`${at}: supersede requires superseded_by`);
      if (e.iteration !== undefined && e.iteration !== null && (!Number.isInteger(e.iteration) || e.iteration < 1 || e.iteration > 3))
        errors.push(`${at}: iteration must be 1..3 (loop §14.6)`);
    });
  }
}

// ── verdict ──────────────────────────────────────────────────────────────────
if (errors.length) { console.log(`FAIL (${errors.join('; ')})`); process.exit(1); }
console.log(`OK ${man.id}`);
