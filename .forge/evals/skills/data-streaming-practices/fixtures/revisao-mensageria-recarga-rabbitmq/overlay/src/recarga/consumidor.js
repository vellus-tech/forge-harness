// Consumidor que credita o saldo do cartão de transporte a partir do evento de recarga.
const { creditarSaldo } = require('./saldo-repositorio');

const FILA = 'saldo.creditar-recarga';
const processados = new Set();

async function consumir(canal) {
  await canal.consume(FILA, async (msg) => {
    const evento = JSON.parse(msg.content.toString());
    if (msg.fields.redelivered) {
      canal.ack(msg);
      return;
    }
    if (processados.has(evento.event_id)) {
      canal.ack(msg);
      return;
    }
    try {
      await creditarSaldo(evento.cartao_transporte_id, evento.valor_centavos);
      processados.add(evento.event_id);
      canal.ack(msg);
    } catch (erro) {
      console.error('falha ao creditar recarga', evento.event_id, erro.message);
      canal.nack(msg);
    }
  });
}

module.exports = { consumir };
