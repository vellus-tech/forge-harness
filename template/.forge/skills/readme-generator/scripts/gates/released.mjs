#!/usr/bin/env node
// released.mjs — gate: cada seção "## [X.Y.Z]" do arquivo anterior tem que estar BYTE A BYTE
// idêntica no arquivo novo. [Unreleased] não entra nesta regra (é o bloco em construção).
//
// Uso: released.mjs <changelog-antigo> <changelog-novo>
// Saída: "OK ..." / "FAIL released: ...", rc 0/1.
import { readFileSync, existsSync } from 'node:fs';

const [, , oldPath, newPath] = process.argv;
if (!oldPath || !newPath) {
  console.error('Uso: released.mjs <changelog-antigo> <changelog-novo>');
  process.exit(2);
}

function extractVersionBlocks(md) {
  const blocks = new Map(); // version -> texto completo do bloco (do "## [X]" até o próximo "## ")
  const re = /^##\s*\[(\d+\.\d+\.\d+[^\]]*)\]/gm;
  const matches = [...md.matchAll(re)];
  for (let i = 0; i < matches.length; i++) {
    const start = matches[i].index;
    const end = i + 1 < matches.length ? matches[i + 1].index : md.length;
    blocks.set(matches[i][1], md.slice(start, end));
  }
  return blocks;
}

const oldMd = existsSync(oldPath) ? readFileSync(oldPath, 'utf8') : '';
const newMd = existsSync(newPath) ? readFileSync(newPath, 'utf8') : '';

const oldBlocks = extractVersionBlocks(oldMd);
const newBlocks = extractVersionBlocks(newMd);

const failures = [];
for (const [version, oldBlock] of oldBlocks) {
  if (!newBlocks.has(version)) {
    failures.push(`secao [${version}] presente no arquivo anterior e ausente no novo (versao removida)`);
    continue;
  }
  const newBlock = newBlocks.get(version);
  if (newBlock !== oldBlock) {
    failures.push(`secao [${version}] divergente do arquivo anterior`);
  }
}

if (failures.length) {
  for (const f of failures) console.error(`FAIL released: ${f}`);
  process.exit(1);
}
console.log(`OK released — ${oldBlocks.size} secao(oes) de versao publicada intacta(s)`);
process.exit(0);
