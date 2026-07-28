#!/usr/bin/env bash
# Gate — check-authz (TASK-14, REQ-05/06/07/08, design.md §2.2 "Os três gates").
# Zero-dependência. Prova os quatro sub-checks contra fixtures de código real:
#   [1] REQ-05 deny-by-default presente (.rego) → PASS
#   [2] REQ-05 "default allow := true" → FAIL nomeando o arquivo, mesmo em mode:warn (inegociável)
#   [3] REQ-05 sem "default allow := false" → FAIL nomeando o arquivo (inegociável)
#   [4] REQ-05 "allow" incondicional → FAIL nomeando o arquivo (inegociável)
#   [5] REQ-06 decisão imperativa fora do PEP, mode:enforce → FAIL nomeando o arquivo (Go/Kotlin/TS)
#   [6] REQ-06 a mesma decisão, mode:warn → WARN (não bloqueia, exit 0) — rebaixável
#   [7] REQ-06 decisão imperativa DENTRO do diretório do PEP declarado → PASS (isenta)
#   [8] REQ-07 cobertura reportada < threshold declarado → FAIL indicando cobertura×threshold
#   [9] REQ-07 sem policy_coverage_threshold declarado → no-op (não falso-positivo)
#   [10] REQ-08 rota layer:api sem caminho ao PEP → FAIL nomeando o node (via graph-govern), mode:warn → WARN
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIX="$WS/tests/fixtures/authz"
T="$(mktemp -d /tmp/forge-authz.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
SH="$T/.forge/scripts/check-authz.sh"
[ -f "$SH" ]
export FORGE_ROOT="$T"
mkdir -p "$T/.forge/graph"

# Fixtures copiadas PARA DENTRO de $T (= FORGE_ROOT), não referenciadas pelo path absoluto do
# repo: pep_paths/allowlist são glob relativos à raiz do projeto (mesmo referencial que
# graph-build.mjs usa para taggear roles), então o gate precisa achar os arquivos sob $T para
# "rel(f) = relative(root, f)" produzir paths como "pep/..." / "services/...".
mkdir -p "$T/policy" "$T/pep" "$T/services/orders"
cp "$FIX/pass/deny-by-default.rego" "$T/policy/pass-deny-by-default.rego"
cp "$FIX/fail/allow-true-default.rego" "$T/policy/fail-allow-true-default.rego"
cp "$FIX/fail/missing-deny-default.rego" "$T/policy/fail-missing-deny-default.rego"
cp "$FIX/fail/unconditional-allow.rego" "$T/policy/fail-unconditional-allow.rego"
cp "$FIX/fail/imperative-outside-pep.go" "$T/services/orders/handler.go"
cp "$FIX/fail/imperative-outside-pep.kt" "$T/services/orders/CancelOrderHandler.kt"
cp "$FIX/fail/imperative-outside-pep.ts" "$T/services/orders/cancelOrder.ts"
cp "$FIX/pass/pep/imperative-inside-pep.go" "$T/pep/check.go"

write_graph() { # write_graph <mode> [pep_paths_json] [threshold]
  local mode="$1" pep="${2:-[]}" thr="${3:-}"
  local thr_line=""
  [ -n "$thr" ] && thr_line="\"policy_coverage_threshold\": $thr,"
  cat > "$T/.forge/graph/graph.json" <<EOF
{
  "schema": "graph/v0",
  "governance": { "authz": { "mode": "$mode", $thr_line "pep_paths": $pep, "allowlist": [] } },
  "nodes": [],
  "edges": []
}
EOF
}

echo "[1] REQ-05: deny-by-default presente → PASS"
write_graph enforce
out="$(bash "$SH" --path "$T/policy/pass-deny-by-default.rego")"
echo "$out" | grep -q '^OK check-authz'
echo "OK [1]"

echo "[2] REQ-05: default allow := true → FAIL nomeando o arquivo, mesmo em mode:warn"
write_graph warn
set +e
out="$(bash "$SH" --path "$T/policy/fail-allow-true-default.rego")"; rc=$?
set -e
[ "$rc" -ne 0 ]
echo "$out" | grep -q 'CONFLICT'
echo "$out" | grep -q 'fail-allow-true-default.rego'
echo "OK [2]"

