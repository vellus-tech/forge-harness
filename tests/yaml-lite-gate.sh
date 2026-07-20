#!/usr/bin/env bash
# Gate — yaml-lite: parseScalar ganha strip de comentário final de linha (" #…")
# fora de aspas (TASK-02 do change security-observability-gates, design §2.3).
#   [1] "mode: warn # comentário" → "warn" (comentário removido)
#   [2] valor entre aspas com "#" interno preservado ("a # b")
#   [3] "#fff"/"#tag" sem espaço antes preservados (não é comentário)
#   [4] documento completo (parseYamlSubset) com bloco authz: + comentários finais
#       em runtime: — não regride nem o bloco existente nem o novo
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/yaml-lite.mjs"
[ -f "$LIB" ]
T="$(mktemp -d /tmp/forge-yaml-lite.XXXXXX)"
trap 'rm -rf "$T"' EXIT

echo "[1] strip de comentário final fora de aspas"
cat > "$T/check1.mjs" <<EOF
import { parseScalar } from '$LIB';
const v = parseScalar(' warn # comentário');
if (v !== 'warn') throw new Error('esperado "warn", obtido ' + JSON.stringify(v));
console.log('OK');
EOF
node "$T/check1.mjs" | grep -q OK
echo "OK [1]"

echo "[2] '#' dentro de aspas preservado (não regride)"
cat > "$T/check2.mjs" <<EOF
import { parseScalar } from '$LIB';
const v = parseScalar(' "a # b"');
if (v !== 'a # b') throw new Error('esperado "a # b", obtido ' + JSON.stringify(v));
console.log('OK');
EOF
node "$T/check2.mjs" | grep -q OK
echo "OK [2]"

echo "[3] '#fff'/'#tag' sem espaço antes preservados"
cat > "$T/check3.mjs" <<EOF
import { parseScalar } from '$LIB';
const a = parseScalar(' #fff');
const b = parseScalar(' #tag');
if (a !== '#fff') throw new Error('esperado "#fff", obtido ' + JSON.stringify(a));
if (b !== '#tag') throw new Error('esperado "#tag", obtido ' + JSON.stringify(b));
console.log('OK');
EOF
node "$T/check3.mjs" | grep -q OK
echo "OK [3]"

echo "[4] documento completo — bloco authz: + comentário final em runtime: sem regressão"
cat > "$T/check4.mjs" <<EOF
import { parseYamlSubset } from '$LIB';
const text = [
  'runtime:',
  '  gates: check-authz,check-observability # gates ativos',
  'authz:',
  '  pep_paths:',
  '    - services/*/internal/authz',
  '  mode: warn # rebaixável',
  '  policy_coverage_threshold: 0.8',
].join('\\n');
const doc = parseYamlSubset(text);
if (doc.runtime.gates !== 'check-authz,check-observability') throw new Error('runtime.gates: ' + JSON.stringify(doc.runtime.gates));
if (doc.authz.mode !== 'warn') throw new Error('authz.mode: ' + JSON.stringify(doc.authz.mode));
if (doc.authz.policy_coverage_threshold !== '0.8') throw new Error('threshold: ' + JSON.stringify(doc.authz.policy_coverage_threshold));
if (!Array.isArray(doc.authz.pep_paths) || doc.authz.pep_paths[0] !== 'services/*/internal/authz') throw new Error('pep_paths: ' + JSON.stringify(doc.authz.pep_paths));
console.log('OK');
EOF
node "$T/check4.mjs" | grep -q OK
echo "OK [4]"

echo "OK"
