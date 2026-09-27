channel.publish(ex, rk, Buffer.from(JSON.stringify({ pedidoId, pan: cartao.pan, cvv: cartao.cvv })));
const evt = { cardNumber: req.body.cardNumber };
