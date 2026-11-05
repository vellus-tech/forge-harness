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

echo "[9b] universo ampliado via wrapper standalone (.sh / include_paths — STORY-04/TASK-07)"
T2="$(mktemp -d /tmp/forge-sym9b.XXXXXX)"
mkdir -p "$T2/.forge/graph" "$T2/scripts" "$T2/.hidden"
cat > "$T2/scripts/deploy.sh" <<'EOF'
#!/usr/bin/env bash
run_deploy() {
  echo deploying
}
EOF
cat > "$T2/.hidden/secret.ts" <<'EOF'
export function hiddenFn() { return 1; }
EOF
cat > "$T2/.forge/FORGE.md" <<'EOF'
---
codegraph:
  include_paths:
    - .hidden
---
# FORGE
EOF
node "$LIB" "$T2" >/dev/null
S2="$T2/.forge/graph/symbols.json"
node -e '
  const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
  const names=s.symbols.map(x=>x.name);
  if(!names.includes("run_deploy")) throw new Error("função shell run_deploy não indexada pelo wrapper standalone");
  if(!names.includes("hiddenFn")) throw new Error("include_paths não foi herdado pelo wrapper standalone (.hidden/ deveria entrar)");
' "$S2" || { echo "FAIL [9b]: universo ampliado (.sh/include_paths) não herdado pelo wrapper standalone"; exit 1; }
rm -rf "$T2"
echo "OK [9b]"

echo "[25] graph.sh symbols isolado não altera graph.json/fingerprints.json/report.md (regressão — STORY-04/TASK-07)"
T3="$(mktemp -d /tmp/forge-sym25.XXXXXX)"
mkdir -p "$T3/src"
cat > "$T3/src/a.ts" <<'EOF'
export class A {}
EOF
cp -R "$WS/template/.forge" "$T3/.forge"
FORGE_ROOT="$T3" bash "$T3/.forge/scripts/graph.sh" build >/dev/null
GJ="$T3/.forge/graph/graph.json"
FP="$T3/.forge/graph/cache/fingerprints.json"
RM="$T3/.forge/graph/report.md"
mtime_gj1="$(node -e 'console.log(require("fs").statSync(process.argv[1]).mtimeMs)' "$GJ")"
mtime_fp1="$(node -e 'console.log(require("fs").statSync(process.argv[1]).mtimeMs)' "$FP")"
mtime_rm1="$(node -e 'console.log(require("fs").statSync(process.argv[1]).mtimeMs)' "$RM")"
FORGE_ROOT="$T3" bash "$T3/.forge/scripts/graph.sh" symbols >/dev/null
mtime_gj2="$(node -e 'console.log(require("fs").statSync(process.argv[1]).mtimeMs)' "$GJ")"
mtime_fp2="$(node -e 'console.log(require("fs").statSync(process.argv[1]).mtimeMs)' "$FP")"
mtime_rm2="$(node -e 'console.log(require("fs").statSync(process.argv[1]).mtimeMs)' "$RM")"
[ "$mtime_gj1" = "$mtime_gj2" ] || { echo "FAIL [25]: graph.json alterado por graph.sh symbols isolado"; exit 1; }
[ "$mtime_fp1" = "$mtime_fp2" ] || { echo "FAIL [25]: fingerprints.json alterado por graph.sh symbols isolado"; exit 1; }
[ "$mtime_rm1" = "$mtime_rm2" ] || { echo "FAIL [25]: report.md alterado por graph.sh symbols isolado"; exit 1; }
rm -rf "$T3"
echo "OK [25]"

echo "OK"
