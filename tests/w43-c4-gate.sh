#!/usr/bin/env bash
# Gate W4.3 — C4 + overview.html (§16.5):
#   [1] c4.sh gera c1-context, c2-container e ao menos um c3-component na fixture
#   [2] overview.html existe e renderiza os 3 níveis C4 + capabilities + change ativo
#   [3] gate grep-negativo: nenhum ponto nem em-dash dentro de labels Mermaid
#   [4] determinismo: 2 execuções geram .md idênticos
#   [5] arquivos com nomes contendo pontos (money.ts) viram labels sanitizados
#   [6] c3 stale é removido quando o boundary deixa de existir
#   [8] LDG-0031: boundary de arquivo único gera C3 (não some em nenhum dos 3 níveis) e o C3 de
#       um boundary pequeno desenha a aresta CROSS-boundary (não só intra-boundary)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w43.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"
C4="$T/.forge/graph/c4"
. "$T/.forge/scripts/lib/gate-universe.sh"

# fixture: src/domain + services/billing, AMBOS com 2 arquivos. O gerador só emite
# component view para boundary com >= 2 arquivos (c4-gen.mjs, `if (allFiles.length < 2) continue`),
# então src/domain precisa de 2 arquivos para que money.ts chegue a ser renderizado e o
# cenário [5] tenha o que verificar. O import interno currency->money também dá ao C3 de
# boundary pequeno uma aresta intra-boundary (a aresta invoice->money é cross-boundary e
# o C3 não a desenha — ver item de ledger da lacuna do gerador).
mkdir -p "$T/src/domain" "$T/services/billing"
printf 'export class Money {}\n' > "$T/src/domain/money.ts"
printf "import { Money } from './money';\nexport class Currency { m = new Money(); }\n" > "$T/src/domain/currency.ts"
printf "import { Money } from '../../src/domain/money';\nexport class Invoice { m = new Money(); }\n" > "$T/services/billing/invoice.ts"
printf 'export class Payment {}\n' > "$T/services/billing/payment.ts"
FORGE_ROOT="$T" bash "$S/graph.sh" build >/dev/null

echo "[1] geração dos 3 níveis"
FORGE_ROOT="$T" bash "$S/c4.sh" >/dev/null
[ -f "$C4/c1-context.md" ] || { echo "FAIL [1]: c1-context.md ausente"; exit 1; }
[ -f "$C4/c2-container.md" ] || { echo "FAIL [1]: c2-container.md ausente"; exit 1; }
ls "$C4"/c3-component-*.md >/dev/null
grep -q '^flowchart' "$C4/c2-container.md"
echo "OK [1]"

echo "[2] overview.html com os 3 níveis + seções"
[ -f "$T/.forge/graph/overview.html" ]
grep -q 'C1 ·' "$T/.forge/graph/overview.html"
grep -q 'C2 ·' "$T/.forge/graph/overview.html"
grep -q 'C3 ·' "$T/.forge/graph/overview.html"
grep -q 'Capabilities' "$T/.forge/graph/overview.html"
grep -q 'Changes ativos' "$T/.forge/graph/overview.html"
grep -q 'class="mermaid"' "$T/.forge/graph/overview.html"
echo "OK [2]"

echo "[3] grep-negativo: pontos/em-dash em labels Mermaid"
viol="$(grep -hoE '\["[^"]*"\]' "$C4"/*.md | grep -E '\.|—|–' || true)"
[ -z "$viol" ] || { echo "VIOLAÇÃO de label: $viol"; exit 1; }
echo "OK [3] (labels limpos)"

echo "[4] determinismo"
h1="$(cat "$C4"/*.md | shasum -a 256)"
FORGE_ROOT="$T" bash "$S/c4.sh" >/dev/null
h2="$(cat "$C4"/*.md | shasum -a 256)"
[ "$h1" = "$h2" ]
echo "OK [4]"

echo "[5] sanitização de nome com ponto (money.ts -> 'money ts')"
grep -rq 'money ts' "$C4"/ && ! grep -rEq '\["[^"]*money\.ts[^"]*"\]' "$C4"/ \
  || { echo "FAIL [5]: 'money ts' sanitizado ausente, ou 'money.ts' com ponto ainda vazando num label"; exit 1; }
echo "OK [5]"

