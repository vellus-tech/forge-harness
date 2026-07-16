#!/usr/bin/env bash
# Gate — extractor nativo Java/Kotlin no code graph (issue #18):
#   [1] Java: nodes + edges internos resolvidos pela convenção pacote=diretório
#       (import explícito, wildcard `pkg.*`, static import, camadas Android por pasta)
#   [2] Kotlin: enum class, wildcard de membro de object (`Obj.*`), fun top-level,
#       import com alias/`;`/comentário — todos resolvem; comentário citando um tipo
#       NÃO gera declaração/edge fantasma
#   [3] validate graph → OK (java lang válida, sem órfãos num repo Java coeso)
#   [4] COBERTURA (§19.5, census em stats): dominante NÃO suportada → WARN de alto
#       nível; QUALQUER linguagem suportada com 0 nodes → FAIL (não só a dominante);
#       headers `.h` vendored NÃO geram WARN falso
#   [5] impact: seed de linguagem não suportada → mensagem distinta; path com
#       diretório pontilhado (v1.2/) não vira pseudo-extensão
#   [6] layerOf: idiomas Android sem colidir com domínios genéricos (room/dao/compose)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-jvm.XXXXXX)"
S="$(mktemp -d /tmp/forge-jvm-s.XXXXXX)"
trap 'rm -rf "$T" "$S"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
G="$T/.forge/scripts/graph.sh"
SCHEMA="$WS/template/.forge/schemas/graph.schema.json"

# ── fixture Android Java (pacote=diretório) + Kotlin com formas difíceis ───────
mkdir -p "$T/app/src/main/java/com/acme/domain" \
         "$T/app/src/main/java/com/acme/network" \
         "$T/app/src/main/java/com/acme/data" \
         "$T/app/src/main/java/com/acme/viewmodel" \
         "$T/app/src/main/kotlin/com/acme/ui" \
         "$T/app/src/main/kotlin/com/acme/util"
cat > "$T/app/src/main/java/com/acme/domain/Money.java" <<'EOF'
package com.acme.domain;
public final class Money { public final long cents; public Money(long c){this.cents=c;} }
EOF
cat > "$T/app/src/main/java/com/acme/domain/Currency.java" <<'EOF'
package com.acme.domain;
public enum Currency { BRL, USD }
EOF
cat > "$T/app/src/main/java/com/acme/network/PayApi.java" <<'EOF'
package com.acme.network;
import com.acme.domain.Money;
import com.acme.domain.Currency;
public interface PayApi { Money charge(Currency c); }
EOF
cat > "$T/app/src/main/java/com/acme/data/PayDao.java" <<'EOF'
package com.acme.data;
import com.acme.domain.*;
public class PayDao { }
EOF
cat > "$T/app/src/main/java/com/acme/viewmodel/PayViewModel.java" <<'EOF'
package com.acme.viewmodel;
import com.acme.network.PayApi;
import static com.acme.domain.Currency.BRL;
public class PayViewModel { PayApi api; }
EOF
# Kotlin: enum class, object (wildcard membro), fun top-level, e um phantom por comentário
cat > "$T/app/src/main/kotlin/com/acme/util/Color.kt" <<'EOF'
package com.acme.util
enum class Color { RED, GREEN }
EOF
cat > "$T/app/src/main/kotlin/com/acme/util/Constants.kt" <<'EOF'
package com.acme.util
object Constants { const val MAX = 42 }
EOF
cat > "$T/app/src/main/kotlin/com/acme/util/Extensions.kt" <<'EOF'
package com.acme.util
fun String.trimAll(): String = this.trim()
EOF
cat > "$T/app/src/main/kotlin/com/acme/util/Phantom.kt" <<'EOF'
package com.acme.util
// Comentário citando enum class Color e object Constants — não deve virar declaração.
class Phantom
EOF
cat > "$T/app/src/main/kotlin/com/acme/ui/PayScreen.kt" <<'EOF'
package com.acme.ui
import com.acme.viewmodel.PayViewModel as VM   // alias
import com.acme.domain.*                        // wildcard de pacote
import com.acme.util.Color                      // enum class
import com.acme.util.Constants.*                // wildcard de membro de object
import com.acme.util.trimAll                    // fun top-level
import com.acme.util.Phantom as P;              // alias + ';' + comentário
class PayScreen { val vm: VM? = null }
EOF

