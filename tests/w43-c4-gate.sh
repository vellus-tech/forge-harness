#!/usr/bin/env bash
# Gate W4.3 — C4 + overview.html (§16.5):
#   [1] c4.sh gera c1-context, c2-container e ao menos um c3-component na fixture
#   [2] overview.html existe e renderiza os 3 níveis C4 + capabilities + change ativo
#   [3] gate grep-negativo: nenhum ponto nem em-dash dentro de labels Mermaid
#   [4] determinismo: 2 execuções geram .mmd idênticos
#   [5] arquivos com nomes contendo pontos (money.ts) viram labels sanitizados
#   [6] c3 stale é removido quando o boundary deixa de existir
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w43.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"
C4="$T/.forge/graph/c4"

# fixture: src/domain + services/billing (2 arquivos -> tem component view)
mkdir -p "$T/src/domain" "$T/services/billing"
printf 'export class Money {}\n' > "$T/src/domain/money.ts"
printf "import { Money } from '../../src/domain/money';\nexport class Invoice { m = new Money(); }\n" > "$T/services/billing/invoice.ts"
printf 'export class Payment {}\n' > "$T/services/billing/payment.ts"
FORGE_ROOT="$T" bash "$S/graph.sh" build >/dev/null

echo "[1] geração dos 3 níveis"
FORGE_ROOT="$T" bash "$S/c4.sh" >/dev/null
[ -f "$C4/c1-context.mmd" ] && [ -f "$C4/c2-container.mmd" ]
ls "$C4"/c3-component-*.mmd >/dev/null
grep -q '^flowchart' "$C4/c2-container.mmd"
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
viol="$(grep -hoE '\["[^"]*"\]' "$C4"/*.mmd | grep -E '\.|—|–' || true)"
[ -z "$viol" ] || { echo "VIOLAÇÃO de label: $viol"; exit 1; }
echo "OK [3] (labels limpos)"

echo "[4] determinismo"
h1="$(cat "$C4"/*.mmd | shasum -a 256)"
FORGE_ROOT="$T" bash "$S/c4.sh" >/dev/null
h2="$(cat "$C4"/*.mmd | shasum -a 256)"
[ "$h1" = "$h2" ]
echo "OK [4]"

echo "[5] sanitização de nome com ponto (money.ts -> 'money ts')"
grep -rq 'money ts' "$C4"/ && ! grep -rEq '\["[^"]*money\.ts[^"]*"\]' "$C4"/
echo "OK [5]"

echo "[6] c3 stale removido quando boundary some"
[ -f "$C4/c3-component-services-billing.mmd" ]
rm -rf "$T/services"
FORGE_ROOT="$T" bash "$S/graph.sh" build >/dev/null
FORGE_ROOT="$T" bash "$S/c4.sh" >/dev/null
[ ! -e "$C4/c3-component-services-billing.mmd" ]
echo "OK [6]"

echo "OK"
