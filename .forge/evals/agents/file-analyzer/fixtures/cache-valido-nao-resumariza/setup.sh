#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness + projeto TypeScript de bilhetagem + grafo construído.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/." "$TARGET/"
# Grafo determinista (summaries nascem null).
bash "$TARGET/.forge/scripts/graph.sh" build >/dev/null
# Semeia summaries já curados no cache, amarrados ao fingerprint atual de cada nó, e reconstrói para o graph.json carregá-los.
node -e '
const fs=require("fs");const [g,c]=[process.argv[1],process.argv[2]];
const graph=JSON.parse(fs.readFileSync(g,"utf8"));const seed=JSON.parse(process.argv[3]);
const out=fs.existsSync(c)?JSON.parse(fs.readFileSync(c,"utf8")):{};
for(const [id,summary] of Object.entries(seed)){const n=graph.nodes.find(x=>x.id===id);if(!n)throw new Error("nó ausente: "+id);out[id]={fingerprint:n.fingerprint,summary};}
fs.writeFileSync(c,JSON.stringify(out,null,2)+"\n");
' "$TARGET/.forge/graph/graph.json" "$TARGET/.forge/graph/cache/summaries.json" '{"src/shared/money.ts":"Value object de dinheiro em centavos inteiros; expõe Money.deCentavos e aplicarDesconto com arredondamento; sem dependências internas.","src/integracao/calculo-integracao.ts":"Calcula a tarifa do segundo embarque na integração: 25% de desconto quando há troca de modal em até 120 min; depende do TarifaRepository e de Money."}'
bash "$TARGET/.forge/scripts/graph.sh" build >/dev/null
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" add -f .forge/graph
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial com grafo construído"
# Edição só cosmética (comentários e reindentação), não commitada: o fingerprint estrutural não muda.
cp "$HERE/cosmetic/src/integracao/calculo-integracao.ts" "$TARGET/src/integracao/calculo-integracao.ts"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
