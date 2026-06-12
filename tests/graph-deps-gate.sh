#!/usr/bin/env bash
# Gate — graph deps: dependências módulo→módulo + detecção de ciclos (absorvido do
# Understand-Anything, determinista/zero-dep).
#   [1] adjacência módulo→módulo agregada com contagem (fan-out/fan-in)
#   [2] detecta ciclo entre módulos (smell)
#   [3] grafo acíclico → "nenhum ciclo"
#   [4] --json grava module-deps.json
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/graph-deps.mjs"
[ -f "$LIB" ]
T="$(mktemp -d /tmp/forge-deps.XXXXXX)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.forge/graph"

# grafo sintético: services/a depende de services/b e de packages/shared; b depende de shared.
cat > "$T/.forge/graph/graph.json" <<'EOF'
{
  "schema": "graph/v0",
  "nodes": [
    { "id": "services/a/x.ts" }, { "id": "services/b/y.ts" }, { "id": "packages/shared/z.ts" }
  ],
  "edges": [
    { "from": "services/a/x.ts", "to": "services/b/y.ts", "resolved": true },
    { "from": "services/a/x.ts", "to": "packages/shared/z.ts", "resolved": true },
    { "from": "services/b/y.ts", "to": "packages/shared/z.ts", "resolved": true }
  ]
}
EOF

echo "[1] adjacência + fan-out/fan-in"
out="$(node "$LIB" "$T")"
echo "$out" | grep -q 'services/a'
echo "$out" | grep -A2 '## services/a' | grep -q 'services/b (1)'
echo "$out" | grep -A2 '## services/a' | grep -q 'packages/shared (1)'
# shared é usado por a e b (fan-in 2)
echo "$out" | grep -A3 '## packages/shared' | grep -qE 'fan-in 2'
echo "OK [1]"

echo "[2] ciclo entre módulos detectado"
# adiciona aresta shared -> a, criando ciclo a->shared->a
node -e '
const fs=require("fs");const p="'"$T"'/.forge/graph/graph.json";const g=JSON.parse(fs.readFileSync(p,"utf8"));
g.edges.push({from:"packages/shared/z.ts",to:"services/a/x.ts",resolved:true});
fs.writeFileSync(p,JSON.stringify(g,null,2));
'
out2="$(node "$LIB" "$T")"
echo "$out2" | grep -qi 'Ciclos entre módulos'
echo "$out2" | grep -q '→'
echo "OK [2]"

echo "[3] grafo acíclico → nenhum ciclo"
# remove a aresta de ciclo
node -e '
const fs=require("fs");const p="'"$T"'/.forge/graph/graph.json";const g=JSON.parse(fs.readFileSync(p,"utf8"));
g.edges=g.edges.filter(e=>!(e.from==="packages/shared/z.ts"&&e.to==="services/a/x.ts"));
fs.writeFileSync(p,JSON.stringify(g,null,2));
'
node "$LIB" "$T" | grep -q 'nenhum ✓'
echo "OK [3]"

echo "[4] --json grava module-deps.json"
node "$LIB" "$T" --json | grep -q '^OK module-deps.json'
[ -f "$T/.forge/graph/module-deps.json" ]
node -e 'const d=JSON.parse(require("fs").readFileSync("'"$T"'/.forge/graph/module-deps.json","utf8")); if(!Array.isArray(d.edges)||!Array.isArray(d.cycles)) throw new Error("schema");'
echo "OK [4]"

echo "[5] violação de camada (domain->infrastructure)"
cat > "$T/.forge/graph/graph.json" <<'JSON'
{ "schema":"graph/v0",
  "nodes":[
    {"id":"src/app/Foo.cs","layer":"domain"},
    {"id":"src/app/Bar.cs","layer":"infrastructure"},
    {"id":"src/app/Api.cs","layer":"api"}
  ],
  "edges":[
    {"from":"src/app/Foo.cs","to":"src/app/Bar.cs","resolved":true},
    {"from":"src/app/Api.cs","to":"src/app/Foo.cs","resolved":true}
  ]
}
JSON
v="$(node "$LIB" "$T")"
echo "$v" | grep -qi 'Violações de camada'
echo "$v" | grep -q 'domain→infrastructure: 1'
# api->domain é permitido (não vira violação)
! echo "$v" | grep -q 'api→domain'
echo "OK [5]"

echo "[6] --by-project usa o diretório do projeto .NET"
cat > "$T/.forge/graph/graph.json" <<'JSON'
{ "schema":"graph/v0",
  "nodes":[
    {"id":"backend/svc/src/App.Api/X.cs","layer":"api"},
    {"id":"backend/svc/src/App.Domain/Y.cs","layer":"domain"}
  ],
  "edges":[{"from":"backend/svc/src/App.Api/X.cs","to":"backend/svc/src/App.Domain/Y.cs","resolved":true}]
}
JSON
p="$(node "$LIB" "$T" --by-project)"
echo "$p" | grep -q 'backend/svc/src/App.Api'
echo "$p" | grep -q 'App.Domain (1)'
echo "OK [6]"

echo "OK"
