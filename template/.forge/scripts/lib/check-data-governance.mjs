#!/usr/bin/env node
// forge check data-governance (G4 enforcement, GW.3). Zero-dependency. Scans
// markdown artifacts (a change dir, or given files) for declarations that
// CONTRADICT the global data-governance matrix (rules/data/data-governance.md) —
// the per-module divergence that caused the pilot incident. Deterministic grep
// of known anti-patterns; reports CONFLICT findings (file:line + why).
//
// This is a guardrail for the literal incident pattern (a module declaring
// "RLS opcional"/"sem RLS" against the mandatory-RLS decision). It complements,
// not replaces, the human/LLM cross-artifact analysis (/forge:analyze).
//
// Usage: check-data-governance.mjs <change-dir|file> [...more files]
// Output: "OK data-governance (no divergence)" or "CONFLICT (<findings>)" (exit 1).
import { readFileSync, existsSync, statSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';

const inputs = process.argv.slice(2);
if (!inputs.length) { console.log('OK data-governance (nothing to check)'); process.exit(0); }

function collect(p, acc = []) {
  const rp = resolve(p);
  if (!existsSync(rp)) return acc;
  if (statSync(rp).isDirectory()) {
    for (const e of readdirSync(rp, { withFileTypes: true })) {
      if (e.isDirectory()) collect(join(rp, e.name), acc);
      else if (e.name.endsWith('.md')) acc.push(join(rp, e.name));
    }
  } else if (rp.endsWith('.md')) acc.push(rp);
  return acc;
}

// anti-patterns vs the global matrix. Each: { re, why, allow } — allow skips a
// match when the same line carries an allowed qualifier (e.g. formal exception).
const ANTI = [
  { re: /\bsem\s+RLS\b/i, why: 'declara "sem RLS" — matriz exige RLS p/ tabelas multi-tenant de domínio (SQL)', allow: /exceção\s+formal|exception/i },
  { re: /RLS\s+(é\s+)?opcional/i, why: 'declara RLS opcional — matriz: RLS obrigatório, dispensa só por exceção formal', allow: /exceção\s+formal/i },
  { re: /RLS\s+optional/i, why: 'declares RLS optional — matrix: RLS mandatory, waivable only by formal exception', allow: /formal\s+exception/i },
  { re: /RLS\s+não\s+(é\s+)?obrigat/i, why: 'declara RLS não obrigatório — contradiz a matriz', allow: /exceção\s+formal/i },
  { re: /cache\b[^\n]*\bsem\s+(namespace|prefixo)\s+(de\s+)?tenant/i, why: 'cache sem namespace de tenant — vetor de vazamento cross-tenant', allow: /(?!)/ },
];

const findings = [];
for (const f of inputs.flatMap((i) => collect(i))) {
  const rel = f.includes('/specs/active/') ? f.slice(f.indexOf('/specs/active/') + 1) : f;
  const lines = readFileSync(f, 'utf8').split('\n');
  lines.forEach((line, i) => {
    for (const a of ANTI) {
      if (a.re.test(line) && !a.allow.test(line)) findings.push(`${rel}:${i + 1}: ${a.why}`);
    }
  });
}

if (findings.length) {
  console.log(`CONFLICT (${findings.join('; ')})`);
  process.exit(1);
}
console.log('OK data-governance (no divergence)');
