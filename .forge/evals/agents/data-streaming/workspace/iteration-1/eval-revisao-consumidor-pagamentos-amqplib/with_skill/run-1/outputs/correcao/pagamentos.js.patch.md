# src/pagamentos.js — versão corrigida

Corrige OBX-AP-01 (dual write) e, por consequência, RMQ-AP-08 (publish sem confirms): o `UPDATE`
e o registro do evento passam a ser a mesma transação no PostgreSQL (outbox transacional); quem
publica no RabbitMQ com publisher confirms é um relay separado (fora deste handler), que lê a
tabela `outbox_eventos` e marca a linha como enviada — nunca CDC como contrato público, o relay
é interno.

```js
const { Pool } = require('pg');

const db = new Pool({ connectionString: process.env.DATABASE_URL });

async function processarPagamento(evento) {
  const client = await db.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'UPDATE pedidos SET status = $1 WHERE id = $2',
      ['PAGO', evento.pedidoId],
    );
    await client.query(
      `INSERT INTO outbox_eventos (aggregate_id, tipo, payload, criado_em, enviado)
       VALUES ($1, $2, $3, now(), false)`,
      [
        evento.pedidoId,
        'pedido.pago',
        JSON.stringify({ pedidoId: evento.pedidoId, valorCentavos: evento.valorCentavos }),
      ],
    );
    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
  // O publish em 'pedidos'/'pedido.pago' sai daqui. Um relay (polling da outbox_eventos, ou
  // CDC/Debezium lendo o WAL) publica de forma assíncrona, com o canal em modo confirm
  // (ch.confirmSelect() / createConfirmChannel() no amqplib) e delivery_mode/persistent: true,
  // e só então marca outbox_eventos.enviado = true. Isso também resolve o RMQ-AP-08: o produtor
  // passa a saber se o broker aceitou a mensagem.
}

module.exports = { processarPagamento };
```

O schema de `outbox_eventos` e a transação que a grava junto com o `UPDATE` em `pedidos` são do
dono do store relacional (`data-relational`); este especialista responde pelo mecanismo do relay
e pela publicação.
