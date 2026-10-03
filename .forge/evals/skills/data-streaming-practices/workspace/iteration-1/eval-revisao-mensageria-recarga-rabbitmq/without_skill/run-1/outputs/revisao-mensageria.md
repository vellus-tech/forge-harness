# Revisão da mensageria do serviço de recarga (pré-upgrade RabbitMQ 3.13 → 4.3)

## Sumário executivo

Os dois incidentes relatados têm causa raiz identificável no código atual, não em falta de infraestrutura, e ambos pioram (em vez de melhorar) com o upgrade para o RabbitMQ 4.3 se nada mudar antes: a política `ha-mode`/`ha-sync-mode` usada em `infra/rabbitmq/definitions.json` depende de filas clássicas espelhadas, um recurso removido no RabbitMQ 4.0 — o cluster não vai nem subir com essa política aplicada. Recomendo tratar isso como bloqueador do upgrade, não como item cosmético. Abaixo está o diagnóstico ponto a ponto e o desenho do retry com espera. Nenhum código foi alterado nesta revisão.

## Incidente 1 — recarga paga que some depois de reinício de nó

Causa raiz, em ordem de impacto:

1. **`src/recarga/consumidor.js` credita o guarda de redelivery errado.** O trecho `if (msg.fields.redelivered) { canal.ack(msg); return; }` trata toda mensagem redelivered como duplicata e a confirma sem processar. `redelivered` não significa duplicata — significa apenas que essa entrega não é a primeira tentativa de entrega daquela mensagem. Quando o nó que hospeda a fila cai (o cenário do incidente), as mensagens não confirmadas são reenfileiradas e reentregues com `redelivered = true` no novo mestre; com o código atual, essa reentrega é confirmada sem chamar `creditarSaldo`, e a recarga paga nunca cai no saldo. Esse é o mecanismo mais provável do incidente relatado — condiz exatamente com "some depois de reinício de nó".
2. **`src/recarga/publicador.js` publica sem marcar a mensagem como persistente e sem confirms.** `canal.publish(EXCHANGE, 'recarga.confirmada', Buffer.from(...))` é chamado sem a opção `{ persistent: true }` e o canal não é um `confirmChannel`. Mesmo com exchange e fila duráveis, uma mensagem publicada sem `persistent: true` não é gravada em disco — ela pode ser perdida se o broker (ou o nó que a recebeu) reiniciar antes de replicar. Sem confirms, o publicador também não tem como saber se a mensagem chegou a ser roteada e persistida antes de considerar a recarga "confirmada" a jusante.
3. **A idempotência é um `Set` em memória (`processados`) no processo do consumidor.** Ele é perdido a cada restart/deploy, não é compartilhado entre réplicas do consumidor (se o serviço escalar horizontalmente) e cresce sem limite. Ele não deveria ser a fonte de verdade de dedupe — o guarda de "já processei isso" tem que estar no Postgres, no mesmo lugar onde o crédito é gravado.
4. **A política `ha-mode: all` em `definitions.json`** replica filas clássicas de forma assíncrona por padrão salvo quando `ha-sync-mode: automatic` mantém tudo sincronizado (o que já está configurado), mas ainda assim há uma janela entre a chegada da mensagem no mestre e a sincronização do mirror; um reinício de nó nessa janela pode perder mensagens não persistidas. Esse mecanismo inteiro está sendo aposentado (ver seção de risco do upgrade).

## Incidente 2 — mensagem girando por horas quando o Postgres cai

Causa raiz: em `src/recarga/consumidor.js`, o bloco `catch` chama `canal.nack(msg)` sem o segundo argumento (`requeue`). O padrão do `nack` no amqplib é `requeue = true`, então toda falha ao creditar o saldo — inclusive uma falha transitória de conexão com o Postgres — devolve a mensagem imediatamente para o início da fila, sem qualquer espera. Isso cria um loop de retry apertado: a mesma mensagem é entregue, falha, é reenfileirada e é entregue de novo, em sequência, potencialmente milhares de vezes por segundo, cada tentativa abrindo uma conexão/query contra um Postgres que já está fora do ar — o que também atrasa a recuperação do Postgres quando ele volta, porque o consumidor bombardeia o banco no instante em que ele volta a aceitar conexões. Não existe backoff, não existe limite de tentativas, e não existe fila de destino para mensagens que falham repetidamente (dead-letter).

## O que mudar em cada ponto

### `src/infra/rabbit.js`
- Adicionar listeners de `error` e `close` na conexão e reconectar com backoff (o código atual não trata queda de conexão; se o broker reiniciar, o processo fica com uma conexão morta e não se recupera sozinho).
- Expor duas formas de canal: um `confirmChannel` para o publicador (necessário para publisher confirms) e um canal comum para o consumidor, com `channel.prefetch(N)` definido explicitamente — hoje não há prefetch configurado, então o consumidor puxa mensagens sem limite, o que agrava o problema de "girando por horas" descrito acima (mais mensagens em voo por processo).

### `src/recarga/publicador.js`
- Publicar com `{ persistent: true }` e usar um `confirmChannel`, aguardando o callback/promise de confirmação (`channel.publish` retorna via `waitForConfirms` ou callback) antes de considerar o evento efetivamente publicado. Sem isso, "recarga confirmada" no domínio pode não corresponder a "evento gravado e replicado" no broker.
- Tratar o valor de retorno de `canal.publish` (indicador de backpressure do buffer de escrita) — hoje é ignorado.

