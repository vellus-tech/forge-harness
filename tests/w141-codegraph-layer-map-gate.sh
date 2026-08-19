#!/usr/bin/env bash
# Gate W141 — mapa de camadas declarável, `unknown` como estado legítimo e classificação de
# órfãos antes do alerta (issue #38).
#
# A heurística de camada nasceu ancorada na convenção `services/<x>/src/<X>.{Domain,…}` e todo
# código .NET fora dessa forma cai em `unknown`. No repositório poliglota medido na issue foram
# 403 arquivos C# em TRÊS layouts distintos — plataforma satélite (`<raiz>/src/services/<svc>/
# <Ns>.<Camada>`), pacotes compartilhados (`packages/dotnet/<Ns>`) e monólito legado pré-Clean-
# Architecture (`src/<Produto>.<Camada>`) — mais 1.259 nós de frontend que a taxonomia
# `domain/application/infrastructure/api/contracts` simplesmente não descreve. A fixture deste
# gate reproduz os quatro layouts REAIS; uma fixture inventada não provaria nada sobre eles.
#
#   [1] guarda de vacuidade: a fixture produz nós, arestas e `unknown` de verdade
#   [2] COMPATIBILIDADE: sem `codegraph:` declarado, o grafo é byte a byte o de hoje (golden
#       capturado com o engine PRÉ-mudança) — nenhum node ganha campo, nenhuma camada muda
#   [3] mapa declarado classifica os três layouts .NET reais que hoje caem em `unknown`
#   [4] precedência: o declarado vence a heurística embutida (inclusive quando ela acertava
#       o formato e errava o sentido — `apps/web` classificado `api` pelo segmento `web`),
#       e o primeiro padrão declarado vence os seguintes
#   [5] `unknown` declarado é FORA DA TAXONOMIA: node ganha `taxonomy:"out"` e sai do
#       denominador de `stats.layer_coverage`; `unknown` não declarado continua sendo lacuna
#   [6] o grafo com configuração continua válido (schema + `forge validate graph`)
#   [7] órfãos classificados: o warning aponta o ÚNICO código morto, não os 4 órfãos por design
#   [8] órfão por design sem candidato nenhum → sem warning de órfão (é o ponto da entrega)
#   [9] bloco `codegraph:` ausente/malformado → no-op, nunca falso positivo
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIX="$WS/tests/fixtures/codegraph-layer-map"
GOLDEN="$FIX/golden-no-config.json"
SCHEMA="$WS/template/.forge/schemas/graph.schema.json"

T="$(mktemp -d /tmp/forge-w141.XXXXXX)"
trap 'rm -rf "$T"' EXIT

[ -f "$GOLDEN" ] || { echo "FAIL [0]: golden de compatibilidade ausente ($GOLDEN)"; exit 1; }

# ── dois clones da MESMA árvore: um sem configuração (controle), um com ────────────────────
mkdir -p "$T/plain" "$T/decl"
for d in plain decl; do
  cp -R "$WS/template/.forge" "$T/$d/.forge"
  bash "$FIX/make-fixture.sh" "$T/$d" || { echo "FAIL [0]: make-fixture falhou em $d"; exit 1; }
done
G="$T/plain/.forge/scripts/graph.sh"

# FORGE.md do clone declarado: descreve os quatro layouts da própria árvore. É exatamente o
# que a issue pede — cada repositório descreve os seus layouts sem mudar o engine.
cat > "$T/decl/.forge/FORGE.md" <<'EOF'
---
forge_version: 1
codegraph:
  layers:
    - path: "apps/web"
      layer: unknown
    - path: "apps/web/src/pages"
      layer: api
    - path: "tools"
      layer: unknown
    - path: "platform/src/services/*/*.Api"
      layer: api
    - path: "platform/src/services/*/*.Handlers"
      layer: application
    - path: "platform/**/*.Kernel"
      layer: domain
    - path: "platform/src/shared/*.Persistence"
      layer: infrastructure
    - path: "packages/dotnet/*.Abstractions"
      layer: contracts
    - path: "packages/dotnet/Contoso.Sdk"
      layer: infrastructure
    - path: "legacy/src/*.Entidades"
      layer: domain
    - path: "legacy/src/*.BLL"
      layer: application
    - path: "legacy/src/*.DAL"
      layer: infrastructure
    - path: "legacy/src/*.Web"
      layer: api
  orphans_by_design:
    - "platform/src/services/*/*.Api/AssemblyMarker.cs"
---

# FORGE.md de fixture
EOF

