#!/usr/bin/env node
// Generic ajv validator for gate scripts (workspace-only; targets stay zero-dep).
// Usage: node tools/validate-yaml.mjs <schema.json> <file.yaml|.json>
// Output: "OK <file>" (exit 0) or "FAIL <file>" + ajv errors on stderr (exit 1).
import { readFileSync } from 'node:fs';
import { parse } from 'yaml';
import Ajv2020 from 'ajv/dist/2020.js';

const [schemaPath, filePath] = process.argv.slice(2);
if (!schemaPath || !filePath) {
  console.error('usage: validate-yaml.mjs <schema.json> <file.yaml|.json>');
  process.exit(2);
}
const schema = JSON.parse(readFileSync(schemaPath, 'utf8'));
const raw = readFileSync(filePath, 'utf8');
const data = filePath.endsWith('.json') ? JSON.parse(raw) : parse(raw);

const ajv = new Ajv2020.default({ allErrors: true, strict: true, allowUnionTypes: true });
const validate = ajv.compile(schema);
if (!validate(data)) {
  console.error(JSON.stringify(validate.errors, null, 2));
  console.log(`FAIL ${filePath}`);
  process.exit(1);
}
console.log(`OK ${filePath}`);
