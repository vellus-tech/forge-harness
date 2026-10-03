// Serviço de faturamento: emite a fatura quando o pedido é confirmado.
// O consumidor de eventos de pedido ainda não existe.
export async function emitirFatura(pedidoId: string, valorCentavos: number): Promise<void> {
  throw new Error('não implementado');
}
