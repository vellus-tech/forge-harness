#!/usr/bin/env bash
# Fixture sintética congelada do golden pré-mudança (TASK-02, fix-graph-query-symbols-fusion).
# Mesmo padrão de `tests/fixtures/codegraph-layer-map/make-fixture.sh`: sem FORGE.md, sem
# config — a árvore sintética materializada aqui é fixa e determinística, para que
# `golden-pre-change/query-golden-pre-change.txt` seja uma foto estável do motor ATUAL de
# `graph.sh query` (antes de qualquer edição de graph.sh/graph-build.mjs/graph-symbols.mjs),
# usada pelas stories seguintes como oráculo byte a byte (TASK-09).
#
# Layout mínimo: uma função `processarPedido` que o motor atual acha por PATH (o arquivo se
# chama literalmente `processar-pedido.js`, então `query processarpedido` casa `node.id`), mais
# um segundo arquivo que importa o primeiro (edge real, cobre a seção `edges (N):` do golden).
#
# Uso: bash make-fixture.sh <dir-destino>
set -uo pipefail
D="${1:-}"
[ -n "$D" ] || { echo "FAIL (uso: make-fixture.sh <dir>)"; exit 1; }

mkdir -p "$D/src/handlers"
cat > "$D/src/handlers/processar-pedido.js" <<'EOF'
export function processarPedido(pedido) {
  return pedido;
}
EOF
cat > "$D/src/handlers/index.js" <<'EOF'
import { processarPedido } from './processar-pedido.js';
export function handle(pedido) {
  return processarPedido(pedido);
}
EOF
