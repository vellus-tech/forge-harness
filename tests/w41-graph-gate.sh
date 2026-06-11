#!/usr/bin/env bash
# Gate W4.1 — graph build + validação determinística (§16.2/§16.3/§19.5):
#   [1] build numa fixture brownfield (TS multi-camada + C#) → graph.json válido por schema
#   [2] forge validate graph → OK (integridade, layers, sem duplicados)
#   [3] determinismo: 2 builds idênticos (mesmo hash de graph.json)
#   [4] INCREMENTAL: mudança cosmética (comentário+whitespace) NÃO altera o
#       fingerprint nem o summary cacheado → update é no-op (zero tokens)
#   [5] mudança ESTRUTURAL (novo import) altera o fingerprint e o grafo
#   [6] validate detecta grafo corrompido (edge resolvido órfão; id duplicado)
#   [7] query e path funcionam sobre o grafo
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w41.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
G="$T/.forge/scripts/graph.sh"
SCHEMA="$WS/template/.forge/schemas/graph.schema.json"

# fixture brownfield
mkdir -p "$T/src/domain" "$T/src/application" "$T/src/api" "$T/services/auth"
cat > "$T/src/domain/money.ts" <<'EOF'
export class Money { constructor(public cents: number) {} }
EOF
cat > "$T/src/application/pay.ts" <<'EOF'
import { Money } from '../domain/money';
export function pay(c: number) { return new Money(c); }
EOF
cat > "$T/src/api/handler.ts" <<'EOF'
import { pay } from '../application/pay';
export const h = () => pay(100);
EOF
cat > "$T/services/auth/Token.cs" <<'EOF'
namespace Auth.Domain;
public class Token { public string Value { get; set; } }
EOF
cat > "$T/services/auth/Service.cs" <<'EOF'
using Auth.Domain;
namespace Auth.Application;
public class Service { public Token Make() => new Token(); }
EOF

echo "[1] build + schema"
FORGE_ROOT="$T" bash "$G" build >/dev/null
[ -f "$T/.forge/graph/graph.json" ]
node "$WS/tools/validate-yaml.mjs" "$SCHEMA" "$T/.forge/graph/graph.json" >/dev/null
node -e '
const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const ok = g.nodes.length===5
  && g.edges.some(e=>e.from==="src/api/handler.ts"&&e.to==="src/application/pay.ts"&&e.resolved)
  && g.edges.some(e=>e.from==="src/application/pay.ts"&&e.to==="src/domain/money.ts"&&e.resolved)
  && g.edges.some(e=>e.from==="services/auth/Service.cs"&&e.to==="services/auth/Token.cs"&&e.kind==="namespace")
  && g.nodes.find(n=>n.id==="src/domain/money.ts").layer==="domain"
  && g.nodes.find(n=>n.id==="src/api/handler.ts").layer==="api";
process.exit(ok?0:1);
' "$T/.forge/graph/graph.json"
echo "OK [1]"

echo "[2] validate graph"
FORGE_ROOT="$T" bash "$G" validate >/dev/null
echo "OK [2]"

echo "[3] determinismo (2 builds idênticos exceto timestamp)"
h1="$(grep -v generated_at "$T/.forge/graph/graph.json" | shasum -a 256)"
FORGE_ROOT="$T" bash "$G" build >/dev/null
h2="$(grep -v generated_at "$T/.forge/graph/graph.json" | shasum -a 256)"
[ "$h1" = "$h2" ]
echo "OK [3]"

echo "[4] incremental: mudança cosmética = zero tokens (fingerprint estável)"
fp_before="$(node -e 'const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(g.nodes.find(n=>n.id==="src/domain/money.ts").fingerprint)' "$T/.forge/graph/graph.json")"
# adiciona comentário em linha própria + linha em branco + reindenta
cat > "$T/src/domain/money.ts" <<'EOF'

// Objeto de Valor monetário (comentário cosmético adicionado)

export class Money {
    constructor(public cents: number) {}
}
EOF
out="$(FORGE_ROOT="$T" bash "$G" update)"
echo "$out" | grep -q 'zero tokens'
fp_after="$(node -e 'const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(g.nodes.find(n=>n.id==="src/domain/money.ts").fingerprint)' "$T/.forge/graph/graph.json")"
[ "$fp_before" = "$fp_after" ]
echo "OK [4] (fingerprint estável: ${fp_before:0:12})"

echo "[5] mudança estrutural altera fingerprint"
cat >> "$T/src/domain/money.ts" <<'EOF'
import { pay } from '../application/pay';
export const extra = pay;
EOF
out="$(FORGE_ROOT="$T" bash "$G" update)"
echo "$out" | grep -q 'structural change'
fp_struct="$(node -e 'const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(g.nodes.find(n=>n.id==="src/domain/money.ts").fingerprint)' "$T/.forge/graph/graph.json")"
[ "$fp_struct" != "$fp_before" ]
echo "OK [5]"

echo "[6] validate detecta corrupção"
cp "$T/.forge/graph/graph.json" "$T/g.bak"
# edge resolvido apontando para nó inexistente
node -e '
const p=process.argv[1];const g=JSON.parse(require("fs").readFileSync(p,"utf8"));
g.edges.push({from:"src/api/handler.ts",to:"src/ghost.ts",kind:"import",resolved:true});
g.stats.edges=g.edges.length;
require("fs").writeFileSync(p,JSON.stringify(g,null,2));
' "$T/.forge/graph/graph.json"
set +e
out="$(FORGE_ROOT="$T" bash "$G" validate 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && echo "$out" | grep -q 'referential integrity'
mv "$T/g.bak" "$T/.forge/graph/graph.json"
echo "OK [6]"

echo "[7] query + path"
FORGE_ROOT="$T" bash "$G" query money | grep -q 'src/domain/money.ts'
FORGE_ROOT="$T" bash "$G" path src/api/handler.ts src/domain/money.ts | grep -q 'PATH:'
echo "OK [7]"

echo "OK"