echo "[1] Java build: nodes + edges + camadas"
FORGE_ROOT="$T" bash "$G" build >/dev/null
[ -f "$T/.forge/graph/graph.json" ]
node "$WS/tools/validate-yaml.mjs" "$SCHEMA" "$T/.forge/graph/graph.json" >/dev/null
node -e '
const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const has=(f,t)=>g.edges.some(e=>e.from===f&&e.to===t&&e.resolved&&e.kind==="import");
const node=(id)=>g.nodes.find(n=>n.id===id);
const D="app/src/main/java/com/acme/";
const ok =
  has(D+"network/PayApi.java", D+"domain/Money.java") &&
  has(D+"network/PayApi.java", D+"domain/Currency.java") &&
  has(D+"data/PayDao.java", D+"domain/Money.java") &&          // wildcard pkg.*
  has(D+"data/PayDao.java", D+"domain/Currency.java") &&
  has(D+"viewmodel/PayViewModel.java", D+"domain/Currency.java") && // static import
  has(D+"viewmodel/PayViewModel.java", D+"network/PayApi.java") &&
  node(D+"domain/Money.java").layer==="domain" &&
  node(D+"network/PayApi.java").layer==="infrastructure" &&
  node(D+"data/PayDao.java").layer==="infrastructure" &&
  node(D+"viewmodel/PayViewModel.java").layer==="api";
if(!ok){console.error("edges/layers Java inesperados");process.exit(1);}
' "$T/.forge/graph/graph.json"
echo "OK [1]"

echo "[2] Kotlin: enum class / object wildcard / fun top-level / alias+; ; sem phantom"
node -e '
const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const K="app/src/main/kotlin/com/acme/";
const S=K+"ui/PayScreen.kt";
const to=g.edges.filter(e=>e.from===S).map(e=>e.to);
const has=(t)=>to.includes(K+t)||to.includes("app/src/main/java/com/acme/"+t);
const ok =
  has("viewmodel/PayViewModel.java") &&   // alias
  has("domain/Money.java") &&             // wildcard pacote
  has("util/Color.kt") &&                 // enum class (name != "class")
  has("util/Constants.kt") &&             // wildcard de membro de object
  has("util/Extensions.kt") &&            // fun top-level
  has("util/Phantom.kt");                 // alias + ; + comentário
// phantom: Phantom.kt só deve receber a aresta real do alias (1), nunca por menção em comentário
const phantomEdges=g.edges.filter(e=>e.from===S && e.to===K+"util/Phantom.kt").length;
const colorDeclaredOnce = g.edges.filter(e=>e.to===K+"util/Phantom.kt").length; // ninguém mais aponta p/ Phantom
if(!ok){console.error("edges Kotlin faltando: "+JSON.stringify(to));process.exit(1);}
if(phantomEdges!==1){console.error("phantom edge count = "+phantomEdges);process.exit(1);}
' "$T/.forge/graph/graph.json"
echo "OK [2]"

echo "[3] validate graph OK (java lang válida, sem órfãos)"
out="$(FORGE_ROOT="$T" bash "$G" validate)"
echo "$out" | grep -q '^OK graph' || { echo "esperava OK: $out"; exit 1; }
echo "$out" | grep -q 'orphan' && { echo "não deveria haver órfão: $out"; exit 1; }
echo "OK [3]"

