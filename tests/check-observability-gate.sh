#!/usr/bin/env bash
# Gate — check-observability (TASK-15 do change security-observability-gates, design.md
# §2.2, REQ-09/10, REQ-16). Zero-dependência (NFR-01). Prova os três sub-checks + o
# contrato comum warn|enforce (gate-mode):
#   [1] lib existe (check-observability.mjs + check-observability.sh)
#   [2] REQ-09b (unidade): logger cru fora do wrapper_paths → finding; mesmo padrão
#       DENTRO do wrapper_paths → excluído (não é violação, é a implementação do wrapper)
#   [3] REQ-09b (unidade): logger estruturado (sem match na matriz ANTI) → sem finding
#   [4] REQ-10 (unidade): validateAlertsAsCode — artefato válido vs inválido (schema)
#   [5] REQ-09a (unidade, via checkObservability): boundary SEM caminho ao otel-wrapper
#       declarado → finding nomeando o boundary; COM caminho → sem finding
#   [6] REQ-10 (unidade, via checkObservability): boundary sem alerts-as-code → finding
#       nomeando o serviço; com artefato válido cobrindo o serviço → sem finding
#   [7] gate-mode: mode:warn rebaixa (WARN, exit 0); mode:enforce bloqueia (CONFLICT, exit 1)
#   [8] end-to-end (.sh + fixtures/observability/pass) → OK, exit 0
#   [9] end-to-end (.sh + fixtures/observability/fail, mode:enforce) → CONFLICT, exit 1,
#       nomeando boundary (REQ-09a), fmt.Println (REQ-09b) e serviço (REQ-10)
#   [10] end-to-end (.sh + fixtures/observability/fail, mode:warn) → WARN, exit 0
#   [11] sem graph.json → REQ-09a/REQ-10 em no-op; REQ-09b roda do mesmo jeito (varredura textual)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/check-observability.mjs"
SH="$WS/template/.forge/scripts/check-observability.sh"
FIX="$WS/tests/fixtures/observability"
[ -f "$LIB" ]
[ -f "$SH" ]
T="$(mktemp -d /tmp/forge-observability.XXXXXX)"
trap 'rm -rf "$T"' EXIT

echo "OK [1] lib e script existem"

echo "[2] REQ-09b: logger cru fora do wrapper → finding; dentro do wrapper_paths → excluído"
mkdir -p "$T/case2/services/orders/api" "$T/case2/packages/otel"
cat > "$T/case2/services/orders/api/handler.go" <<'EOF'
package api
import "fmt"
func Handler() { fmt.Println("cru") }
EOF
cat > "$T/case2/packages/otel/wrap.go" <<'EOF'
package otel
import "fmt"
func sink(m string) { fmt.Println(m) }
EOF
cat > "$T/check2.mjs" <<EOF
import { checkRawLoggers } from '$LIB';
const root = '$T/case2';
const found = checkRawLoggers([root], { root, wrapperPaths: ['packages/otel'] });
if (found.length !== 1) throw new Error('esperado 1 finding (fora do wrapper), obtido ' + JSON.stringify(found));
if (!found[0].why.includes('services/orders/api/handler.go')) throw new Error('finding nao nomeia o arquivo: ' + found[0].why);
if (!found[0].why.includes('fmt.Println')) throw new Error('why nao menciona fmt.Println: ' + found[0].why);
if (found[0].enforceable !== false) throw new Error('REQ-09b deveria ser rebaixavel (enforceable:false)');
console.log('OK');
EOF
node "$T/check2.mjs" | grep -q OK
echo "OK [2]"

echo "[3] REQ-09b: logger estruturado (sem match na matriz ANTI) → sem finding"
mkdir -p "$T/case3/services/orders/api"
cat > "$T/case3/services/orders/api/handler.go" <<'EOF'
package api
func Handler() { logger.Info("order created") }
EOF
cat > "$T/check3.mjs" <<EOF
import { checkRawLoggers } from '$LIB';
const root = '$T/case3';
const found = checkRawLoggers([root], { root, wrapperPaths: [] });
if (found.length !== 0) throw new Error('esperado 0 findings, obtido ' + JSON.stringify(found));
console.log('OK');
EOF
node "$T/check3.mjs" | grep -q OK
echo "OK [3]"

echo "[4] REQ-10: validateAlertsAsCode — válido vs inválido"
cat > "$T/check4.mjs" <<EOF
import { validateAlertsAsCode } from '$LIB';
const valid = { service: 'services/orders', alerts: [ { name: 'lat', expr: 'up', severity: 'warning', for: '5m' } ] };
if (validateAlertsAsCode(valid).length !== 0) throw new Error('esperado valido, erros: ' + JSON.stringify(validateAlertsAsCode(valid)));
const noAlerts = { service: 'services/orders', alerts: [] };
if (validateAlertsAsCode(noAlerts).length === 0) throw new Error('esperado invalido (alerts vazio)');
const badSeverity = { service: 'services/orders', alerts: [ { name: 'lat', expr: 'up', severity: 'bogus', for: '5m' } ] };
if (validateAlertsAsCode(badSeverity).length === 0) throw new Error('esperado invalido (severity)');
const badFor = { service: 'services/orders', alerts: [ { name: 'lat', expr: 'up', severity: 'info', for: 'five-minutes' } ] };
if (validateAlertsAsCode(badFor).length === 0) throw new Error('esperado invalido (for)');
const noService = { alerts: [ { name: 'lat', expr: 'up', severity: 'info', for: '5m' } ] };
if (validateAlertsAsCode(noService).length === 0) throw new Error('esperado invalido (sem service)');
console.log('OK');
EOF
node "$T/check4.mjs" | grep -q OK
echo "OK [4]"

