#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness + base "Rota Única" + módulo Tarifação com design.md acima de 3.000 linhas.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/../_base-rota-unica/overlay/." "$TARGET/"
cp -R "$HERE/overlay/." "$TARGET/"
# O design.md gigante é gerado (cabeçalho + apêndice de 400 linhas de ônibus + cauda) para manter a fixture pequena no repositório.
OUT="$TARGET/docs/product/modules/tarifacao/design.md"
{
  cat "$HERE/parts/head.md"
  for i in $(seq 1 400); do
    n=$(printf '%03d' "$i")
    cat <<LINHA
### A.$i — Linha $n (Terminal Leste ↔ Bairro $n)

- Operadora (tenant): $( [ $((i % 3)) -eq 0 ] && echo "Expresso Sul" || { [ $((i % 3)) -eq 1 ] && echo "Viação Leste" || echo "TransNorte"; } )
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: \`GET /v1/tarifas/linhas/$n?faixa={faixa}\` → 200 \`{ linha: "$n", valor: 4.4 }\`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

LINHA
  done
  cat "$HERE/parts/tail.md"
} > "$OUT"
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
