const amqp = require('amqplib');
const { processarPagamento, ErroPermanente } = require('./pagamentos');

async function iniciar() {
  const conn = await amqp.connect(process.env.AMQP_URL);
  conn.on('error', (e) => console.error('conexão AMQP com erro', e.message));
  conn.on('close', () => console.error('conexão AMQP fechada'));

  const ch = await conn.createChannel();
  ch.on('error', (e) => console.error('canal AMQP com erro', e.message));

  // Limita quantas mensagens ficam "em voo" por vez — sem isso o broker
  // entrega no ritmo máximo, e um erro permanente vira laço apertado.
  await ch.prefetch(1);

  await ch.assertQueue('pagamentos', { durable: true });

  // noAck: false (padrão) — precisa ser manual porque o handler chama
  // ch.ack/ch.nack. Com noAck: true o broker já dá a mensagem como
  // confirmada na entrega; chamar ack/nack depois disso é o bug original.
  ch.consume('pagamentos', async (msg) => {
    try {
      await processarPagamento(JSON.parse(msg.content.toString()));
      ch.ack(msg);
    } catch (e) {
      if (e instanceof ErroPermanente) {
        // Mensagem malformada/inválida: não adianta reentregar.
        // requeue: false → vai para a dead-letter-exchange configurada
        // na policy (ver policy.corrigida.json), em vez de voltar pro
        // início da fila e ser reentregue instantaneamente.
        console.error('mensagem descartada (erro permanente)', e.message);
        ch.nack(msg, false, false);
      } else {
        // Erro transitório (ex.: Postgres fora do ar) — aqui vale
        // requeue, mas o ideal é combinar com delivery-limit da quorum
        // queue para não reentregar para sempre.
        console.error('falha transitória ao processar pagamento', e.message);
        ch.nack(msg, false, true);
      }
    }
  }, { noAck: false });
}

iniciar();
