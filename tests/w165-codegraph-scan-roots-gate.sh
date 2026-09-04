#!/usr/bin/env bash
# Gate W165 — raiz de varredura declarável do code graph + `.sh` no mapa de linguagens
# (LDG-0027). SKIP_DIRS pula `bin` (já corrigido — w41 [10]) e `.forge` (correto em projeto
# CONSUMIDOR: lá é o harness instalado, não o produto). O problema é o repositório que PRODUZ o
# harness: `template/.forge/scripts/**` é código-fonte de verdade e ficava invisível para
# `/forge:codegraph`, `/forge:onboard`, `/forge:c4` e `/forge:impact` rodando sobre o próprio
# forge-harness. A correção não é uma exceção com o nome deste projeto embutida no motor: o
# repositório DECLARA, via `codegraph.include_paths` no frontmatter do FORGE.md — o mesmo bloco
# que já existe para `codegraph.layers` (issue #38) —, quais caminhos normalmente pulados
# (prefixo de ponto OU SKIP_DIRS) são código-fonte. `.sh` entra no mapa de linguagens como nó;
# extração de aresta NÃO é tentada (decisão documentada — SCRIPT_DIR/variáveis tornam a resolução
# estática pouco confiável; nó sem aresta é honesto, aresta fantasma não é).
#
#   [1] controle: sem `codegraph.include_paths`, um diretório de nome oculto continua fora do
#       grafo — o default de projeto consumidor não muda
#   [2] declarado: `codegraph.include_paths` traz o mesmo diretório para o grafo
#   [3] `.sh` vira nó (`lang: shell`) mas sem aresta extraída (decisão documentada, não omissão)
#   [4] `forge graph validate` aceita nó lang=shell (validate-graph.mjs tem seu PRÓPRIO enum de
#       linguagens, duplicado do schema — os dois têm de saber sobre `shell`)
#   [5] guarda de vacuidade (issue #49): nós e arestas examinados > 0 nos dois lados
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w165.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
G="$T/.forge/scripts/graph.sh"
J="$T/.forge/graph/graph.json"
. "$T/.forge/scripts/lib/gate-universe.sh"

node_ids() { node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).nodes.map(n=>n.id).join("\n"))' "$1"; }
node_count() { node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).nodes.length)' "$1"; }
edge_count() { node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).edges.length)' "$1"; }

# fixture: produto simulado sob diretório de NOME OCULTO (".hidden-src"), o mesmo formato do
# blind spot real (template/.forge/scripts). Dois .sh que se chamam via SCRIPT_DIR (o idioma
# real do repositório) + dois .ts comuns fora do diretório oculto, para ancorar arestas
# resolvidas normais (guarda de vacuidade precisa de arestas de verdade, não só de nós).
mkdir -p "$T/.hidden-src/lib" "$T/src"
cat > "$T/.hidden-src/main.sh" <<'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/lib/util.sh"
EOF
cat > "$T/.hidden-src/lib/util.sh" <<'EOF'
#!/usr/bin/env bash
echo "util"
EOF
cat > "$T/src/money.ts" <<'EOF'
export class Money {}
EOF
cat > "$T/src/billing.ts" <<'EOF'
import { Money } from './money';
export class Billing { m = new Money(); }
EOF

echo "[1] controle: sem include_paths, diretório oculto continua fora (default de consumidor)"
FORGE_ROOT="$T" bash "$G" build >/dev/null
ids1="$(node_ids "$J")"
if grep -q '^\.hidden-src' <<<"$ids1"; then
  echo "FAIL [1]: .hidden-src apareceu no grafo sem declaração alguma — o default de projeto consumidor quebrou"
  exit 1
fi
n1="$(node_count "$J")"
e1="$(edge_count "$J")"
echo "OK [1] (nodes=$n1 edges=$e1, .hidden-src ausente)"

echo "[2] declarado: codegraph.include_paths traz .hidden-src para o grafo"
cat > "$T/.forge/FORGE.md" <<'EOF'
---
forge_version: 1
codegraph:
  include_paths:
    - ".hidden-src/**"
---

# FORGE.md de fixture
EOF
FORGE_ROOT="$T" bash "$G" build >/dev/null
ids2="$(node_ids "$J")"
for want in ".hidden-src/main.sh" ".hidden-src/lib/util.sh"; do
  grep -qF "$want" <<<"$ids2" || { echo "FAIL [2]: $want ausente do grafo mesmo com include_paths declarado — nodes: $ids2"; exit 1; }
done
n2="$(node_count "$J")"
e2="$(edge_count "$J")"
[ "$n2" -gt "$n1" ] || { echo "FAIL [2]: declarar include_paths não aumentou a contagem de nós ($n1 -> $n2)"; exit 1; }
echo "OK [2] (nodes=$n2, .hidden-src/** presente)"

echo "[3] .sh vira nó (lang shell) sem aresta extraída (decisão documentada, não omissão)"
lang_sh="$(node -e '
const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const n=g.nodes.find(x=>x.id===".hidden-src/main.sh");
console.log(n ? n.lang : "AUSENTE");
' "$J")"
[ "$lang_sh" = "shell" ] || { echo "FAIL [3]: .hidden-src/main.sh deveria ter lang=shell, obtido '$lang_sh'"; exit 1; }
sh_edges="$(node -e '
const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const ids=new Set([".hidden-src/main.sh",".hidden-src/lib/util.sh"]);
console.log(g.edges.filter(e=>ids.has(e.from)||ids.has(e.to)).length);
' "$J")"
[ "$sh_edges" -eq 0 ] || { echo "FAIL [3]: extração de aresta para .sh apareceu (esperado 0, obtido $sh_edges) — se a decisão de não extrair mudou, este gate precisa acompanhar deliberadamente"; exit 1; }
echo "OK [3] (lang=shell, 0 arestas — decisão deliberada)"

echo "[4] forge graph validate aceita nó lang=shell"
out4="$(FORGE_ROOT="$T" bash "$G" validate 2>&1)" || { echo "FAIL [4]: validate reprovou grafo com nó shell: $out4"; exit 1; }
case "$out4" in
  OK*) : ;;
  *) echo "FAIL [4]: validate não retornou OK: $out4"; exit 1 ;;
esac
echo "OK [4]"

echo "[5] guarda de vacuidade (issue #49): nós e arestas examinados > 0 nos dois lados"
forge_universe_check "w165-controle-nodes" "$n1" "node(s)" "fixture sem include_paths" "$T"
forge_universe_check "w165-controle-edges" "$e1" "edge(s)" "fixture sem include_paths" "$T"
forge_universe_check "w165-declarado-nodes" "$n2" "node(s)" "fixture com include_paths" "$T"
forge_universe_check "w165-declarado-edges" "$e2" "edge(s)" "fixture com include_paths" "$T"
echo "OK [5]"

echo "PASS w165-codegraph-scan-roots-gate"
