#!/usr/bin/env bash
# Red SDD-level do defeito original (TASK-01, fix-graph-query-symbols-fusion) — bugfix.md §1:
# `graph.sh query` filtra só node.id/edge.from/edge.to, nunca abre symbols.json; uma busca por
# nome de FUNÇÃO (processarPedido, declarada em src/handlers/h1.js, não em nenhum path) não acha
# nada hoje. Este script roda build -> symbols -> query sobre um FORGE_ROOT isolado (este próprio
# diretório, nunca o root do repositório) e falha de verdade (rc=1) enquanto o defeito existir.
#
# Uso: bash repro.sh
set -euo pipefail

FIX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRAPH_SH="$FIX/../../../../template/.forge/scripts/graph.sh"

cleanup() { rm -rf "$FIX/.forge"; }

FORGE_ROOT="$FIX" bash "$GRAPH_SH" build >/dev/null
FORGE_ROOT="$FIX" bash "$GRAPH_SH" symbols >/dev/null

OUT="$(FORGE_ROOT="$FIX" bash "$GRAPH_SH" query processarPedido 2>&1)"

if ! printf '%s\n' "$OUT" | grep -q '^symbols ('; then
  echo "FAIL [red-task01-processarPedido] query nao lista simbolo processarPedido"
  cleanup
  exit 1
fi

echo "OK [red-task01-processarPedido]"
cleanup
exit 0
