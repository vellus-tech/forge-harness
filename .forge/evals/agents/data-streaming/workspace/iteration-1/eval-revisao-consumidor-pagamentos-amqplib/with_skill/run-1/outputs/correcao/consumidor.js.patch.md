# src/consumidor.js — versão corrigida

Corrige RMQ-AP-10 (requeue infinito, a causa do laço) e RMQ-AP-01 (auto-ack): ack manual só depois
do efeito persistir, `nack` com `requeue=false` para erro permanente (vai para a DLX da policy quorum
— ver `policy.json.patch.md`), e `prefetch` explícito para não afogar o worker com mensagens em voo.

```js
const amqp = require('amqplib');
const { processarPagamento } = require('./pagamentos');

const PREFETCH = 10;

async function iniciar() {
  const conn = await amqp.connect(process.env.AMQP_URL);
  const ch = await conn.createChannel();
  await ch.assertQueue('pagamentos', { durable: true }); // fila migrada para quorum — ver policy.json.patch.md
  await ch.prefetch(PREFETCH);

  ch.consume('pagamentos', async (msg) => {
    try {
      await processarPagamento(JSON.parse(msg.content.toString()));
      ch.ack(msg);
    } catch (e) {
      console.error('falha ao processar pagamento', e.message);
      // erro permanente (payload inválido, regra de negócio): reject/nack sem requeue,
      // a mensagem vai para a DLX (pagamentos.dlx -> pagamentos.parking) e não volta a esta fila.
      // Nunca nack(msg) simples: requeue=true por padrão no amqplib, e basic.nack não conta
      // para o delivery-limit em quorum queue — é a causa do laço original.
      ch.nack(msg, false, false);

      // Se em algum caso o erro for transitório (ex.: dependência externa fora do ar) e valer
      // retry, não reenfileirar na mesma fila: publique numa fila de espera com TTL (ou use o
      // retry atrasado nativo do 4.3, delayed-retry-type/min/max na policy) e ack a mensagem
      // original — nunca nack(requeue=true) como mecanismo de retry.
    }
  }, { noAck: false });
}

iniciar();
```
