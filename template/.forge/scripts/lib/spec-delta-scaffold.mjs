#!/usr/bin/env node
// spec-delta-scaffold.mjs — gera o ESQUELETO determinista do spec-delta.yaml na fase
// verify (§10.4), fechando o gap "pipeline nunca produz o delta e o archive improvisa".
// A autoria semântica (scenarios reais, tests, add vs modify definitivo) continua sendo
// do agente na sessão de /forge:verify — com o contexto quente da conferência REQ a REQ.
//
// O que É determinista aqui:
//   - extração dos "## REQ-NN — título" do artefato de requirements (requirements.md,
//     bugfix.md ou refactor.md — nos dois últimos raramente há REQ-; sem REQ → SKIP);
//   - capability default = primeira entrada de affected_capabilities do manifest
//     (fallback: o próprio change-id);
//   - requirement_id no padrão do baseline (REQ-<INICIAIS-DA-CAPABILITY>-NN);
//   - op sugerida: modify_requirement se o requirement_id já existe no baseline da
//     capability, add_requirement caso contrário;
//   - cenário: quando a linha "**Quando** X, **o sistema deve** Y" do template de
//     requirements é parseável, vira when/then; o given fica marcado `<scaffold: ...>`.
//
// Marcadores `<scaffold: ...>` (e os placeholders do template, `<capability-kebab>` /
// REQ-XXX-) são BLOQUEANTES no pré-flight do archive (validate-archive) — um esqueleto
// não preenchido nunca chega ao baseline.
//
// Garantias: idempotente e NUNCA sobrescreve um delta já autorado — só (re)escreve se o
// arquivo não existe ou ainda é o placeholder pristino do template do spec-new.
//
// Uso: spec-delta-scaffold.mjs <change-dir> <forge-root>
// Saída: "OK ..." (gerado) | "SKIP (...)" (nada a fazer) | "FAIL (...)" (uso incorreto).
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, resolve, basename } from 'node:path';
import { parseYamlSubset } from './yaml-lite.mjs';

const changeDir = process.argv[2];
const forgeRoot = process.argv[3];
if (!changeDir || !forgeRoot) { console.log('FAIL (usage: spec-delta-scaffold.mjs <change-dir> <forge-root>)'); process.exit(1); }
const dir = resolve(changeDir);
const root = resolve(forgeRoot);
const changeId = basename(dir);
const deltaPath = join(dir, 'spec-delta.yaml');

// nunca sobrescrever autoria real — só arquivo ausente ou placeholder pristino do template
const PRISTINE = /(<capability-kebab>|REQ-XXX-)/;
if (existsSync(deltaPath) && !PRISTINE.test(readFileSync(deltaPath, 'utf8'))) {
  console.log('SKIP (spec-delta.yaml já autorado — não sobrescrevo)');
  process.exit(0);
}

let man = {};
try { man = parseYamlSubset(readFileSync(join(dir, 'manifest.yaml'), 'utf8')); }
catch (e) { console.log(`FAIL (manifest.yaml: ${e.message})`); process.exit(1); }

const REQ_ARTIFACT = { bugfix: 'bugfix.md', refactor: 'refactor.md' };
const reqFile = REQ_ARTIFACT[man.type] || 'requirements.md';
const reqPath = join(dir, reqFile);
if (!existsSync(reqPath)) {
  console.log(`SKIP (${reqFile} ausente — autore spec-delta.yaml à mão se o change altera o baseline)`);
  process.exit(0);
}
const reqText = readFileSync(reqPath, 'utf8');

// "## REQ-01 — Título" (ignora headings ainda com placeholder de template no título)
const reqs = [];
for (const m of reqText.matchAll(/^## (REQ-[A-Za-z0-9-]+)\s+—\s+(.+?)\s*$/gm)) {
  if (m[2].includes('<')) continue;
  reqs.push({ localId: m[1], title: m[2], at: m.index });
}
if (!reqs.length) {
  console.log(`SKIP (nenhum "## REQ-NN — título" extraível de ${reqFile} — autore spec-delta.yaml à mão se o change altera o baseline)`);
  process.exit(0);
}

const capsDeclared = Array.isArray(man.affected_capabilities) ? man.affected_capabilities.filter(Boolean) : [];
const capability = String(capsDeclared[0] || changeId).toLowerCase().replace(/[^a-z0-9-]/g, '-').replace(/^-+|-+$/g, '');
const prefix = capability.split('-').filter(Boolean).map((w) => w[0]).join('').toUpperCase() || 'X';

// baseline da capability (para sugerir modify vs add)
let baselineText = '';
const capSpec = join(root, '.forge/product/current/capabilities', capability, 'spec.yaml');
if (existsSync(capSpec)) baselineText = readFileSync(capSpec, 'utf8');

// cenário a partir da linha canônica do template de requirements, quando parseável
function scenarioFor(req, next) {
  const section = reqText.slice(req.at, next ? next.at : reqText.length);
  const m = section.match(/\*\*Quando\*\*\s*(.+?),\s*\*\*o sistema deve\*\*\s*(.+?)\.?\s*$/m);
  const clean = (s) => s.replace(/[<>]/g, '').trim();
  if (m && !m[1].includes('<') && !m[2].includes('<'))
    return { given: '<scaffold: precondição — preencher na fase verify>', when: clean(m[1]), then: clean(m[2]) };
  return {
    given: '<scaffold: precondição — preencher na fase verify>',
    when: '<scaffold: ação — preencher na fase verify>',
    then: '<scaffold: resultado observável — preencher na fase verify>',
  };
}

const q = (s) => `"${String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
const L = [];
L.push('# Spec delta — GERADO por spec-delta-scaffold.mjs na fase verify (§10.4).');
L.push('# Preencha os payloads (given/when/then reais, tests, op add vs modify) ANTES do');
L.push('# gate do archive — todo marcador de scaffold remanescente bloqueia o pré-flight (§13.1).');
L.push('# modify_requirement é SUBSTITUIÇÃO INTEGRAL — nunca patch parcial.');
if (capsDeclared.length > 1)
  L.push(`# affected_capabilities adicionais (redistribua ops se necessário): ${capsDeclared.slice(1).join(', ')}`);
L.push('operations:');
reqs.forEach((r, i) => {
  const nn = (r.localId.match(/([0-9]+)$/) || [, String(i + 1).padStart(2, '0')])[1];
  const rid = `REQ-${prefix}-${nn}`;
  const op = baselineText.includes(`id: ${rid}`) ? 'modify_requirement' : 'add_requirement';
  const scn = scenarioFor(r, reqs[i + 1]);
  L.push(`  - op: ${op}`);
  L.push(`    capability: ${capability}`);
  L.push(`    requirement_id: ${rid}`);
  L.push(`    ${op === 'modify_requirement' ? 'full_replacement_ref' : 'content_ref'}: ${reqFile}#${r.localId.toLowerCase()}`);
  L.push('    requirement:');
  L.push(`      id: ${rid}`);
  L.push(`      title: ${q(r.title)}`);
  L.push('      normative: SHALL');
  L.push('      scenarios:');
  L.push(`        - id: SCN-${prefix}-${nn}-A`);
  L.push(`          given: ${q(scn.given)}`);
  L.push(`          when: ${q(scn.when)}`);
  L.push(`          then: ${q(scn.then)}`);
  L.push('      contracts: []');
  L.push('      tests: []');
});
writeFileSync(deltaPath, L.join('\n') + '\n');
console.log(`OK spec-delta.yaml scaffold gerado (${reqs.length} op(s), capability ${capability}) — preencha os payloads e valide com validate-spec.sh`);