### `src/recarga/consumidor.js`
- Remover o `if (msg.fields.redelivered) { ack; return; }`. Esse é o bug mais grave e mais direto para o incidente 1: redelivered não é sinônimo de duplicata.
- Mover a dedupe para o Postgres: gravar `event_id` processado na mesma transação que credita o saldo (ver abaixo), e tratar violação de unicidade como "já processado, ack e sai" — dedupe real e sobrevivente a restart, em vez do `Set` em memória.
- Trocar `canal.nack(msg)` no catch por `canal.nack(msg, false, false)` (sem requeue) e publicar a mensagem original em uma exchange/fila de retry com espera (ver seção de retry abaixo) em vez de deixar o RabbitMQ reenfileirar imediatamente. Configurar `channel.prefetch` baixo (ex.: 10–20) para limitar o dano de qualquer novo ciclo de falha.

### `src/recarga/saldo-repositorio.js`
- Fazer o crédito e o registro de dedupe na mesma transação: `BEGIN; INSERT INTO recargas_processadas(event_id) VALUES ($1); UPDATE saldo_cartao SET saldo_centavos = saldo_centavos + $2 WHERE cartao_transporte_id = $3; COMMIT;`, com `event_id` como chave única. Isso torna o crédito idempotente de verdade (nível de banco, não de processo) e resolve tanto duplicata quanto o problema de estado perdido em restart do consumidor.

### `infra/rabbitmq/definitions.json`
- Trocar `arguments: {}` das filas `saldo.creditar-recarga` e `extrato.registrar-recarga` para `x-queue-type: quorum` e remover a política `ha-mode`/`ha-sync-mode` (ver risco do upgrade abaixo — é obrigatório antes do 4.3, não opcional).
- Adicionar uma exchange e uma fila de dead-letter (`recarga.dlx` / `saldo.creditar-recarga.dlq`) e configurar `x-dead-letter-exchange` nas filas principais, para reter mensagens que esgotarem as tentativas de retry em vez de girar indefinidamente.
- Se o desenho de retry por TTL+DLX abaixo for adotado, criar as filas de espera (`saldo.creditar-recarga.retry-10s`, `.retry-1m`, `.retry-10m`) com `x-message-ttl` e `x-dead-letter-exchange` apontando de volta para `recarga.eventos`/fila principal.

### `infra/rabbitmq/enabled_plugins`
- Manter `rabbitmq_delayed_message_exchange` habilitado não é a recomendação para o retry deste fluxo — ver justificativa na seção de retry. Ele pode continuar habilitado para outros usos, mas não deveria ser o mecanismo de espera do retry de recarga.

## Retry com espera — desenho recomendado

Não recomendo usar o `rabbitmq_delayed_message_exchange` para este retry, apesar de já estar habilitado. O motivo: mensagens "atrasadas" nesse plugin ficam retidas em memória/Mnesia em um único nó enquanto esperam, sem replicação entre os nós do cluster — se aquele nó reiniciar durante a espera, a mensagem atrasada é perdida, o que reproduziria o incidente 1 dentro do próprio mecanismo de retry. É um risco conhecido do plugin e particularmente relevante aqui porque o ponto de partida da revisão é justamente "recarga que some no reinício de nó".

Desenho recomendado — TTL por fila + dead-letter (funciona com quorum queues e sobrevive a reinício de nó, porque a espera vira uma mensagem durável numa fila normal, não um timer em memória):

1. Fila principal `saldo.creditar-recarga` (quorum) com `x-dead-letter-exchange: recarga.retry-exchange` e `x-dead-letter-routing-key: retry.10s` aplicado só quando o consumidor decide fazer nack sem requeue (ou seja, a mensagem só cai aqui de propósito, via `nack(msg, false, false)`).
2. Três filas de espera, cada uma quorum + TTL fixo, sem consumidor algum, cujo único papel é expirar e devolver a mensagem: `retry.10s` (TTL 10s, DLX de volta para `recarga.eventos` com a routing key original), `retry.1m` (TTL 60s) e `retry.10m` (TTL 600s), formando backoff crescente. O consumidor escolhe a routing key de retry (`retry.10s` → `retry.1m` → `retry.10m`) olhando um contador de tentativas no header da mensagem (`x-death` já vem preenchido pelo próprio RabbitMQ a cada dead-letter, então dá para ler o número de tentativas sem estado adicional).
3. Depois de esgotar as três tentativas (ou um limite definido, ex.: 5), a mensagem vai para uma fila de dead-letter final (`saldo.creditar-recarga.dlq`), sem TTL, para investigação manual — nunca é descartada silenciosamente.
4. Esse desenho tolera exatamente o cenário do incidente 2: se o Postgres cair, a primeira falha manda a mensagem para `retry.10s`; se ainda estiver fora do ar, vai para `retry.1m`, depois `retry.10m` — sem bombardear o banco, e sem depender de nenhum estado em memória do processo consumidor.

## Risco específico do upgrade RabbitMQ 3.13 → 4.3

O RabbitMQ 4.0 removeu o suporte a filas clássicas espelhadas (o mecanismo por trás de `ha-mode`/`ha-sync-mode`, já deprecado desde a série 3.x com avisos de remoção). `infra/rabbitmq/definitions.json` hoje declara a política `ha-todas` com `ha-mode: all` aplicada a todas as filas via `pattern: ".*"`. Isso precisa ser resolvido **antes** do upgrade, não depois: migrar `saldo.creditar-recarga` e `extrato.registrar-recarga` (e as filas de retry propostas acima) para `x-queue-type: quorum` e remover a política `ha-mode`. Quorum queues replicam por Raft, têm garantias de durabilidade mais fortes que o mirroring clássico (o que também ajuda a fechar o incidente 1) e são o caminho suportado no 4.3. Recomendo migrar as filas e validar em homologação como uma etapa separada, antes de agendar a janela do upgrade — não como parte do mesmo evento.

## Escopo desta revisão

Este documento é só diagnóstico e desenho, conforme solicitado — nenhum arquivo de código ou de infraestrutura foi alterado nesta revisão.
