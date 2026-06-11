#!/usr/bin/env node
// Gate W1.0 — validates the canonical skeleton against its schemas (ajv, draft 2020-12):
//   1. template/.forge/forge.yaml            vs $defs/forgeManifest
//   2. template/.forge/FORGE.md frontmatter  vs $defs/forgeFrontmatter
//   3. adapter-capability.schema.json        compiles (sanity)
// Output: one "OK <check>" line per check; exits 1 on first failure with ajv errors.
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from 'yaml';
import Ajv2020 from 'ajv/dist/2020.js';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (p) => readFileSync(resolve(root, p), 'utf8');

const core = JSON.parse(read('template/.forge/schemas/forge.schema.json'));
const adapterCap = JSON.parse(read('template/.forge/schemas/adapter-capability.schema.json'));

const ajv = new Ajv2020.default({ allErrors: true, strict: true, allowUnionTypes: true });

function check(name, schema, data) {
  const validate = ajv.compile(schema);
  if (!validate(data)) {
    console.error(`FAIL ${name}`);
    console.error(JSON.stringify(validate.errors, null, 2));
    process.exit(1);
  }
  console.log(`OK ${name}`);
}

// $defs are self-contained except for nullableString — inline it for isolated compilation.
const withDefs = (def) => ({ ...def, $defs: { nullableString: core.$defs.nullableString } });

check('forge.yaml vs forgeManifest', withDefs(core.$defs.forgeManifest), parse(read('template/.forge/forge.yaml')));

const md = read('template/.forge/FORGE.md');
const fmMatch = md.match(/^---\n([\s\S]*?)\n---/);
if (!fmMatch) { console.error('FAIL FORGE.md has no YAML frontmatter'); process.exit(1); }
check('FORGE.md frontmatter vs forgeFrontmatter', withDefs(core.$defs.forgeFrontmatter), parse(fmMatch[1]));

const validateAdapter = ajv.compile(adapterCap);
console.log('OK adapter-capability.schema.json compiles');

const { readdirSync } = await import('node:fs');
const adaptersDir = resolve(root, 'template/.forge/adapters');
const decls = readdirSync(adaptersDir)
  .filter((f) => f.endsWith('.yaml') && !f.endsWith('.lock.yaml'))
  .sort();
for (const decl of decls) {
  const data = parse(read(`template/.forge/adapters/${decl}`));
  if (!validateAdapter(data)) {
    console.error(`FAIL adapters/${decl} vs adapter-capability schema`);
    console.error(JSON.stringify(validateAdapter.errors, null, 2));
    process.exit(1);
  }
}
console.log(`OK ${decls.length} adapter declarations vs adapter-capability schema (${decls.map((d) => d.replace('.yaml', '')).join(', ')})`);

// W2.0 — spec-manifest schema compiles and the dogfooding change manifest conforms
// (ajv parity check for the zero-dep validator in template/.forge/scripts/lib/validate-spec.mjs)
const specManifest = JSON.parse(read('template/.forge/schemas/spec-manifest.schema.json'));
const validateSpecManifest = ajv.compile(specManifest);
console.log('OK spec-manifest.schema.json compiles');
const dogfood = parse(read('.forge/specs/active/create-forge-project-harness/manifest.yaml'));
if (!validateSpecManifest(dogfood)) {
  console.error('FAIL dogfooding manifest vs spec-manifest schema');
  console.error(JSON.stringify(validateSpecManifest.errors, null, 2));
  process.exit(1);
}
console.log('OK dogfooding manifest (create-forge-project-harness) vs spec-manifest schema');

// W3.0 — baseline schemas compile; canonical state machine definition conforms
const compiled = {};
for (const s of ['spec-delta', 'baseline-capability', 'traceability', 'archive-state-machine', 'approvals', 'verification', 'graph-manifest']) {
  compiled[s] = ajv.compile(JSON.parse(read(`template/.forge/schemas/${s}.schema.json`)));
  console.log(`OK ${s}.schema.json compiles`);
}
const smData = parse(read('template/.forge/schemas/archive-state-machine.yaml'));
const vsm = compiled['archive-state-machine'];
if (!vsm(smData)) {
  console.error('FAIL archive-state-machine.yaml vs schema');
  console.error(JSON.stringify(vsm.errors, null, 2));
  process.exit(1);
}
console.log('OK archive-state-machine.yaml (canonical definition) vs schema');