echo "[1] guarda de vacuidade: a varredura precisa achar nós, arestas e unknown de verdade"
FORGE_ROOT="$T/plain" bash "$G" build >/dev/null 2>&1
PJ="$T/plain/.forge/graph/graph.json"
[ -f "$PJ" ] || { echo "FAIL [1]: build não produziu graph.json"; exit 1; }
counts="$(node -e '
const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const unk=g.nodes.filter(n=>n.layer==="unknown").length;
console.log(g.nodes.length, g.edges.length, unk);
' "$PJ" 2>&1)" || { echo "FAIL [1]: leitura do grafo falhou: $counts"; exit 1; }
set -- $counts
if [ "${1:-0}" -eq 0 ] || [ "${2:-0}" -eq 0 ] || [ "${3:-0}" -eq 0 ]; then
  echo "FAIL [1]: fixture vazia (nodes=${1:-0} edges=${2:-0} unknown=${3:-0}) — qualquer asserção de camada passaria por acidente"
  exit 1
fi
echo "OK [1] (nodes=$1 edges=$2 unknown=$3)"

echo "[2] compatibilidade: sem codegraph: declarado, o grafo é o de hoje (golden pré-mudança)"
cmp_out="$(node -e '
const fs=require("fs");
const g=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const golden=JSON.parse(fs.readFileSync(process.argv[2],"utf8"));
const S=(x)=>JSON.stringify(x);
if (S(g.nodes) !== S(golden.nodes)) {
  const a=new Map(golden.nodes.map(n=>[n.id,n])), diffs=[];
  for (const n of g.nodes) {
    const o=a.get(n.id);
    if (!o) { diffs.push(`node novo: ${n.id}`); continue; }
    if (S(n)!==S(o)) diffs.push(`${n.id}: ${S(o)} -> ${S(n)}`);
  }
  for (const o of golden.nodes) if (!g.nodes.some(n=>n.id===o.id)) diffs.push(`node sumiu: ${o.id}`);
  console.log("NODES-DIFF " + diffs.slice(0,6).join(" | "));
  process.exit(0);
}
if (S(g.edges) !== S(golden.edges)) { console.log("EDGES-DIFF"); process.exit(0); }
for (const k of ["nodes","edges","languages","summaries_stale","census"]) {
  if (S(g.stats[k]) !== S(golden.stats[k])) { console.log(`STATS-DIFF ${k}: ${S(golden.stats[k])} -> ${S(g.stats[k])}`); process.exit(0); }
}
console.log("IDENTICO");
' "$PJ" "$GOLDEN" 2>&1)" || { echo "FAIL [2]: comparação com o golden falhou: $cmp_out"; exit 1; }
[ "$cmp_out" = "IDENTICO" ] || { echo "FAIL [2]: sem configuração o grafo mudou — $cmp_out"; exit 1; }
echo "OK [2]"

echo "[3] mapa declarado classifica os três layouts .NET reais"
FORGE_ROOT="$T/decl" bash "$T/decl/.forge/scripts/graph.sh" build >/dev/null 2>&1
DJ="$T/decl/.forge/graph/graph.json"
[ -f "$DJ" ] || { echo "FAIL [3]: build do clone declarado não produziu graph.json"; exit 1; }
out3="$(node -e '
const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const L=new Map(g.nodes.map(n=>[n.id,n.layer]));
const esperado={
  // plataforma satélite
  "platform/src/shared/Contoso.Shared.Kernel/Guard.cs":"domain",
  "platform/src/shared/Contoso.Shared.Persistence/InvoiceRepository.cs":"infrastructure",
  "platform/src/services/billing/Contoso.Billing.Handlers/IssueInvoiceHandler.cs":"application",
  "platform/src/services/billing/Contoso.Billing.Api/InvoiceController.cs":"api",
  // pacotes compartilhados
  "packages/dotnet/Contoso.Messaging.Abstractions/IBus.cs":"contracts",
  "packages/dotnet/Contoso.Sdk/BillingClient.cs":"infrastructure",
  // monólito legado pré-Clean-Architecture
  "legacy/src/Produto.Entidades/Pedido.cs":"domain",
  "legacy/src/Produto.BLL/PedidoService.cs":"application",
  "legacy/src/Produto.DAL/PedidoDao.cs":"infrastructure",
  "legacy/src/Produto.Web/PedidoPage.cs":"api",
};
const erros=[];
for (const [id,l] of Object.entries(esperado)) {
  if (!L.has(id)) { erros.push(`${id}: node ausente do grafo`); continue; }
  if (L.get(id)!==l) erros.push(`${id}: esperado ${l}, obtido ${L.get(id)}`);
}
const csUnknown=g.nodes.filter(n=>n.lang==="csharp"&&n.layer==="unknown").map(n=>n.id);
if (csUnknown.length) erros.push(`C# ainda em unknown: ${csUnknown.join(", ")}`);
console.log(erros.length ? erros.join(" | ") : "OK");
' "$DJ" 2>&1)"
[ "$out3" = "OK" ] || { echo "FAIL [3]: $out3"; exit 1; }
echo "OK [3]"

