#!/usr/bin/env bash
# Gate — mdl-gen (PoC): gera diagramas na notação MDL 2.0 a partir do code graph.
#   [1] contexto: USER/FRONT-END/BACK-END/DATA + BOUNDARY + ALWAYS LINK
#   [2] DATA detectado de infra (docker/helm yaml)
#   [3] componente: PARTs (.NET) + COMPOSIÇÃO + LINK; ESPECIALIZAÇÃO de symbols.json
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/mdl-gen.mjs"
[ -f "$LIB" ]
T="$(mktemp -d /tmp/forge-mdl.XXXXXX)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.forge/graph" "$T/docker"

cat > "$T/docker/compose.yaml" <<'EOF'
services:
  db: { image: postgres:16 }
  cache: { image: redis:7 }
EOF
cat > "$T/.forge/graph/graph.json" <<'EOF'
{ "schema":"graph/v0",
  "nodes":[
    {"id":"backend/order-service/src/Shop.Order.Api/C.cs","layer":"api"},
    {"id":"backend/order-service/src/Shop.Order.Domain/E.cs","layer":"domain"},
    {"id":"frontend/web/src/App.tsx","layer":"api"}
  ],
  "edges":[{"from":"backend/order-service/src/Shop.Order.Api/C.cs","to":"backend/order-service/src/Shop.Order.Domain/E.cs","resolved":true}]
}
EOF
cat > "$T/.forge/graph/symbols.json" <<'EOF'
{ "schema":"symbols/v0","symbols":[],"edges":[
  {"from":"backend/order-service/src/Shop.Order.Domain/E.cs#Order","to":"backend/order-service/src/Shop.Order.Domain/E.cs#Entity","kind":"inherits","resolved":true}
]}
EOF

node "$LIB" "$T" >/dev/null
CTX="$T/.forge/graph/mdl/mdl-context.md"
CMP="$T/.forge/graph/mdl/mdl-component-order_service.md"

echo "[1] contexto com elementos + conectores MDL"
[ -f "$CTX" ]
grep -q '«user»' "$CTX"
grep -q '«back-end»' "$CTX"
grep -q '«front-end»' "$CTX"
grep -q '«data»' "$CTX"
grep -q '«boundary»' "$CTX"
grep -q '«always»' "$CTX"
echo "OK [1]"

echo "[2] DATA detectado da infra (postgres/redis)"
grep -qi 'PostgreSQL' "$CTX"
grep -qi 'Redis' "$CTX"
echo "OK [2]"

echo "[3] componente: PARTs + composição + especialização"
[ -f "$CMP" ]
grep -q '«part»' "$CMP"
grep -q 'Shop.Order.Api' "$CMP"
grep -q '«composição»' "$CMP"
grep -q '«especialização»' "$CMP"
echo "OK [3]"

echo "OK"
