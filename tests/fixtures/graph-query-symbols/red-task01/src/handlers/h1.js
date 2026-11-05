// Fixture do Red SDD-level (TASK-01, fix-graph-query-symbols-fusion) — função real, extensão
// .js real (exceção explícita nº2 da convenção de fixtures do tasks.md): precisa ser reconhecida
// pelo mapa LANG de graph-build.mjs/graph-symbols.mjs para que a reprodução do defeito seja real.
// Vive sob um FORGE_ROOT isolado (red-task01/), nunca o root do repositório.
export function processarPedido(pedido) {
  return pedido;
}