echo "[4] precedência: declarado vence a heurística, e o primeiro padrão vence os seguintes"
out4="$(node -e '
const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const N=new Map(g.nodes.map(n=>[n.id,n]));
const erros=[];
// a heurística embutida classifica TODO apps/web como `api` (o segmento literal `web`).
// A declaração `apps/web -> unknown` tem de vencer, senão nada do que o repositório
// declara sobre frontend vale.
const btn=N.get("apps/web/src/components/Button.tsx");
if (!btn) erros.push("Button.tsx ausente");
else if (btn.layer!=="unknown") erros.push(`Button.tsx: declarado unknown, obtido ${btn.layer}`);
// primeiro match vence: `apps/web` é declarado ANTES de `apps/web/src/pages`, logo a página
// também é `unknown` — ordem de declaração é o desempate, e é do autor da configuração.
const home=N.get("apps/web/src/pages/Home.tsx");
if (!home) erros.push("Home.tsx ausente");
else if (home.layer!=="unknown") erros.push(`Home.tsx: primeiro padrão declarado deveria vencer (unknown), obtido ${home.layer}`);
// glob com ** atravessando segmentos
const guard=N.get("platform/src/shared/Contoso.Shared.Kernel/Guard.cs");
if (!guard || guard.layer!=="domain") erros.push("glob ** (platform/**/*.Kernel) não casou");
console.log(erros.length ? erros.join(" | ") : "OK");
' "$DJ" 2>&1)"
[ "$out4" = "OK" ] || { echo "FAIL [4]: $out4"; exit 1; }
echo "OK [4]"

echo "[5] unknown declarado é fora da taxonomia e sai do denominador da cobertura"
out5="$(node -e '
const fs=require("fs");
const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const p=JSON.parse(fs.readFileSync(process.argv[2],"utf8"));
const erros=[];
const out=d.nodes.filter(n=>n.taxonomy==="out").map(n=>n.id).sort();
if (!out.length) erros.push("nenhum node marcado taxonomy:out no clone declarado");
if (!out.includes("tools/codegen/gen.mjs")) erros.push("tooling declarado fora da taxonomia não foi marcado");
if (!out.includes("apps/web/src/components/Button.tsx")) erros.push("frontend declarado fora da taxonomia não foi marcado");
const c=d.stats && d.stats.layer_coverage;
if (!c) { console.log("stats.layer_coverage ausente no grafo declarado"); process.exit(0); }
const outN=d.nodes.filter(n=>n.taxonomy==="out").length;
const cls=d.nodes.filter(n=>n.layer!=="unknown").length;
const unc=d.nodes.filter(n=>n.layer==="unknown"&&n.taxonomy!=="out").length;
if (c.out_of_taxonomy!==outN) erros.push(`out_of_taxonomy=${c.out_of_taxonomy}, esperado ${outN}`);
if (c.classified!==cls) erros.push(`classified=${c.classified}, esperado ${cls}`);
if (c.unclassified!==unc) erros.push(`unclassified=${c.unclassified}, esperado ${unc}`);
if (c.denominator!==cls+unc) erros.push(`denominator=${c.denominator}, esperado ${cls+unc} (fora da taxonomia NÃO entra)`);
if (c.denominator>=d.nodes.length) erros.push("o denominador não excluiu nada — fora da taxonomia continua contado como buraco");
if (c.unclassified!==0) erros.push(`com tudo declarado não deveria sobrar lacuna, sobrou ${c.unclassified}`);
if (c.ratio!==1) erros.push(`ratio=${c.ratio}, esperado 1`);
// sem configuração o número continua HONESTO: unknown não declarado é lacuna de verdade
const cp=p.stats && p.stats.layer_coverage;
if (!cp) { erros.push("stats.layer_coverage ausente no grafo sem configuração"); }
else {
  if (cp.out_of_taxonomy!==0) erros.push(`sem configuração nada é fora da taxonomia, obtido ${cp.out_of_taxonomy}`);
  if (cp.unclassified===0) erros.push("sem configuração a lacuna real virou zero — o número deixou de ser honesto");
  if (cp.denominator!==p.nodes.length) erros.push(`sem configuração o denominador deveria ser ${p.nodes.length}, obtido ${cp.denominator}`);
  if (!(cp.ratio>0 && cp.ratio<1)) erros.push(`sem configuração o ratio deveria ficar entre 0 e 1, obtido ${cp.ratio}`);
}
console.log(erros.length ? erros.join(" | ") : "OK");
' "$DJ" "$PJ" 2>&1)"
[ "$out5" = "OK" ] || { echo "FAIL [5]: $out5"; exit 1; }
echo "OK [5]"

