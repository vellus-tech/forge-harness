#!/usr/bin/env node
// analyzer-prompt.mjs — monta o prompt do analista de um artefato a partir de prompts/analyzer.md.
// Uso: node analyzer-prompt.mjs <skills|agents> <nome> [--iteration 2] [--extra "<texto>"]
// Ambiente: REEXEC_SCRATCH (o prompt é gravado em REEXEC_SCRATCH/analyzer-<nome>.md e o caminho é impresso).
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '../../..');
const [kind, name, ...rest] = process.argv.slice(2);
const opt = { iteration: '2', extra: '' };
for (let i = 0; i < rest.length; i += 2) opt[rest[i].replace(/^--/, '')] = rest[i + 1];
const EVALDIR = join(REPO, '.forge/evals', kind, name);
const ITERDIR = join(EVALDIR, 'workspace', `iteration-${opt.iteration}`);
const ARTIFACT = kind === 'skills' ? join(REPO, 'template/.forge/skills', name, 'SKILL.md')
  : execFileSync('find', [join(REPO, 'template/.forge/agents'), '-name', `${name}.md`], { encoding: 'utf8' }).trim();
const vars = { ITER: opt.iteration, NAME: name, REPO, ITERDIR, EVALDIR, ARTIFACT, EXTRA: opt.extra };
const out = Object.entries(vars).reduce((s, [k, v]) => s.split(`{{${k}}}`).join(v), readFileSync(join(HERE, 'prompts/analyzer.md'), 'utf8'));
const dst = join(process.env.REEXEC_SCRATCH, `analyzer-${name}.md`);
writeFileSync(dst, out);
console.log(dst);
