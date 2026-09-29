// Consumidor único (Single Active Consumer) que envia os lançamentos ao banco liquidante na ordem em que chegam.
// A ordem importa: débito e estorno da mesma conta de lojista precisam chegar ao liquidante na sequência original.
//
// Retry: quando o liquidante está fora do ar (ErroTransitorio), a mensagem NÃO é ack/nack — o handler
// fica esperando e tentando de novo (5s, depois 30s, depois 5min) antes de decidir. Como o prefetch é 1
// e o consumidor é único (SAC), nenhuma outra mensagem da fila avança enquanto essa espera acontece, o que
// preserva a ordem por conta de lojista sem precisar de fila auxiliar com delay. O efeito colateral aceito é
// a fila inteira parar de avançar durante a indisponibilidade do liquidante (ver docs/design-retry-liquidacao.md).
const { enviarAoLiquidante, ErroTransitorio } = require('./cliente-liquidante');
const { jaProcessado, registrarProcessado } = require('./inbox');

const ESPERAS_MS = [5_000, 30_000, 300_000]; // 5s, 30s, 5min

function aguardar(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function consumir(canal) {
  await canal.prefetch(1);
  await canal.consume('liquidacao.lancamentos', async (msg) => {
    const lancamento = JSON.parse(msg.content.toString());
    if (await jaProcessado(lancamento.event_id)) {
      canal.ack(msg);
      return;
    }

    for (let tentativa = 0; ; tentativa++) {
      try {
        await enviarAoLiquidante(lancamento);
        await registrarProcessado(lancamento.event_id);
        canal.ack(msg);
        return;
      } catch (erro) {
        const esgotouRetriesLocais = tentativa >= ESPERAS_MS.length;
        if (!(erro instanceof ErroTransitorio) || esgotouRetriesLocais) {
          // Erro definitivo do liquidante, ou já tentamos 5s + 30s + 5min sem sucesso: desiste desta
          // mensagem. requeue=false + x-dead-letter-exchange (definitions.json) manda para a DLQ em vez
          // de descartar silenciosamente, que é o que acontece hoje.
          canal.reject(msg, false);
          return;
        }
        await aguardar(ESPERAS_MS[tentativa]);
        // continua o for: nova tentativa, mensagem segue unacked no broker o tempo todo.
      }
    }
  });
}

module.exports = { consumir };
