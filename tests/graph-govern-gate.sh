#!/usr/bin/env bash
# Gate — graph-govern: motor interno de reachability rota layer:api → roles:pep /
# roles:otel-wrapper (TASK-12 do change security-observability-gates, design §2.3).
# Biblioteca pura (sem CLI própria) — exercitada isoladamente via import direto,
# igual ao molde de yaml-lite-gate.sh. NÃO é declarada na chave `gates:` do FORGE.md.
#   [1] rota com caminho (direto) ao PEP → sem finding
#   [2] rota SEM caminho ao PEP → finding nomeando o arquivo
#   [3] caminho TRANSITIVO (api -> application -> pep) também conta como alcançado
#   [4] rota na allowlist → isenta mesmo sem caminho
#   [5] graph sem bloco governance.authz/observability → no-op (checked=false)
#   [6] REQ-09a: mesmo motor, role otel-wrapper, via govern() consumindo graph.governance
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/graph-govern.mjs"
[ -f "$LIB" ]
T="$(mktemp -d /tmp/forge-govern.XXXXXX)"
trap 'rm -rf "$T"' EXIT

echo "[1] rota com caminho direto ao PEP → sem finding"
cat > "$T/check1.mjs" <<EOF
import { checkRole } from '$LIB';
const graph = {
  nodes: [
    { id: 'services/orders/api/handler.ts', layer: 'api' },
    { id: 'packages/pep/check.ts', layer: 'infrastructure', roles: ['pep'] },
  ],
  edges: [
    { from: 'services/orders/api/handler.ts', to: 'packages/pep/check.ts', resolved: true },
  ],
};
const block = { allowlist: [] };
const r = checkRole(graph, block, 'pep');
if (!r.checked) throw new Error('esperado checked=true');
if (r.findings.length !== 0) throw new Error('esperado 0 findings, obtido ' + JSON.stringify(r.findings));
console.log('OK');
EOF
node "$T/check1.mjs" | grep -q OK
echo "OK [1]"

echo "[2] rota SEM caminho ao PEP → finding nomeando o arquivo"
cat > "$T/check2.mjs" <<EOF
import { checkRole } from '$LIB';
const graph = {
  nodes: [
    { id: 'services/orders/api/handler.ts', layer: 'api' },
    { id: 'packages/pep/check.ts', layer: 'infrastructure', roles: ['pep'] },
  ],
  edges: [],
};
const r = checkRole(graph, { allowlist: [] }, 'pep');
if (!r.checked) throw new Error('esperado checked=true');
if (r.findings.length !== 1 || r.findings[0] !== 'services/orders/api/handler.ts') {
  throw new Error('esperado finding nomeando o arquivo, obtido ' + JSON.stringify(r.findings));
}
console.log('OK');
EOF
node "$T/check2.mjs" | grep -q OK
echo "OK [2]"

echo "[3] caminho transitivo (api -> application -> pep) conta como alcançado; só edges resolved:true"
cat > "$T/check3.mjs" <<EOF
import { checkRole } from '$LIB';
const graph = {
  nodes: [
    { id: 'services/orders/api/handler.ts', layer: 'api' },
    { id: 'services/orders/application/authorize.ts', layer: 'application' },
    { id: 'packages/pep/check.ts', layer: 'infrastructure', roles: ['pep'] },
    { id: 'packages/red-herring/x.ts', layer: 'infrastructure' },
  ],
  edges: [
    { from: 'services/orders/api/handler.ts', to: 'services/orders/application/authorize.ts', resolved: true },
    { from: 'services/orders/application/authorize.ts', to: 'packages/pep/check.ts', resolved: true },
    // edge não resolvida não deve contar como caminho
    { from: 'services/orders/api/handler.ts', to: 'packages/red-herring/x.ts', resolved: false },
  ],
};
const r = checkRole(graph, { allowlist: [] }, 'pep');
if (r.findings.length !== 0) throw new Error('esperado alcançável transitivamente, obtido ' + JSON.stringify(r.findings));
console.log('OK');
EOF
node "$T/check3.mjs" | grep -q OK
echo "OK [3]"

echo "[4] rota na allowlist → isenta mesmo sem caminho"
cat > "$T/check4.mjs" <<EOF
import { checkRole } from '$LIB';
const graph = {
  nodes: [
    { id: 'services/health/index.ts', layer: 'api' },
    { id: 'packages/pep/check.ts', layer: 'infrastructure', roles: ['pep'] },
  ],
  edges: [],
};
const r = checkRole(graph, { allowlist: ['services/health'] }, 'pep');
if (r.findings.length !== 0) throw new Error('esperado allowlist isenta, obtido ' + JSON.stringify(r.findings));
console.log('OK');
EOF
node "$T/check4.mjs" | grep -q OK
echo "OK [4]"

echo "[5] graph sem governance.authz/observability → no-op (checked=false, sem falso-positivo)"
cat > "$T/check5.mjs" <<EOF
import { govern } from '$LIB';
const graph = {
  nodes: [ { id: 'services/orders/api/handler.ts', layer: 'api' } ],
  edges: [],
};
const g = govern(graph);
if (g.authz.checked !== false || g.authz.findings.length !== 0) throw new Error('authz deveria ser no-op');
if (g.observability.checked !== false || g.observability.findings.length !== 0) throw new Error('observability deveria ser no-op');
console.log('OK');
EOF
node "$T/check5.mjs" | grep -q OK
echo "OK [5]"

echo "[6] REQ-09a: role otel-wrapper via govern() consumindo graph.governance"
cat > "$T/check6.mjs" <<EOF
import { govern } from '$LIB';
const graphOk = {
  governance: { authz: { allowlist: [] }, observability: { allowlist: [] } },
  nodes: [
    { id: 'services/orders/api/handler.ts', layer: 'api' },
    { id: 'packages/otel/wrap.ts', layer: 'infrastructure', roles: ['otel-wrapper'] },
  ],
  edges: [
    { from: 'services/orders/api/handler.ts', to: 'packages/otel/wrap.ts', resolved: true },
  ],
};
const rOk = govern(graphOk);
if (rOk.observability.findings.length !== 0) throw new Error('esperado wrapper alcançado');

const graphFail = {
  governance: { observability: { allowlist: [] } },
  nodes: [
    { id: 'services/orders/api/handler.ts', layer: 'api' },
    { id: 'packages/otel/wrap.ts', layer: 'infrastructure', roles: ['otel-wrapper'] },
  ],
  edges: [],
};
const rFail = govern(graphFail);
if (rFail.observability.findings.length !== 1 || rFail.observability.findings[0] !== 'services/orders/api/handler.ts') {
  throw new Error('esperado finding do boundary sem wrapper, obtido ' + JSON.stringify(rFail.observability.findings));
}
if (rFail.authz.checked !== false) throw new Error('authz ausente deveria ser no-op mesmo com observability presente');
console.log('OK');
EOF
node "$T/check6.mjs" | grep -q OK
echo "OK [6]"

echo "OK"