echo "[5] REQ-09a (via checkObservability): boundary sem caminho ao otel-wrapper → finding; com caminho → sem finding"
mkdir -p "$T/case5/.forge/graph"
cat > "$T/case5/.forge/graph/graph.json" <<'EOF'
{
  "nodes": [
    { "id": "services/orders/api/handler.go", "layer": "api" },
    { "id": "packages/otel/wrap.go", "layer": "infrastructure", "roles": ["otel-wrapper"] }
  ],
  "edges": [],
  "governance": { "observability": { "wrapper_paths": ["packages/otel"], "allowlist": [], "mode": "enforce" } }
}
EOF
cat > "$T/check5.mjs" <<EOF
import { checkObservability } from '$LIB';
const root = '$T/case5';
const r1 = checkObservability([root], { root });
const req09a = r1.blocking.filter((f) => f.subcheck === 'REQ-09a');
if (req09a.length !== 1 || req09a[0].target !== 'services/orders/api/handler.go') {
  throw new Error('esperado finding REQ-09a nomeando o boundary, obtido ' + JSON.stringify(req09a));
}
console.log('OK sem caminho');
EOF
node "$T/check5.mjs" | grep -q 'OK sem caminho'
# agora com edge resolvido até o wrapper
cat > "$T/case5/.forge/graph/graph.json" <<'EOF'
{
  "nodes": [
    { "id": "services/orders/api/handler.go", "layer": "api" },
    { "id": "packages/otel/wrap.go", "layer": "infrastructure", "roles": ["otel-wrapper"] }
  ],
  "edges": [ { "from": "services/orders/api/handler.go", "to": "packages/otel/wrap.go", "resolved": true } ],
  "governance": { "observability": { "wrapper_paths": ["packages/otel"], "allowlist": [], "mode": "enforce" } }
}
EOF
cat > "$T/check5b.mjs" <<EOF
import { checkObservability } from '$LIB';
const root = '$T/case5';
const r2 = checkObservability([root], { root });
const req09a = r2.blocking.filter((f) => f.subcheck === 'REQ-09a').concat(r2.warnings.filter((f) => f.subcheck === 'REQ-09a'));
if (req09a.length !== 0) throw new Error('esperado 0 findings REQ-09a (caminho existe), obtido ' + JSON.stringify(req09a));
console.log('OK com caminho');
EOF
node "$T/check5b.mjs" | grep -q 'OK com caminho'
echo "OK [5]"

echo "[6] REQ-10 (via checkObservability): boundary sem alerts-as-code → finding nomeando o servico; com artefato valido → sem finding"
mkdir -p "$T/case6/.forge/graph" "$T/case6/alerts"
cat > "$T/case6/.forge/graph/graph.json" <<'EOF'
{
  "nodes": [ { "id": "services/orders/api/handler.go", "layer": "api" } ],
  "edges": [],
  "governance": { "observability": { "wrapper_paths": [], "allowlist": [], "mode": "enforce" } }
}
EOF
cat > "$T/check6.mjs" <<EOF
import { checkObservability } from '$LIB';
const root = '$T/case6';
const r1 = checkObservability([root], { root });
const req10 = r1.blocking.filter((f) => f.subcheck === 'REQ-10');
if (req10.length !== 1 || req10[0].target !== 'services/orders') {
  throw new Error('esperado finding REQ-10 nomeando "services/orders", obtido ' + JSON.stringify(req10));
}
console.log('OK sem alerts');
EOF
node "$T/check6.mjs" | grep -q 'OK sem alerts'
cat > "$T/case6/alerts/orders.json" <<'EOF'
{ "service": "services/orders", "alerts": [ { "name": "lat", "expr": "up", "severity": "warning", "for": "5m" } ] }
EOF
cat > "$T/check6b.mjs" <<EOF
import { checkObservability } from '$LIB';
const root = '$T/case6';
const r2 = checkObservability([root], { root });
const req10 = r2.blocking.filter((f) => f.subcheck === 'REQ-10').concat(r2.warnings.filter((f) => f.subcheck === 'REQ-10'));
if (req10.length !== 0) throw new Error('esperado 0 findings REQ-10 (artefato valido presente), obtido ' + JSON.stringify(req10));
console.log('OK com alerts');
EOF
node "$T/check6b.mjs" | grep -q 'OK com alerts'
echo "OK [6]"

