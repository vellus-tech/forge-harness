#!/usr/bin/env bash
# Gate W162 — yaml-lite.mjs passa a entender array em flow style (LDG-0033).
#
# Por que existe: `quick_plan.skipped_phases: [design]` (flow style) virava a STRING literal
# "[design]" em vez de uma lista de um elemento — e `spec-new.sh` grava skipped_phases NESSE
# formato por padrão (`skipped_phases: []`), induzindo o autor exatamente ao formato que o
# parser não entendia. Block style (`- design`) sempre funcionou; só o flow style não vazio
# quebrava. tests/w138-story-shard-guard-gate.sh [11] documentava esse "reprova fechado" como
# comportamento aceito — este gate fecha o defeito na origem (o parser), e w138 [11] muda de
# FAIL-fechado para PASSA (mesmo resultado do bloco style em [10]).
#
#   [1]  reprodução literal do exemplo do ledger: `quick_plan.skipped_phases: [design]` dentro
#        de um documento com indentação real → array de um elemento, NÃO a string "[design]"
#   [2]  âncoras: vazia, um elemento, muitos, elemento com espaço interno, elemento que exige
#        aspas por causa de vírgula, elemento com "#" (não pode virar comentário truncado),
#        valores ambíguos (true/false/null/123/"") que precisam permanecer string
#   [3]  vírgula DENTRO de valor aspeado não separa elementos (o caso clássico que quebra
#        parsers ingênuos de flow-style)
#   [4]  PROPRIEDADE round-trip: para 200 listas geradas com PRNG determinístico (seed fixa),
#        parse(render(x)) devolve x — cobre espaços, vírgulas, tamanhos 0..5 elementos
#   [5]  CONTROLE — `key: []` (vazio) continua funcionando como já funcionava antes (não regride)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/yaml-lite.mjs"
[ -f "$LIB" ]
T="$(mktemp -d /tmp/forge-w162.XXXXXX)"
trap 'rm -rf "$T"' EXIT

echo "[1] reprodução literal do ledger: quick_plan.skipped_phases: [design]"
cat > "$T/check1.mjs" <<EOF
import { parseYamlSubset } from '$LIB';
const doc = parseYamlSubset([
  'quick_plan:',
  '  enabled: true',
  '  skipped_phases: [design]',
  '  justification: "x"',
].join('\n'));
const got = doc.quick_plan.skipped_phases;
if (!Array.isArray(got)) throw new Error('esperado array, obtido ' + JSON.stringify(got) + ' (typeof ' + typeof got + ')');
if (got.length !== 1 || got[0] !== 'design') throw new Error('esperado ["design"], obtido ' + JSON.stringify(got));
console.log('OK');
EOF
node "$T/check1.mjs" | grep -q OK
echo "OK [1]"

echo "[2] âncoras (vazia, um, muitos, espaço interno, vírgula exige aspas, '#', ambíguos)"
cat > "$T/check2.mjs" <<EOF
import { parseYamlSubset } from '$LIB';
function parseList(flowText) {
  const doc = parseYamlSubset('key: ' + flowText);
  return doc.key;
}
function eq(got, want, label) {
  const g = JSON.stringify(got), w = JSON.stringify(want);
  if (g !== w) throw new Error(label + ': esperado ' + w + ', obtido ' + g);
}
eq(parseList('[]'), [], 'vazia');
eq(parseList('[design]'), ['design'], 'um elemento');
eq(parseList('[a, b, c, d]'), ['a', 'b', 'c', 'd'], 'muitos elementos');
eq(parseList('[hello world, x]'), ['hello world', 'x'], 'espaço interno sem aspas');
eq(parseList('["a, b", c]'), ['a, b', 'c'], 'vírgula dentro de string aspeada (elemento único)');
eq(parseList('["a # b", x]'), ['a # b', 'x'], '# dentro de aspas não trunca o elemento nem a lista');
eq(parseList('["true", "false", "null", "123", ""]'), ['true', 'false', 'null', '123', ''], 'ambíguos aspeados permanecem string');
console.log('OK');
EOF
node "$T/check2.mjs" | grep -q OK
echo "OK [2]"

