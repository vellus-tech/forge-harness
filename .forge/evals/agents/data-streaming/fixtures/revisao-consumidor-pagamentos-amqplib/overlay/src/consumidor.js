const amqp = require('amqplib');
const { processarPagamento } = require('./pagamentos');

async function iniciar() {
  const conn = await amqp.connect(process.env.AMQP_URL);
  const ch = await conn.createChannel();
  await ch.assertQueue('pagamentos', { durable: true });
  ch.consume('pagamentos', async (msg) => {
    try {
      await processarPagamento(JSON.parse(msg.content.toString()));
      ch.ack(msg);
    } catch (e) {
      console.error('falha ao processar pagamento', e.message);
      ch.nack(msg);
    }
  }, { noAck: true });
}

iniciar();