echo "[6] c3 stale removido quando boundary some"
[ -f "$C4/c3-component-services-billing.md" ]
rm -rf "$T/services"
FORGE_ROOT="$T" bash "$S/graph.sh" build >/dev/null
FORGE_ROOT="$T" bash "$S/c4.sh" >/dev/null
[ ! -e "$C4/c3-component-services-billing.md" ]
echo "OK [6]"

echo "[7] C3 grande é AGREGADO por submódulo (equilíbrio: renderável + completo)"
T2="$(mktemp -d /tmp/forge-w43cap.XXXXXX)"
mkdir -p "$T2/.forge/graph"
node -e '
  const n=[],e=[];
  const subs=["App.Api","App.Application","App.Domain"];
  for(let i=0;i<60;i++){const s=subs[i%3];n.push({id:`services/big/src/${s}/f${i}.cs`,layer:"application"});}
  for(let i=0;i<20;i++){e.push({from:`services/big/src/App.Api/f${i*3}.cs`,to:`services/big/src/App.Application/f${i*3+1}.cs`,resolved:true});}
  require("fs").writeFileSync(process.argv[1],JSON.stringify({schema:"graph/v0",nodes:n,edges:e}));
' "$T2/.forge/graph/graph.json"
FORGE_ROOT="$T2" node "$S/lib/c4-gen.mjs" "$T2" >/dev/null
BIG="$T2/.forge/graph/c4/c3-component-services-big.md"
[ -f "$BIG" ]
cnt="$(grep -cE '^[[:space:]]+g[0-9]+\["' "$BIG")"
[ "$cnt" -le 50 ] && [ "$cnt" -ge 2 ] \
  || { echo "FAIL [7]: C3 agregado com cnt=$cnt fora da faixa [2, 50]"; exit 1; }
grep -q 'agregado' "$BIG"
grep -q '60 arquivos' "$BIG"
rm -rf "$T2"
echo "OK [7] (agregado em $cnt submódulos)"

echo "[8] LDG-0031: boundary de arquivo único aparece + aresta cross-boundary aparece no C3"
T3="$(mktemp -d /tmp/forge-w43single.XXXXXX)"
mkdir -p "$T3/.forge/graph"
node -e '
  const n = [
    { id: "src/domain/money.ts", layer: "domain" },
    { id: "services/billing/invoice.ts", layer: "application" },
    { id: "services/billing/payment.ts", layer: "application" },
  ];
  const e = [{ from: "services/billing/invoice.ts", to: "src/domain/money.ts", kind: "import", resolved: true }];
  require("fs").writeFileSync(process.argv[1], JSON.stringify({ schema: "graph/v0", nodes: n, edges: e }));
' "$T3/.forge/graph/graph.json"
n3="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).nodes.length)' "$T3/.forge/graph/graph.json")"
e3="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).edges.length)' "$T3/.forge/graph/graph.json")"
forge_universe_check "w43-single-boundary-nodes" "$n3" "node(s)" "fixture do repro do LDG-0031" "$T3"
forge_universe_check "w43-single-boundary-edges" "$e3" "edge(s)" "fixture do repro do LDG-0031" "$T3"
FORGE_ROOT="$T3" node "$S/lib/c4-gen.mjs" "$T3" >/dev/null
SINGLE="$T3/.forge/graph/c4/c3-component-src-domain.md"
BILL="$T3/.forge/graph/c4/c3-component-services-billing.md"
[ -f "$SINGLE" ] || { echo "FAIL [8]: boundary de arquivo único (src/domain, 1 arquivo) não gerou C3 — money.ts some dos 3 níveis do C4"; exit 1; }
grep -q 'money ts' "$SINGLE" || { echo "FAIL [8]: c3-component-src-domain.md existe mas não contém o nó money.ts"; exit 1; }
[ -f "$BILL" ] || { echo "FAIL [8]: services/billing (2 arquivos) não gerou C3"; exit 1; }
grep -q 'money ts' "$BILL" || { echo "FAIL [8]: c3-component-services-billing.md não mostra a aresta cross-boundary para money.ts (C3 desenhando só arestas intra-boundary)"; exit 1; }
grep -qE -- '-->' "$BILL" || { echo "FAIL [8]: c3-component-services-billing.md não desenha NENHUMA aresta, nem a cross-boundary"; exit 1; }
rm -rf "$T3"
echo "OK [8]"

echo "OK"