echo "[6] o grafo com configuração continua válido (schema + validate graph)"
sv="$(node "$WS/tools/validate-yaml.mjs" "$SCHEMA" "$DJ" 2>&1)"
case "$sv" in
  *OK*) : ;;
  *) echo "FAIL [6]: graph.json declarado não valida contra o schema: $sv"; exit 1 ;;
esac
vg="$(FORGE_ROOT="$T/decl" bash "$T/decl/.forge/scripts/graph.sh" validate 2>&1)"
case "$vg" in
  OK*) : ;;
  *) echo "FAIL [6]: validate graph reprovou o grafo declarado: $vg"; exit 1 ;;
esac
echo "OK [6]"

echo "[7] órfãos classificados: o warning aponta o código morto, não os órfãos por design"
orph="$(node -e '
const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const deg=new Map(g.nodes.map(n=>[n.id,0]));
for (const e of g.edges) {
  if (deg.has(e.from)) deg.set(e.from,deg.get(e.from)+1);
  if (e.resolved===true && deg.has(e.to)) deg.set(e.to,deg.get(e.to)+1);
}
console.log([...deg.entries()].filter(([,d])=>d===0).map(([i])=>i).sort().join(" "));
' "$DJ" 2>&1)"
n_orph="$(printf '%s\n' "$orph" | tr ' ' '\n' | grep -c . || true)"
[ "${n_orph:-0}" -ge 5 ] || { echo "FAIL [7]: a fixture deveria ter ao menos 5 órfãos (4 por design + 1 morto), tem ${n_orph:-0}: $orph"; exit 1; }
case "$vg" in
  *CalculadoraObsoleta.cs*) : ;;
  *) echo "FAIL [7]: o warning não nomeia o único código morto de verdade — saída: $vg"; exit 1 ;;
esac
for benigno in AssemblyMarker.cs 001_CriaPedido.cs checkout.spec.ts gen.mjs; do
  case "$vg" in
    *"$benigno"*) echo "FAIL [7]: órfão por design '$benigno' foi apontado como achado — saída: $vg"; exit 1 ;;
  esac
done
case "$vg" in
  *"by design"*|*"por design"*) : ;;
  *) echo "FAIL [7]: o warning não distingue órfão por design de candidato — saída: $vg"; exit 1 ;;
esac
echo "OK [7] ($n_orph órfãos, 1 candidato)"

echo "[8] só órfãos por design → sem warning de órfão"
rm -f "$T/decl/legacy/src/Produto.BLL/CalculadoraObsoleta.cs"
FORGE_ROOT="$T/decl" bash "$T/decl/.forge/scripts/graph.sh" build >/dev/null 2>&1
vg8="$(FORGE_ROOT="$T/decl" bash "$T/decl/.forge/scripts/graph.sh" validate 2>&1)"
case "$vg8" in
  OK*) : ;;
  *) echo "FAIL [8]: validate reprovou: $vg8"; exit 1 ;;
esac
case "$vg8" in
  *orphan*) echo "FAIL [8]: sem candidato algum o validate ainda alerta sobre órfãos — saída: $vg8"; exit 1 ;;
esac
echo "OK [8]"

echo "[9] bloco codegraph: ausente ou malformado → no-op"
vgp="$(FORGE_ROOT="$T/plain" bash "$G" validate 2>&1)"
case "$vgp" in
  OK*) : ;;
  *) echo "FAIL [9]: validate reprovou o clone sem configuração: $vgp"; exit 1 ;;
esac
node -e '
const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
if (g.nodes.some(n=>n.taxonomy!==undefined)) { console.log("BAD"); process.exit(0); }
console.log("OK");
' "$PJ" | grep -q '^OK$' || { echo "FAIL [9]: sem configuração algum node ganhou taxonomy"; exit 1; }
# malformado: bloco com forma errada (escalar onde se espera lista) não pode derrubar o build
mkdir -p "$T/bad" && cp -R "$WS/template/.forge" "$T/bad/.forge"
bash "$FIX/make-fixture.sh" "$T/bad" >/dev/null 2>&1
printf -- '---\nforge_version: 1\ncodegraph:\n  layers: nao-e-uma-lista\n---\n\n# bad\n' > "$T/bad/.forge/FORGE.md"
outb="$(FORGE_ROOT="$T/bad" bash "$T/bad/.forge/scripts/graph.sh" build 2>&1)"
case "$outb" in
  OK*) : ;;
  *) echo "FAIL [9]: bloco malformado derrubou o build: $outb"; exit 1 ;;
esac
node -e '
const g=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
if (g.nodes.some(n=>n.taxonomy!==undefined)) { console.log("BAD"); process.exit(0); }
console.log("OK");
' "$T/bad/.forge/graph/graph.json" | grep -q '^OK$' || { echo "FAIL [9]: bloco malformado produziu classificação"; exit 1; }
echo "OK [9]"

echo "PASS w141-codegraph-layer-map-gate"
