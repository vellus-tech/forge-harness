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

const claudeYaml = parse(read('template/.forge/adapters/claude.yaml'));
if (!validateAdapter(claudeYaml)) {
  console.error('FAIL adapters/claude.yaml vs adapter-capability schema');
  console.error(JSON.stringify(validateAdapter.errors, null, 2));
  process.exit(1);
}
console.log('OK adapters/claude.yaml vs adapter-capability schema');
