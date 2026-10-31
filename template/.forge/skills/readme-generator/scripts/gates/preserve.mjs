#!/usr/bin/env node
// preserve.mjs — gate: nenhum bloco (entrada de lista sob um "### <Secao>") do arquivo anterior
// pode desaparecer no arquivo novo sem substituto. Escrever um CHANGELOG novo não pode apagar
// história — só adicionar.
//
// Uso: preserve.mjs <changelog-antigo> <changelog-novo>
// Saída: "OK ..." / "FAIL preserve: ...", rc 0/1.
import { readFileSync, existsSync } from 'node:fs';

const [, , oldPath, newPath] = process.argv;
if (!oldPath || !newPath) {
  console.error('Uso: preserve.mjs <changelog-antigo> <changelog-novo>');
  process.exit(2);
}

// Extrai um mapa "<versao>|<secao>" -> Set(linhas de bullet) do markdown. <versao> é o texto do
// cabeçalho "## ..." mais próximo acima (ou "" se nenhum ainda apareceu); <secao> é o texto do
// "### ..." mais próximo acima dentro do mesmo bloco de versão.
function extractSections(md) {
  const map = new Map();
  let currentVersion = '';
  let currentSection = '';
  for (const line of md.split('\n')) {
    const h2 = line.match(/^##\s+(.+)$/);
    if (h2) { currentVersion = h2[1].trim(); currentSection = ''; continue; }
    const h3 = line.match(/^###\s+(.+)$/);
    if (h3) { currentSection = h3[1].trim(); continue; }
    const bullet = line.match(/^-\s+(.+)$/);
    if (bullet && currentSection) {
      const key = `${currentVersion}|${currentSection}`;
      if (!map.has(key)) map.set(key, new Set());
      map.get(key).add(bullet[1].trim());
    }
  }
  return map;
}

const oldMd = existsSync(oldPath) ? readFileSync(oldPath, 'utf8') : '';
const newMd = existsSync(newPath) ? readFileSync(newPath, 'utf8') : '';

const oldSections = extractSections(oldMd);
const newSections = extractSections(newMd);

const failures = [];
for (const [key, oldLines] of oldSections) {
  const newLines = newSections.get(key) || new Set();
  for (const line of oldLines) {
    if (!newLines.has(line)) {
      failures.push(`bloco removido sem substituto em "${key}": "${line}"`);
    }
  }
}

if (failures.length) {
  for (const f of failures) console.error(`FAIL preserve: ${f}`);
  process.exit(1);
}
console.log(`OK preserve — ${oldSections.size} bloco(s) do arquivo anterior preservado(s)`);
process.exit(0);
