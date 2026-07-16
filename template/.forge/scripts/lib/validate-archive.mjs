#!/usr/bin/env node
// forge validate archive (§19.3, W3.1) — static pre-flight for /forge:archive
// (doc §13.1). Zero-dependency. Checks, for ONE active change:
//   1. validate-spec passes (full §19.2 rules — invoked logic shared via files)
//      NOTE: callers run validate-spec first; this script re-checks the archive
//      specific conditions:
//   2. status == verified
//   3. spec-delta.yaml present + structurally valid + apply payloads present
//      (add/modify ops carry the structured `requirement` for deterministic apply)
//   4. verification.yaml present (checks recorded; no failed check)
//   5. approvals: manifest gates.human_archive_approval == true
//   6. tasks 100% done
//   7. published docs integrity: if .forge/cache/publish.lock exists, docs/product
//      files must match the recorded hashes (no manual edits without baseline origin)
// Output: "OK <id>" or "FAIL (<reasons>)". Usage: validate-archive.mjs <change-dir> [<forge-root>]
import { readFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { createHash } from 'node:crypto';
import { parseYamlSubset } from './yaml-lite.mjs';
import { hasScaffoldMarkers } from './scaffold-markers.mjs';
import { impactStatus } from './impact-freshness.mjs';

const dir = process.argv[2];
if (!dir) { console.log('FAIL (usage: validate-archive.mjs <change-dir> [<forge-root>])'); process.exit(1); }
const root = resolve(dir);
const forgeRoot = resolve(process.argv[3] || join(root, '../../../..'));
const errors = [];
const has = (f) => existsSync(join(root, f));
const load = (f) => parseYamlSubset(readFileSync(join(root, f), 'utf8'));

let man = null;
try { man = load('manifest.yaml'); } catch (e) { console.log(`FAIL (manifest.yaml: ${e.message})`); process.exit(1); }

if (man.status !== 'verified') errors.push(`status must be verified (got: ${man.status}) — finish /forge:verify first`);

// spec-delta with deterministic payloads
if (!has('spec-delta.yaml')) errors.push('spec-delta.yaml missing (nothing to apply — §13.1)');
else {
  // guard de scaffold: um esqueleto gerado (spec-delta-scaffold.mjs na fase verify) ou o
  // placeholder do template do spec-new nunca podem chegar ao baseline — o conteúdo passa
  // na validação estrutural, mas é texto de preenchimento, não spec.
  const raw = readFileSync(join(root, 'spec-delta.yaml'), 'utf8');
  if (hasScaffoldMarkers(raw))
    errors.push('spec-delta.yaml still has scaffold/template placeholders — fill the payloads in /forge:verify (§2.5) before archiving');
  try {
    const sd = load('spec-delta.yaml');
    const ops = Array.isArray(sd.operations) ? sd.operations : [];
    if (!ops.length) errors.push('spec-delta.yaml: no operations');
    ops.forEach((o, i) => {
      if ((o.op === 'add_requirement' || o.op === 'modify_requirement') && !o.requirement)
        errors.push(`spec-delta operations[${i}] (${o.op} ${o.requirement_id}): structured 'requirement' payload missing — required for deterministic apply`);
      if (o.requirement && o.requirement.id !== o.requirement_id)
        errors.push(`spec-delta operations[${i}]: requirement.id "${o.requirement.id}" != requirement_id "${o.requirement_id}"`);
    });
  } catch (e) { errors.push(`spec-delta.yaml: ${e.message}`); }
}

// verification evidence
if (!has('verification.yaml')) errors.push('verification.yaml missing (§13.1: checks executed or justified)');
else {
  try {
    const v = load('verification.yaml');
    const checks = v.verification && Array.isArray(v.verification.checks) ? v.verification.checks : [];
    for (const c of checks) if (c.status === 'failed') errors.push(`verification check failed: ${c.name}`);
  } catch (e) { errors.push(`verification.yaml: ${e.message}`); }
}

// human archive approval gate
if (!(man.gates && man.gates.human_archive_approval === true))
  errors.push('gates.human_archive_approval is not true (HITL gate — /forge:archive asks via AskUserQuestion)');

// tasks 100%
if (has('tasks.md')) {
  const open = (readFileSync(join(root, 'tasks.md'), 'utf8').match(/^\s*- \[( |-|!)\] /gm) || []).length;
  if (open > 0) errors.push(`${open} open task(s) in tasks.md`);
} else errors.push('tasks.md missing');

// impact freshness (§13.2 step 7, W4.2): if the change declares code affected_paths
// AND a graph exists, an up-to-date impact.json is required (run /forge:impact).
// Julgamento único em impact-freshness.mjs (mesma lógica do auto-recovery [0/6] do archive).
switch (impactStatus(root, forgeRoot)) {
  case 'missing':
    errors.push('impact.json missing — change touches code and a graph exists (run /forge:impact --change <id> before archive, §13.2)');
    break;
  case 'stale':
    errors.push('impact.json is stale vs current graph (re-run /forge:impact --change <id> after /forge:graph update)');
    break;
  default: // fresh | not-applicable
    break;
}

// published docs integrity (round-trip with publish-docs)
const lockPath = join(forgeRoot, '.forge/cache/publish.lock');
if (existsSync(lockPath)) {
  for (const line of readFileSync(lockPath, 'utf8').split('\n').filter(Boolean)) {
    const [hash, rel] = line.split(/\s{2,}|\t/);
    if (!rel) continue;
    const target = join(forgeRoot, rel);
    if (!existsSync(target)) { errors.push(`published file missing vs publish.lock: ${rel}`); continue; }
    const now = createHash('sha256').update(readFileSync(target)).digest('hex');
    if (now !== hash) errors.push(`docs/product changed without baseline origin: ${rel} (republish from product/current — §8.2)`);
  }
}

if (errors.length) { console.log(`FAIL (${errors.join('; ')})`); process.exit(1); }
console.log(`OK ${man.id}`);
