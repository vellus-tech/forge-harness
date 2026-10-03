// Consumidor único (Single Active Consumer) que envia os lançamentos ao banco liquidante na ordem em que chegam.
// A ordem importa: débito e estorno da mesma conta de lojista precisam chegar ao liquidante na sequência original.
//
// Retry de erro transitório (banco liquidante indisponível) é feito AQUI, dentro do próprio consumidor, e não
// pelo delayed retry nativo da quorum (delayed-retry-type) nem por filas de espera com TTL+DLX. Qualquer uma
// dessas duas formas tira a mensagem da ordem: enquanto ela espera fora da fila principal, as mensagens
// seguintes da mesma fila (mesma conta ou não — a ordem aqui é global, por causa do Single Active Consumer)
// são entregues e processadas na frente dela. Numa fila que promete ordem isso é o antipattern RMQ-AP-26.
// Ver docs/design-retry-liquidacao.md para o raciocínio completo e as fontes.
const { enviarAoLiquidante, ErroTransitorio } = require('./cliente-liquidante');
const { jaProcessado, registrarProcessado } = require('./inbox');

// Patamares de espera pedidos (5s, 30s, 5min). O último é um teto: depois dele, o consumidor continua
// tentando a cada 5min (com jitter) enquanto o erro for transitório — nunca desiste e derruba a mensagem
// para a DLX só por timeout, porque isso adiantaria as mensagens seguintes da fila fora de ordem.
const PATAMARES_MS = [5_000, 30_000, 5 * 60_000];
const TETO_MS = PATAMARES_MS[PATAMARES_MS.length - 1];
const JITTER_MAX_MS = 3_000; // RMQ-BP: jitter no cliente para retry de chamada remota (o retry nativo é linear e sem jitter; o nosso, feito à mão, ganha o jitter que falta nele).

function esperaMs(tentativa) {
  const base = tentativa < PATAMARES_MS.length ? PATAMARES_MS[tentativa] : TETO_MS;
  return base + Math.floor(Math.random() * JITTER_MAX_MS);
}

function dormir(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function consumir(canal, { logger = console } = {}) {
  await canal.prefetch(1);
  await canal.consume('liquidacao.lancamentos', async (msg) => {
    const lancamento = JSON.parse(msg.content.toString());
    if (await jaProcessado(lancamento.event_id)) {
      canal.ack(msg);
      return;
    }

    let tentativa = 0;
    for (;;) {
      try {
        await enviarAoLiquidante(lancamento);
        await registrarProcessado(lancamento.event_id);
        canal.ack(msg);
        return;
      } catch (erro) {
        if (!(erro instanceof ErroTransitorio)) {
          // Erro permanente (dado inválido, regra de negócio): não é da alçada de retry. Vai para a DLX/parking
          // lot sem requeue (RMQ-AP-10 é exatamente `requeue=true` aqui, por isso nunca é usado) e o consumidor
          // segue para a próxima mensagem. Isso é um poison message (RMQ-BP-11): trate como incidente pontual,
          // não como o caminho normal do banco liquidante fora do ar.
          logger.error('liquidacao.consumidor: erro permanente, enviando para a DLX', {
            event_id: lancamento.event_id,
            conta: lancamento.conta_id,
            erro: erro.message,
          });
          canal.reject(msg, false);
          return;
        }

        // Erro transitório: banco liquidante indisponível. Retry aqui mesmo, sem soltar a mensagem — a fila
        // fica bloqueada atrás dela (SAC + prefetch(1) já serializa a entrega), o que é o comportamento correto
        // porque a indisponibilidade do liquidante afeta todo mundo, não só esta conta: não há como continuar
        // processando as próximas em ordem sem primeiro resolver esta.
        const espera = esperaMs(tentativa);
        logger.warn('liquidacao.consumidor: erro transitório, aguardando para tentar de novo', {
          event_id: lancamento.event_id,
          conta: lancamento.conta_id,
          tentativa: tentativa + 1,
          espera_ms: espera,
        });
        tentativa += 1;
        await dormir(espera);
      }
    }
  });
}

module.exports = { consumir };
