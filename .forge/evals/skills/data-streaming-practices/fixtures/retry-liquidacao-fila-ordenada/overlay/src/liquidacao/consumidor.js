// Consumidor único (Single Active Consumer) que envia os lançamentos ao banco liquidante na ordem em que chegam.
// A ordem importa: débito e estorno da mesma conta de lojista precisam chegar ao liquidante na sequência original.
const { enviarAoLiquidante, ErroTransitorio } = require('./cliente-liquidante');
const { jaProcessado, registrarProcessado } = require('./inbox');

async function consumir(canal) {
  await canal.prefetch(1);
  await canal.consume('liquidacao.lancamentos', async (msg) => {
    const lancamento = JSON.parse(msg.content.toString());
    if (await jaProcessado(lancamento.event_id)) {
      canal.ack(msg);
      return;
    }
    try {
      await enviarAoLiquidante(lancamento);
      await registrarProcessado(lancamento.event_id);
      canal.ack(msg);
    } catch (erro) {
      if (erro instanceof ErroTransitorio) {
        canal.reject(msg, false);
        return;
      }
      canal.reject(msg, false);
    }
  });
}

module.exports = { consumir };
