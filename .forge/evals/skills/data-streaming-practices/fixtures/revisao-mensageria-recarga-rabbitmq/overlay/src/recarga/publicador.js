// Publica o evento de recarga confirmada para os consumidores de saldo e de extrato.
const EXCHANGE = 'recarga.eventos';

async function publicarRecargaConfirmada(canal, recarga) {
  const evento = {
    event_id: recarga.id,
    cartao_transporte_id: recarga.cartaoTransporteId,
    valor_centavos: recarga.valorCentavos,
    confirmada_em: new Date().toISOString(),
  };
  canal.publish(EXCHANGE, 'recarga.confirmada', Buffer.from(JSON.stringify(evento)));
}

module.exports = { publicarRecargaConfirmada };
