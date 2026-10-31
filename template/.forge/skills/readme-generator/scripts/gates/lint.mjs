#!/usr/bin/env node
// lint.mjs — gate de higiene de prosa nas entradas (linhas "- ...") de um CHANGELOG.md.
// Checagens: travessão, quebra de linha dentro de parágrafo, acentuação ASCII (palavra comum
// grafada sem o acento devido), placeholder, link markdown quebrado.
//
// Uso: lint.mjs <changelog>
// Saída: "OK ..." / "FAIL lint: ...", rc 0/1.
import { readFileSync, existsSync } from 'node:fs';

const [, , path] = process.argv;
if (!path) {
  console.error('Uso: lint.mjs <changelog>');
  process.exit(2);
}
if (!existsSync(path)) {
  console.error(`FAIL lint: arquivo nao encontrado: ${path}`);
  process.exit(2);
}

const md = readFileSync(path, 'utf8');
const lines = md.split('\n');
const failures = [];

// Palavras comuns em pt-BR que, grafadas sem acento (forma ASCII), indicam perda de acentuação.
const ASCII_WORDS = [
  'nao', 'sao', 'entao', 'estao', 'codigo', 'voce', 'esta', 'ja', 'funcao', 'opcao', 'secao',
  'informacao', 'configuracao', 'implementacao', 'validacao', 'atraves', 'possivel', 'tambem',
  'usuario', 'pagina', 'historico', 'exemplo', 'numero', 'ultima', 'ultimo', 'proprio', 'propria',
];
const ASCII_RE = new RegExp(`\\b(${ASCII_WORDS.join('|')})\\b`, 'i');

const PLACEHOLDER_RE = /\b(TODO|FIXME|XXX|TBD|<placeholder>)\b/i;
const BROKEN_LINK_RE = /\[[^\]]*\]\(\s*\)/; // [texto]() — url vazia

let inBullet = false;
for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  const bullet = line.match(/^-\s+(.+)$/);
  if (bullet) {
    const text = bullet[1];
    if (/[—–]/.test(text)) {
      failures.push(`linha ${i + 1}: travessao encontrado — "${text.trim()}"`);
    }
    if (ASCII_RE.test(text)) {
      const m = text.match(ASCII_RE);
      failures.push(`linha ${i + 1}: acentuacao ausente ("${m[0]}") — "${text.trim()}"`);
    }
    if (PLACEHOLDER_RE.test(text)) {
      failures.push(`linha ${i + 1}: placeholder encontrado — "${text.trim()}"`);
    }
    if (BROKEN_LINK_RE.test(text)) {
      failures.push(`linha ${i + 1}: link markdown quebrado (url vazia) — "${text.trim()}"`);
    }
    inBullet = true;
    continue;
  }
  // Quebra de linha dentro de parágrafo: uma linha não vazia, que não é bullet/heading/branco,
  // imediatamente após uma linha de bullet — indica hard-wrap manual no meio da frase.
  const isBlankOrStructural = /^\s*$/.test(line) || /^#/.test(line) || /^-\s/.test(line);
  if (inBullet && !isBlankOrStructural) {
    failures.push(`linha ${i + 1}: quebra de linha dentro de paragrafo — "${line.trim()}"`);
  }
  if (!isBlankOrStructural) inBullet = false;
  if (/^\s*$/.test(line)) inBullet = false;
}

if (failures.length) {
  for (const f of failures) console.error(`FAIL lint: ${f}`);
  process.exit(1);
}
console.log('OK lint — sem travessao, quebra de linha indevida, acentuacao ascii, placeholder ou link quebrado');
process.exit(0);