echo "[4] cobertura: dominante não suportada = WARN; suportada 0 nodes = FAIL; .h vendored sem WARN falso"
# 4a: Swift dominante (não suportado) → OK com WARN
mkdir -p "$S/Sources/App"
cp -R "$WS/template/.forge" "$S/.forge"
for i in 1 2 3 4 5; do printf 'import Foundation\nclass Thing%s {}\n' "$i" > "$S/Sources/App/File$i.swift"; done
printf 'export const x = 1;\n' > "$S/tool.js"
FORGE_ROOT="$S" bash "$G" build >/dev/null
out="$(FORGE_ROOT="$S" bash "$G" validate)"
echo "$out" | grep -q '^OK graph' || { echo "swift: esperava OK (WARN): $out"; exit 1; }
echo "$out" | grep -q "dominant language 'swift'" || { echo "swift: faltou WARN: $out"; exit 1; }
# 4b: java suportada com 0 nodes (grafo corrompido/stale) → FAIL, mesmo não sendo dominante
node -e '
const p=process.argv[1];const g=JSON.parse(require("fs").readFileSync(p,"utf8"));
g.nodes=g.nodes.filter(n=>n.lang!=="java");g.edges=[];g.stats.nodes=g.nodes.length;g.stats.edges=0;
require("fs").writeFileSync(p,JSON.stringify(g,null,2));
' "$T/.forge/graph/graph.json"
set +e
out="$(FORGE_ROOT="$T" bash "$G" validate 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "esperava FAIL (java 0 nodes): $out"; exit 1; }
echo "$out" | grep -q "language 'java'" || { echo "faltou motivo de cobertura: $out"; exit 1; }
# 4c: headers .h vendored não superam código real (não viram census 'c')
V="$(mktemp -d /tmp/forge-h.XXXXXX)"
cp -R "$WS/template/.forge" "$V/.forge"
mkdir -p "$V/app/src/main/java/com/x" "$V/cpp/thirdparty/include"
for i in 1 2 3; do printf 'package com.x;\npublic class C%s {}\n' "$i" > "$V/app/src/main/java/com/x/C$i.java"; done
for i in $(seq 1 30); do printf '#pragma once\nint f%s();\n' "$i" > "$V/cpp/thirdparty/include/h$i.h"; done
FORGE_ROOT="$V" bash "$G" build >/dev/null
out="$(FORGE_ROOT="$V" bash "$G" validate)"
echo "$out" | grep -q "language 'c'" && { echo "REGRESSÃO: .h vendored gerou WARN falso: $out"; rm -rf "$V"; exit 1; }
echo "$out" | grep -q '^OK graph' || { echo ".h: esperava OK: $out"; rm -rf "$V"; exit 1; }
rm -rf "$V"
echo "OK [4]"

echo "[5] impact: seed não suportado + path com diretório pontilhado"
set +e
out="$(node "$S/.forge/scripts/lib/impact-scan.mjs" --graph "$S/.forge/graph/graph.json" --files Sources/App/File1.swift 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "esperava FAIL: $out"; exit 1; }
echo "$out" | grep -q 'not covered by the native extractor' || { echo "faltou msg de não-suportado: $out"; exit 1; }
# path com diretório pontilhado e sem extensão → mensagem genérica, não pseudo-extensão
set +e
out="$(node "$S/.forge/scripts/lib/impact-scan.mjs" --graph "$S/.forge/graph/graph.json" --files docs/v1.2/README 2>&1)"; rc=$?
set -e
echo "$out" | grep -q '2/README' && { echo "REGRESSÃO: pseudo-extensão .2/README: $out"; exit 1; }
echo "$out" | grep -q 'paths outside the graph or graph stale' || { echo "esperava msg genérica: $out"; exit 1; }
echo "OK [5]"

echo "[6] layerOf: Android sem colidir com domínio genérico"
node -e '
const src=require("fs").readFileSync("'"$WS"'/template/.forge/scripts/lib/graph-build.mjs","utf8");
eval(src.match(/function layerOf[\s\S]*?\n\}/)[0]);
const expect=[
  ["src/features/room/RoomService.ts","unknown"],       // Room de chat, não infra
  ["src/dao/ProposalVoting.ts","unknown"],              // DAO web3, não infra
  ["deploy/compose/docker-compose.prod.yml","config"],  // compose docker → config, não api
  ["app/src/main/java/com/acme/viewmodel/PayVM.java","api"],
  ["app/src/main/java/com/acme/network/Api.java","infrastructure"],
];
for(const [p,exp] of expect){ const got=layerOf(p); if(got!==exp){console.error(`layerOf(${p})=${got}, esperava ${exp}`);process.exit(1);} }
'
echo "OK [6]"

echo "OK"
