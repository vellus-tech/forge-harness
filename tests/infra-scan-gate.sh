#!/usr/bin/env bash
# Gate — infra-scan: scaffold de diagram-as-code a partir do docker-compose.
#   [1] detecta serviços + classifica por imagem (gateway/serviço/dados/obs)
#   [2] emite infra.py com imports corretos + clusters + nó users
#   [3] não gera `[lista] >> [lista]` (inválido no diagrams); Python compila
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/infra-scan.mjs"
[ -f "$LIB" ]
T="$(mktemp -d /tmp/forge-infra.XXXXXX)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/docker"

cat > "$T/docker/docker-compose.yml" <<'EOF'
services:
  kong:
    image: kong:3.6
  postgresql:
    image: postgres:16
  redis:
    image: redis:7-alpine
  rabbitmq:
    image: rabbitmq:3.12
  api-service:
    image: acme/api-service:dev
  jaeger:
    image: jaegertracing/all-in-one:1.53
EOF

node "$LIB" "$T" --out "$T/out" >/dev/null
PY="$T/out/infra.py"

echo "[1] classificação por imagem"
[ -f "$PY" ]
grep -q 'from diagrams.onprem.network import .*Kong' "$PY"
grep -q 'from diagrams.onprem.database import PostgreSQL' "$PY"
grep -q 'from diagrams.onprem.inmemory import Redis' "$PY"
grep -q 'from diagrams.onprem.queue import RabbitMQ' "$PY"
grep -q 'from diagrams.onprem.tracing import Jaeger' "$PY"
grep -q 'from diagrams.k8s.compute import Deployment' "$PY"   # api-service -> Deployment
echo "OK [1]"

echo "[2] clusters + users + Diagram"
grep -q 'with Diagram(' "$PY"
grep -q 'users = Users(' "$PY"
grep -q 'with Cluster("Edge' "$PY"
grep -q 'with Cluster("Dados' "$PY"
echo "OK [2]"

echo "[3] sem [lista] >> [lista]; Python compila"
! grep -Eq '\]\s*>>\s*Edge\([^)]*\)\s*>>\s*\[' "$PY"
if command -v python3 >/dev/null 2>&1; then
  python3 -m py_compile "$PY"   # sintaxe válida (não precisa de diagrams instalado)
fi
echo "OK [3]"

echo "OK"
