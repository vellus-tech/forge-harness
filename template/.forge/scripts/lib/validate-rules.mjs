#!/usr/bin/env node
// forge validate rules (G3 drift detection, GW.2). Zero-dependency. Checks that
// every rule which declares `based_on: [ADR-NNNN, ...]` in its frontmatter is
// anchored to an ADR that (a) exists in the baseline (.forge/product/current/adr/)
// and (b) has Status: accepted. A rule contradicting/orphaned from its ADR is
// DRIFT — the exact failure mode of the pilot incident (a rule that claimed to
// follow an ADR but encoded the opposite decision).
//
// Rules with no `based_on` or `based_on: []` are conventions not tied to a
// specific decision — fine, skipped. The `based_on` mechanism is opt-in per
// project: a fresh template ships no ADRs, so template rules use `based_on: []`.
//
// Usage: validate-rules.mjs <forge-root>
// Output: "OK rules (N anchored, M unanchored)" or "FAIL (<drifts>)".
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';

const root = resolve(process.argv[2] || '.');
const rulesDir = join(root, '.forge/rules');
const adrDir = join(root, '.forge/product/current/adr');
if (!existsSync(rulesDir)) { console.log('OK rules (no rules directory)'); process.exit(0); }

function walk(dir, acc = []) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) walk(p, acc);
    else if (e.name.endsWith('.md') && e.name !== 'README.md') acc.push(p);
  }
  return acc;
}

// index baseline ADRs: number -> { status }
const adrs = new Map();
if (existsSync(adrDir)) {
  for (const f of readdirSync(adrDir)) {
    const m = f.match(/^([0-9]{4})-.*\.md$/);
    if (!m) continue;
    const text = readFileSync(join(adrDir, f), 'utf8');
    const st = text.match(/^[-*]?\s*\**Status:\**\s*([a-zA-Z ]+)/m);
    adrs.set(m[1], { status: st ? st[1].trim().toLowerCase().split(/\s+/)[0] : 'unknown' });
  }
}

const drifts = [];
let anchored = 0, unanchored = 0;

for (const f of walk(rulesDir)) {
  const text = readFileSync(f, 'utf8');
  const fm = text.match(/^---\n([\s\S]*?)\n---/);
  const rel = f.slice(root.length + 1);
  if (!fm) { unanchored++; continue; }
  const bo = fm[1].match(/^based_on:\s*\[([^\]]*)\]/m);
  if (!bo || !bo[1].trim()) { unanchored++; continue; }
  const refs = bo[1].split(',').map((s) => s.trim().replace(/['"]/g, '')).filter(Boolean);
  if (!refs.length) { unanchored++; continue; }
  anchored++;
  for (const ref of refs) {
    const num = ref.replace(/^ADR-/i, '');
    if (!adrs.has(num)) {
      drifts.push(`${rel}: based_on ${ref} — no such ADR in baseline (.forge/product/current/adr/)`);
    } else if (adrs.get(num).status !== 'accepted') {
      drifts.push(`${rel}: based_on ${ref} — ADR is "${adrs.get(num).status}", not accepted (drift)`);
    }
  }
}

if (drifts.length) { console.log(`FAIL (${drifts.join('; ')})`); process.exit(1); }
console.log(`OK rules (${anchored} anchored, ${unanchored} unanchored)`);