echo "[3] REQ-05: sem default allow := false → FAIL nomeando o arquivo"
write_graph enforce
set +e
out="$(bash "$SH" --path "$T/policy/fail-missing-deny-default.rego")"; rc=$?
set -e
[ "$rc" -ne 0 ]
echo "$out" | grep -q 'CONFLICT'
echo "$out" | grep -q 'fail-missing-deny-default.rego'
echo "OK [3]"

echo "[4] REQ-05: allow incondicional → FAIL nomeando o arquivo"
write_graph enforce
set +e
out="$(bash "$SH" --path "$T/policy/fail-unconditional-allow.rego")"; rc=$?
set -e
[ "$rc" -ne 0 ]
echo "$out" | grep -q 'CONFLICT'
echo "$out" | grep -q 'fail-unconditional-allow.rego'
echo "OK [4]"

echo "[5] REQ-06: decisão imperativa fora do PEP, mode:enforce → FAIL nomeando o arquivo (Go/Kotlin/TS)"
write_graph enforce '["pep"]'
set +e
out="$(bash "$SH" --path "$T/services/orders")"; rc=$?
set -e
[ "$rc" -ne 0 ]
echo "$out" | grep -q 'CONFLICT'
echo "$out" | grep -q 'services/orders/handler.go' && echo "$out" | grep -q 'hasRole(...)'
echo "$out" | grep -q 'services/orders/CancelOrderHandler.kt' && echo "$out" | grep -q 'decorator de role ad-hoc'
echo "$out" | grep -q 'services/orders/cancelOrder.ts' && echo "$out" | grep -q 'claims\["permissions"\]'
echo "OK [5]"

echo "[6] REQ-06: mesma decisão, mode:warn → WARN, não bloqueia (exit 0) — rebaixável"
write_graph warn '["pep"]'
out="$(bash "$SH" --path "$T/services/orders")"
echo "$out" | grep -q 'WARN'
echo "$out" | grep -q 'services/orders/handler.go'
! echo "$out" | grep -q 'CONFLICT'
echo "OK [6]"

echo "[7] REQ-06: decisão imperativa DENTRO do diretório do PEP declarado → PASS (isenta)"
write_graph enforce '["pep"]'
out="$(bash "$SH" --path "$T/pep")"
echo "$out" | grep -q '^OK check-authz'
echo "OK [7]"

echo "[8] REQ-07: cobertura reportada < threshold declarado → FAIL indicando cobertura×threshold"
write_graph enforce '[]' 0.9
echo '{ "coverage": 0.42 }' > "$T/coverage-report.json"
set +e
out="$(bash "$SH" --path "$T/policy/pass-deny-by-default.rego" --coverage-report "$T/coverage-report.json")"; rc=$?
set -e
[ "$rc" -ne 0 ]
echo "$out" | grep -q 'CONFLICT'
echo "$out" | grep -q '0.42' && echo "$out" | grep -q '0.9'
echo "OK [8]"

echo "[9] REQ-07: sem policy_coverage_threshold declarado → no-op (não falso-positivo)"
write_graph enforce
out="$(bash "$SH" --path "$T/policy/pass-deny-by-default.rego" --coverage-report "$T/coverage-report.json")"
echo "$out" | grep -q '^OK check-authz'
echo "OK [9]"

echo "[10] REQ-08: rota layer:api sem caminho ao PEP → FAIL nomeando o node (graph-govern); mode:warn → WARN"
cat > "$T/.forge/graph/graph.json" <<'EOF'
{
  "schema": "graph/v0",
  "governance": { "authz": { "mode": "enforce", "pep_paths": ["pep"], "allowlist": [] } },
  "nodes": [
    { "id": "services/orders/api/handler.go", "layer": "api" },
    { "id": "pep/check.go", "layer": "infrastructure", "roles": ["pep"] }
  ],
  "edges": []
}
EOF
set +e
out="$(bash "$SH" --path "$T/policy/pass-deny-by-default.rego")"; rc=$?
set -e
[ "$rc" -ne 0 ]
echo "$out" | grep -q 'CONFLICT'
echo "$out" | grep -q 'services/orders/api/handler.go'
echo "$out" | grep -q 'REQ-08'
# mesmo achado em mode:warn não bloqueia (rebaixável)
sed -i.bak 's/"mode": "enforce"/"mode": "warn"/' "$T/.forge/graph/graph.json"
out="$(bash "$SH" --path "$T/policy/pass-deny-by-default.rego")"
echo "$out" | grep -q 'WARN'
echo "$out" | grep -q 'services/orders/api/handler.go'
echo "OK [10]"

echo "OK"
