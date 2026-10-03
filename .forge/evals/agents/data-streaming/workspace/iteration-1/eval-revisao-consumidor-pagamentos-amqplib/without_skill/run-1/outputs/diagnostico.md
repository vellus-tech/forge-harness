# Diagnóstico — fila `pagamentos` em laço / worker a 100% CPU

Revisão de `src/consumidor.js`, `src/pagamentos.js` e `infra/rabbitmq/policy.json` (cluster RabbitMQ 4.1, três nós). Nenhum arquivo do repositório foi alterado — apenas leitura, conforme pedido.

## Causa raiz

`ch.consume('pagamentos', handler, { noAck: true })` está configurado com `noAck: true` **e ao mesmo tempo** o handler chama `ch.ack(msg)` / `ch.nack(msg)` manualmente. Isso é contraditório: com `noAck: true` o broker já considera a mensagem confirmada (removida da fila) no instante da entrega — o cliente não deveria (e não precisa) chamar `ack`/`nack`. O `amqplib` reporta essa combinação como erro do canal (o RabbitMQ devolve `PRECONDITION_FAILED - unknown delivery tag` para o `ack`/`nack` de uma tag que o servidor já deu como resolvida), fechando o canal. Como não há listener de `error`/`close` nem lógica de reconexão em `consumidor.js`, o processo se comporta de forma instável (canal morto silenciosamente, ou processo caindo e sendo reiniciado pelo orquestrador).

O sintoma relatado — "a mesma mensagem voltava sem parar" com CPU a 100% — é explicado pela combinação de três problemas que se somam:

1. **`noAck: true` inconsistente com ack/nack manual** (acima) — comportamento indefinido/errático do canal.
2. **Sem QoS/prefetch** (`ch.prefetch(n)` nunca é chamado): o broker entrega mensagens ao consumidor no ritmo máximo possível. Combinado com o ponto 3, isso vira um loop apertado sem backoff.
3. **`ch.nack(msg)` sem argumentos** equivale a `nack(msg, false, true)` — `requeue: true` por padrão. Se `processarPagamento` falha de forma **permanente** (ex.: `JSON.parse` de payload malformado, `evento.pedidoId` inexistente, violação de constraint no Postgres), a mensagem é recolocada no início da fila e reentregue imediatamente, falha de novo, é reenfileirada de novo — um laço infinito de redelivery sem qualquer backoff, limite de tentativas ou fila de mortos (DLQ). É exatamente esse ciclo apertado (requeue → redelivery instantâneo → falha → requeue) que consome 100% de CPU.
4. **Sem dead-letter exchange nem limite de tentativas** em `infra/rabbitmq/policy.json` — não há `dead-letter-exchange`, `x-delivery-limit` ou TTL que interrompam esse laço.

## Achado adicional — política de HA incompatível com RabbitMQ 4.1

`infra/rabbitmq/policy.json` usa `ha-mode: all` / `ha-sync-mode: automatic` (mirror de fila clássica). **O RabbitMQ removeu o suporte a mirroring de filas clássicas (`ha-mode`) a partir da série 4.0** — em um cluster 4.1 de três nós essa policy não produz mais réplicas; a fila `pagamentos` roda como fila clássica não replicada, sem tolerância a falha de nó. Para HA real em 4.1, a fila precisa ser migrada para **quorum queue** (`x-queue-type: quorum`), que é o mecanismo suportado nesta versão.

## Achados secundários

- `pagamentos.js` abre uma **segunda conexão AMQP** própria (`canalDePublicacao`) só para publicar o evento `pedido.pago`, em vez de reaproveitar a conexão/canal já aberto em `consumidor.js`. Funciona, mas duplica conexões e não trata erro/fechamento dessa conexão.
- Nenhum handler de `error`/`close` em `conn`/`ch` nos dois arquivos — falhas de canal (inclusive a do item 1) passam despercebidas.
- Sem idempotência: como o modelo é *at-least-once*, ao reintroduzir retries corretamente (item abaixo) uma mesma mensagem pode ser reprocessada; o `UPDATE pedidos SET status = 'PAGO'` é idempotente por natureza (bom), mas o `publish` de `pedido.pago` não é — duplicidade de evento é possível em reentrega.

## Correção proposta

- `noAck: false` (usar ack/nack manual de verdade — é o padrão, mas deixo explícito).
- `ch.prefetch(1)` (ou valor calibrado) para limitar mensagens em voo.
- Distinguir erro transitório (nack + requeue) de erro permanente (nack sem requeue, mandando para DLQ) — evita o laço infinito de reentrega imediata.
- Adicionar `dead-letter-exchange` na fila/policy e migrar para quorum queue com `delivery-limit`, substituindo `ha-mode`/`ha-sync-mode` (obsoletos no 4.1).

Ver `outputs/consumidor.corrigido.js` e `outputs/policy.corrigida.json` para os trechos corrigidos.
