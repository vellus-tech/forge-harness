// Trecho ilustrativo: classificar o erro para o consumidor decidir
// requeue (transitório) x dead-letter (permanente). Não é o arquivo
// inteiro corrigido — só o que muda em relação ao original.

class ErroPermanente extends Error {}

async function processarPagamento(evento) {
  if (!evento || typeof evento.pedidoId !== 'string') {
    // payload malformado nunca vai "consertar sozinho" numa reentrega
    throw new ErroPermanente('evento sem pedidoId válido');
  }

  await db.query('UPDATE pedidos SET status = $1 WHERE id = $2', ['PAGO', evento.pedidoId]);

  const ch = await canalDePublicacao();
  ch.publish(
    'pedidos',
    'pedido.pago',
    Buffer.from(JSON.stringify({ pedidoId: evento.pedidoId, valorCentavos: evento.valorCentavos })),
    { persistent: true },
  );
}

module.exports = { processarPagamento, ErroPermanente };