echo "[7] gate-mode: mode:warn rebaixa (exit 0, warnings); mode:enforce bloqueia (exit != 0, blocking)"
cat > "$T/check7.mjs" <<EOF
import { checkObservability } from '$LIB';
const root = '$T/case6'; // sem alerts.json de novo? nao, ainda tem — recriar cenario isolado abaixo
EOF
mkdir -p "$T/case7/.forge/graph"
cat > "$T/case7/.forge/graph/graph.json" <<'EOF'
{
  "nodes": [ { "id": "services/orders/api/handler.go", "layer": "api" } ],
  "edges": [],
  "governance": { "observability": { "wrapper_paths": [], "allowlist": [], "mode": "warn" } }
}
EOF
cat > "$T/check7.mjs" <<EOF
import { checkObservability } from '$LIB';
const root = '$T/case7';
const rWarn = checkObservability([root], { root });
if (rWarn.exitCode !== 0) throw new Error('mode:warn deveria sair 0, obtido ' + rWarn.exitCode);
if (rWarn.warnings.length === 0) throw new Error('mode:warn deveria ter warnings (REQ-10 rebaixavel)');
console.log('OK warn');
EOF
node "$T/check7.mjs" | grep -q 'OK warn'
sed -i.bak 's/"mode": "warn"/"mode": "enforce"/' "$T/case7/.forge/graph/graph.json"
cat > "$T/check7b.mjs" <<EOF
import { checkObservability } from '$LIB';
const root = '$T/case7';
const rEnf = checkObservability([root], { root });
if (rEnf.exitCode === 0) throw new Error('mode:enforce deveria sair != 0');
if (rEnf.blocking.length === 0) throw new Error('mode:enforce deveria ter blocking');
console.log('OK enforce');
EOF
node "$T/check7b.mjs" | grep -q 'OK enforce'
echo "OK [7]"

echo "[8] end-to-end (.sh): fixtures/observability/pass → OK, exit 0"
set +e
out="$(FORGE_ROOT="$FIX/pass" bash "$SH" --path "$FIX/pass")"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "esperado exit 0, obtido $rc — saida: $out"; exit 1; }
echo "$out" | grep -q '^OK check-observability' || { echo "esperado OK, obtido: $out"; exit 1; }
echo "OK [8]"

echo "[9] end-to-end (.sh): fixtures/observability/fail (mode:enforce) → CONFLICT, exit 1"
set +e
out="$(FORGE_ROOT="$FIX/fail" bash "$SH" --path "$FIX/fail")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "esperado exit != 0, obtido 0 — saida: $out"; exit 1; }
echo "$out" | grep -q 'CONFLICT' || { echo "esperado CONFLICT, obtido: $out"; exit 1; }
echo "$out" | grep -q 'services/orders/api/handler.go\|services/orders/api/refund.go' || { echo "CONFLICT nao nomeia o boundary (REQ-09a): $out"; exit 1; }
echo "$out" | grep -q 'fmt.Println' || { echo "CONFLICT nao menciona fmt.Println (REQ-09b): $out"; exit 1; }
echo "$out" | grep -q 'services/orders' || { echo "CONFLICT nao nomeia o servico (REQ-10): $out"; exit 1; }
echo "OK [9]"

echo "[10] end-to-end (.sh): fixtures/observability/fail (mode:warn) → WARN, exit 0"
cp -R "$FIX/fail" "$T/fail-warn"
sed -i.bak 's/"mode": "enforce"/"mode": "warn"/' "$T/fail-warn/.forge/graph/graph.json"
set +e
out="$(FORGE_ROOT="$T/fail-warn" bash "$SH" --path "$T/fail-warn")"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "esperado exit 0 em mode:warn, obtido $rc — saida: $out"; exit 1; }
echo "$out" | grep -q '^WARN' || { echo "esperado WARN, obtido: $out"; exit 1; }
echo "OK [10]"

echo "[11] sem graph.json: REQ-09a/REQ-10 em no-op; REQ-09b roda do mesmo jeito (achado rebaixavel, default seguro mode:warn sem bloco declarado)"
mkdir -p "$T/case11/services/orders/api"
cat > "$T/case11/services/orders/api/handler.go" <<'EOF'
package api
import "fmt"
func Handler() { fmt.Println("cru sem grafo") }
EOF
set +e
out="$(FORGE_ROOT="$T/case11" bash "$SH" --path "$T/case11")"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "esperado exit 0 (sem bloco declarado -> default seguro mode:warn), obtido $rc — saida: $out"; exit 1; }
echo "$out" | grep -q '^WARN' || { echo "esperado WARN, obtido: $out"; exit 1; }
echo "$out" | grep -q 'fmt.Println' || { echo "esperado REQ-09b mesmo sem grafo: $out"; exit 1; }
echo "$out" | grep -q 'caminho (import\|alerts-as-code' && { echo "REQ-09a/REQ-10 nao deveriam aparecer sem graph.json: $out"; exit 1; } || true
echo "OK [11]"

echo "OK"
