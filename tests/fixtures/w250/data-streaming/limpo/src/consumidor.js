const ch = await conexao.createConfirmChannel();
await ch.prefetch(50);
ch.consume("pagamentos", tratar, { noAck: false });
ch.nack(msg, false, false);
ch.publish("dominio.eventos", "pedido.criado", Buffer.from(corpo), { persistent: true });
const opcoes = { acks: "all" };
log.info("redelivered", msg.fields.redelivered);
const processedAt = Date.now();
const valor = mapa.get("x");