echo "[3] vírgula dentro de valor aspeado não separa elementos (parser ingênuo quebraria aqui)"
cat > "$T/check3.mjs" <<EOF
import { parseYamlSubset } from '$LIB';
const doc = parseYamlSubset('key: ["um, dois", tres, "quatro, cinco, seis"]');
const got = doc.key;
if (!Array.isArray(got) || got.length !== 3) throw new Error('esperado 3 elementos, obtido ' + JSON.stringify(got));
if (got[0] !== 'um, dois') throw new Error('elemento 0: ' + JSON.stringify(got[0]));
if (got[1] !== 'tres') throw new Error('elemento 1: ' + JSON.stringify(got[1]));
if (got[2] !== 'quatro, cinco, seis') throw new Error('elemento 2: ' + JSON.stringify(got[2]));
console.log('OK');
EOF
node "$T/check3.mjs" | grep -q OK
echo "OK [3]"

echo "[4] PROPRIEDADE round-trip: parse(render(x)) === x, 200 listas geradas (seed fixa)"
cat > "$T/check4.mjs" <<EOF
import { parseYamlSubset, yamlFlowList } from '$LIB';

// PRNG determinístico (mulberry32) — sem depender de Math.random, reproduzível entre corridas.
function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rnd = mulberry32(20260904);
// charset deliberadamente sem aspas/backslash: o unescape de aspas embutidas é lacuna
// pré-existente do parser (fora do escopo de LDG-0033, que é sobre flow-style de ARRAY).
const CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ,._-#';
function randString(minLen, maxLen) {
  const len = minLen + Math.floor(rnd() * (maxLen - minLen + 1));
  let s = '';
  for (let i = 0; i < len; i++) s += CHARS[Math.floor(rnd() * CHARS.length)];
  return s;
}
function randList(n) {
  const out = [];
  for (let i = 0; i < n; i++) out.push(randString(1, 12));
  return out;
}

const failures = [];
function check(label, arr) {
  const rendered = yamlFlowList(arr);
  const doc = parseYamlSubset('key: ' + rendered);
  const got = doc.key;
  const ok = Array.isArray(got) && got.length === arr.length && got.every((v, i) => v === arr[i]);
  if (!ok) failures.push({ label, arr, rendered, got });
}

check('vazia', []);
check('um elemento', ['design']);
check('muitos elementos', ['a', 'b', 'c', 'd', 'e']);
check('com espaços internos', ['hello world', 'a b c']);
check('elemento que exige aspas (vírgula)', ['a, b']);
check('vírgula dentro de string aspeada + mais elementos', ['a, b', 'c', 'd, e, f']);
check('valores ambíguos que precisam virar string quoted', ['true', 'false', 'null', '123', '']);
check('espaço líder/final preservado só se aspeado', [' leading', 'trailing ', '  both  ']);
check('# não pode truncar (stripTrailingComment)', ['a # b', 'x']);

for (let i = 0; i < 200; i++) {
  const n = Math.floor(rnd() * 6); // 0..5 elementos
  check('pbt#' + i, randList(n));
}

if (failures.length) {
  console.error('FAIL round-trip: ' + failures.length + ' de ' + (9 + 200) + ' casos falharam');
  for (const f of failures.slice(0, 8)) console.error(JSON.stringify(f));
  process.exit(1);
}
console.log('OK ' + (9 + 200) + ' casos round-trip');
EOF
node "$T/check4.mjs"
echo "OK [4]"

echo "[5] CONTROLE — key: [] (vazio) continua funcionando (não regride)"
cat > "$T/check5.mjs" <<EOF
import { parseYamlSubset } from '$LIB';
const doc = parseYamlSubset('affected_capabilities: []');
if (!Array.isArray(doc.affected_capabilities) || doc.affected_capabilities.length !== 0)
  throw new Error('esperado [], obtido ' + JSON.stringify(doc.affected_capabilities));
console.log('OK');
EOF
node "$T/check5.mjs" | grep -q OK
echo "OK [5]"

echo "PASS w162-yaml-lite-flow-array-gate"
