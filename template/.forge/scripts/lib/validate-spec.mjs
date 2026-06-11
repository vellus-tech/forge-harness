#!/usr/bin/env node
// forge validate spec — full version (§19.2, W3.1).
// Zero-dependency (Node >= 20). Validates ONE active change folder:
//   1. manifest.yaml parses (yaml-lite subset) and conforms to the rules of
//      spec-manifest.schema.json, re-implemented deterministically here.
//   2. artifacts required by type/scale/status exist (doc §10.3 + §12).
//   3. approvals.yaml (when present) conforms to approvals.schema.json rules
//      (§12.1 decision form + legacy §10.10 form).
//   4. status=verified requires verification.yaml (§12).
//   5. §19.2 content rules: mandatory headings per artifact, no orphan
//      <CHANGE_*> placeholders, no bare NEEDS CLARIFICATION from
//      requirements-ready on (backtick-quoted mentions are instructional),
//      traceability.yaml coherence, spec-delta.yaml structural rules.
// Output: single line "OK <id>" (exit 0) or "FAIL (<reasons>)" (exit 1). Usage:
//   node validate-spec.mjs <path-to-change-dir>
import { readFileSync, existsSync } from 'node:fs';
import { join, basename, resolve } from 'node:path';
import { parseYamlSubset } from './yaml-lite.mjs';

const dir = process.argv[2];
if (!dir) { console.log('FAIL (usage: validate-spec.mjs <change-dir>)'); process.exit(1); }
const root = resolve(dir);
const errors = [];

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
      if (e.approved_by && e.approved_at && e.decision === undefined) {
        // legacy §10.10 form (plain approval record) — gate is free-form here
        if (!e.gate) errors.push(`${at}: gate missing (legacy form)`);
        return;
      }
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

// ── §19.2 full rules (W3.1): placeholders, clarifications, headings ─────────
const readIf = (f) => (has(f) ? readFileSync(join(root, f), 'utf8') : null);
const MD_ARTIFACTS = ['proposal.md', 'requirements.md', 'bugfix.md', 'refactor.md', 'design.md', 'tasks.md', 'analysis.md', 'verification.md'];

for (const f of MD_ARTIFACTS) {
  const text = readIf(f);
  if (!text) continue;
  const orphan = text.match(/<CHANGE_[A-Z_]+>/);
  if (orphan) errors.push(`${f}: orphan template placeholder ${orphan[0]}`);
  // real NEEDS CLARIFICATION markers block requirements-ready+ (§12). Convention:
  // real markers are bare; instructional mentions are backtick-quoted.
  if (reached('requirements-ready')) {
    const bare = text.split('\n').some((l) => l.includes('NEEDS CLARIFICATION') && !l.includes('`NEEDS CLARIFICATION`'));
    if (bare) errors.push(`${f}: unresolved NEEDS CLARIFICATION (blocks requirements-ready+ — run /forge:clarify)`);
  }
}

const headingRules = [
  ['proposal.md', /^## 1\./m, 'section "## 1." (why)'],
  ['proposal.md', /^## 2\./m, 'section "## 2." (what changes)'],
  ['bugfix.md', /comportamento atual/i, 'current-behavior section'],
  ['bugfix.md', /root cause/i, 'root-cause section'],
  ['refactor.md', /invariantes/i, 'invariants section'],
];
for (const [f, re, what] of headingRules) {
  const text = readIf(f);
  if (text && !re.test(text)) errors.push(`${f}: missing ${what}`);
}
if (reached('requirements-ready') && man.type !== 'bugfix' && man.type !== 'refactor' && scale >= 1) {
  const text = readIf('requirements.md');
  if (text && !/^## REQ-/m.test(text)) errors.push('requirements.md: no "## REQ-" entries');
  if (text && !/critérios de aceite/i.test(text)) errors.push('requirements.md: no acceptance criteria (testability — §19.2)');
}
if (reached('tasks-ready')) {
  const text = readIf('tasks.md');
  if (text && !/^\s*- \[( |-|X|!)\] TASK-[0-9]+/m.test(text)) errors.push('tasks.md: no TASK-NN entries');
}

// ── traceability.yaml coherence (§19.2) ─────────────────────────────────────
if (has('traceability.yaml')) {
  try {
    const tr = parseYamlSubset(readFileSync(join(root, 'traceability.yaml'), 'utf8'));
    const list = Array.isArray(tr.traceability) ? tr.traceability : null;
    if (!list) errors.push('traceability.yaml: top-level "traceability" list missing');
    else {
      const reqText = readIf(reqArtifact) || '';
      const tasksText = readIf('tasks.md') || '';
      list.forEach((t, i) => {
        if (!t.requirement_id) { errors.push(`traceability[${i}]: requirement_id missing`); return; }
        if (reqText && !reqText.includes(String(t.requirement_id)))
          errors.push(`traceability[${i}]: ${t.requirement_id} not found in ${reqArtifact}`);
        const tasks = Array.isArray(t.tasks) ? t.tasks : [];
        if (!tasks.length) errors.push(`traceability[${i}]: ${t.requirement_id} has no tasks`);
        for (const tk of tasks)
          if (tasksText && !tasksText.includes(String(tk))) errors.push(`traceability[${i}]: ${tk} not found in tasks.md`);
      });
    }
  } catch (e) { errors.push(`traceability.yaml: ${e.message}`); }
}

// ── spec-delta.yaml structural rules (§19.2 — mirror of spec-delta.schema) ──
if (has('spec-delta.yaml')) {
  try {
    const sd = parseYamlSubset(readFileSync(join(root, 'spec-delta.yaml'), 'utf8'));
    const ops = Array.isArray(sd.operations) ? sd.operations : null;
    if (!ops || !ops.length) errors.push('spec-delta.yaml: operations list missing/empty');
    else ops.forEach((o, i) => {
      const at = `spec-delta operations[${i}]`;
      const OPS = ['add_requirement', 'modify_requirement', 'remove_requirement', 'add_contract'];
      if (!OPS.includes(o.op)) { errors.push(`${at}: op invalid: ${o.op}`); return; }
      if (o.op !== 'add_contract' && (!o.capability || !o.requirement_id))
        errors.push(`${at}: capability/requirement_id missing`);
      if (o.op === 'remove_requirement' && !o.reason) errors.push(`${at}: remove requires reason`);
      if (o.op === 'add_contract' && (!o.contract_type || !o.path)) errors.push(`${at}: contract_type/path missing`);
    });
  } catch (e) { errors.push(`spec-delta.yaml: ${e.message}`); }
}

// ── verdict ──────────────────────────────────────────────────────────────────
if (errors.length) { console.log(`FAIL (${errors.join('; ')})`); process.exit(1); }
console.log(`OK ${man.id}`);
