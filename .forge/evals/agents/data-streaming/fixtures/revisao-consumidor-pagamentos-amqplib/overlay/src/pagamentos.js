const { Pool } = require('pg');
const amqp = require('amqplib');

const db = new Pool({ connectionString: process.env.DATABASE_URL });
let canal;

async function canalDePublicacao() {
  if (!canal) {
    const conn = await amqp.connect(process.env.AMQP_URL);
    canal = await conn.createChannel();
  }
  return canal;
}

async function processarPagamento(evento) {
  await db.query('UPDATE pedidos SET status = $1 WHERE id = $2', ['PAGO', evento.pedidoId]);
  const ch = await canalDePublicacao();
  ch.publish('pedidos', 'pedido.pago', Buffer.from(JSON.stringify({ pedidoId: evento.pedidoId, valorCentavos: evento.valorCentavos })), { persistent: true });
}

module.exports = { processarPagamento };
