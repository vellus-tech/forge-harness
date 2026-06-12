#!/usr/bin/env bash
# Gate — graph symbols: camada símbolo-nível opt-in (regex, zero-dep).
#   [1] extrai classes/interfaces/funções por linguagem
#   [2] arestas de herança resolvidas por nome
#   [3] sem call graph (apenas declarações + herança) — symbols.json válido
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/graph-symbols.mjs"
[ -f "$LIB" ]
T="$(mktemp -d /tmp/forge-sym.XXXXXX)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.forge/graph" "$T/src"

cat > "$T/src/animal.ts" <<'EOF'
export interface Animal { name: string }
export class Dog extends Mammal { bark() {} }
export class Mammal implements Animal { name = "" }
export function makeDog(): Dog { return new Dog(); }
EOF
cat > "$T/src/order.cs" <<'EOF'
namespace Shop;
public interface IOrder { }
public record OrderPlaced : DomainEvent;
public class Order : IOrder { }
public class DomainEvent { }
EOF
cat > "$T/src/svc.py" <<'EOF'
class Base:
    pass
class Service(Base):
    def run(self):
        pass
def helper():
    return 1
EOF

echo "[1] extrai declarações por linguagem"
node "$LIB" "$T" >/dev/null
S="$T/.forge/graph/symbols.json"
[ -f "$S" ]
node -e '
  const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
  const names=s.symbols.map(x=>x.name);
  for (const n of ["Animal","Dog","Mammal","makeDog","IOrder","Order","DomainEvent","OrderPlaced","Base","Service","helper"])
    if(!names.includes(n)) throw new Error("faltou símbolo: "+n);
  const t=s.stats.by_type;
  if(!t.class||!t.interface||!t.function) throw new Error("tipos faltando: "+JSON.stringify(t));
' "$S"
echo "OK [1]"

echo "[2] herança resolvida por nome"
node -e '
  const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
  const has=(a,b)=>s.edges.some(e=>e.kind==="inherits"&&e.resolved&&e.from.endsWith("#"+a)&&e.to.endsWith("#"+b));
  if(!has("Dog","Mammal")) throw new Error("Dog->Mammal ausente");
  if(!has("OrderPlaced","DomainEvent")) throw new Error("OrderPlaced->DomainEvent ausente");
  if(!has("Service","Base")) throw new Error("Service->Base ausente");
' "$S"
echo "OK [2]"

echo "[3] symbols.json estrutural + nota de limitação (sem call graph)"
node -e '
  const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
  if(s.schema!=="symbols/v0") throw new Error("schema");
  if(!/call graph/i.test(s.note)) throw new Error("nota de limitação ausente");
  if(s.edges.some(e=>e.kind==="call")) throw new Error("não deveria ter arestas de call");
' "$S"
echo "OK [3]"

echo "OK"
