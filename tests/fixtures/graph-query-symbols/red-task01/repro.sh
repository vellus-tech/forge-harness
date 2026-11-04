#!/usr/bin/env bash
# Red SDD-level do defeito original (TASK-01, fix-graph-query-symbols-fusion) — bugfix.md §1:
# `graph.sh query` filtra só node.id/edge.from/edge.to, nunca abre symbols.json; uma busca por
# nome de FUNÇÃO (processarPedido, declarada em src/handlers/h1.js, não em nenhum path) não acha
# nada hoje. Este script roda build -> symbols -> query sobre um FORGE_ROOT ISOLADO e falha de
# verdade (rc=1) enquanto o defeito existir.
#
# O FORGE_ROOT isolado é um diretório de mktemp (nunca este próprio diretório rastreado): copia
# só o conteúdo de src/ para lá antes de build/symbols/query, e limpa via `rm -rf` sobre esse
# mktemp nos dois ramos — tests/w213-arvore-rastreada-gate.sh reprova qualquer escrita (inclusive
# `rm`) resolvida a partir de `${BASH_SOURCE[0]}` (a árvore rastreada real), mesmo quando o alvo é
# um `.forge/` que o .gitignore cobre; rodar build/symbols/query sobre uma cópia em mktemp
# reproduz o defeito exatamente igual (mesmo conteúdo de h1.js) sem jamais escrever dentro da
# árvore rastreada.
#
# Uso: bash repro.sh
set -euo pipefail

FIX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRAPH_SH="$FIX/../../../../template/.forge/scripts/graph.sh"

TMPROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMPROOT"; }

cp -R "$FIX/src" "$TMPROOT/src"

FORGE_ROOT="$TMPROOT" bash "$GRAPH_SH" build >/dev/null
FORGE_ROOT="$TMPROOT" bash "$GRAPH_SH" symbols >/dev/null

OUT="$(FORGE_ROOT="$TMPROOT" bash "$GRAPH_SH" query processarPedido 2>&1)"

if ! printf '%s\n' "$OUT" | grep -q '^symbols ('; then
  echo "FAIL [red-task01-processarPedido] query nao lista simbolo processarPedido"
  cleanup
  exit 1
fi

echo "OK [red-task01-processarPedido]"
cleanup
exit 0
