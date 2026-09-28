# Desenho do consumidor Kafka do faturamento — para o `task-coder` implementar

Pressupõe a decisão registrada em `outputs/01-CONFLITO-bloqueante.md` (consumir o tópico de CDC de pedidos diretamente, conforme ADR-0004 em vigor). Se a decisão humana for superar a ADR e migrar para evento de domínio, este consumidor muda de tópico/schema mas a estrutura de retry/DLT abaixo continua válida.

## Tópicos

- Entrada: `pedidos.public.pedidos` (CDC, fora do controle do faturamento).
- Retry: `faturamento.pedido-confirmado.retry` (tópico próprio do faturamento, 3 partições, mesma chave `pedidoId`).
- Dead-letter: `faturamento.pedido-confirmado.dlt` (retenção longa, ex. 30 dias, para investigação manual).

## Grupo de consumidores

`faturamento-emissao-fatura` lendo `pedidos.public.pedidos` (`fromBeginning: false` em produção; `true` só em ambiente de teste/replay controlado).

## Fluxo

1. Consome mensagem do tópico de CDC.
2. Filtra: descarta se `op` não for `u`/`r`, ou se a transição não for para `status === 'CONFIRMADO'` a partir de um `before.status` diferente (ver `outputs/02`). Mensagens filtradas são commit direto (não é erro, é no-op esperado).
3. Verifica idempotência: já existe fatura para `after.id`? Se sim, commit e log (`already_processed`), não reprocessa.
4. Chama `emitirFatura(pedidoId, valorCentavos)` (`services/faturamento/src/index.ts`, hoje um stub que lança `não implementado` — é o método que o `task-coder` precisa implementar de verdade).
5. Sucesso: commit do offset.
6. Falha: decide retry local vs. tópico de retry (ver política abaixo).

## Política de retry

- **Retry local (in-memory, sem re-publicar)**: até 3 tentativas com backoff exponencial (ex. 200ms, 800ms, 3200ms) para falhas transitórias já classificadas como tal (timeout de rede, conexão de banco recusada, 5xx de serviço downstream). Evita custo de round-trip pelo Kafka para o caso comum.
- **Retry via tópico dedicado**: se as 3 tentativas locais falharem, publica a mensagem original (envelope Debezium intacto + metadados de tentativa: `attempt`, `firstFailureAt`, `lastError`) em `faturamento.pedido-confirmado.retry` e faz commit do offset original (não trava a partição principal). Um segundo consumer group lê o tópico de retry com backoff maior entre lotes (ex. 30s) e até 5 tentativas adicionais.
- **Não é permitido bloquear a partição principal** re-tentando no laço síncrono do consumer além do retry local — isso pararia o processamento de todos os pedidos subsequentes (head-of-line blocking) enquanto um pedido problemático é reprocessado.

## Dead-letter topic (DLT)

Esgotadas as tentativas do tópico de retry (3 locais + 5 no retry = 8 tentativas), a mensagem vai para `faturamento.pedido-confirmado.dlt` com o payload original, o histórico de tentativas e o erro final serializado. Publicação na DLT dispara alerta (a `rule` de observabilidade do projeto já exige `correlationId` e logging estruturado de erro — aplicar aqui: `correlationId` = `pedidoId`, log com stack trace só em não-produção).

Reprocessamento da DLT é manual (ferramenta/console de operação lê a DLT e republica na entrada após correção da causa raiz) — não há retry automático a partir da DLT, para evitar loop.

## Idempotência e ordenação

Chave de partição = `pedidoId` (herdada do tópico de CDC, que particiona pela chave primária da tabela) preservada em todos os tópicos derivados (retry, DLT), garantindo que mensagens do mesmo pedido continuem ordenadas entre si.

## Configuração sugerida (kafkajs, já é dependência de `services/faturamento/package.json`)

```ts
consumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    // parse envelope Debezium, filtro de transição, idempotência, chamada a emitirFatura,
    // captura de erro classificado (transitório vs. permanente) e roteamento para retry/DLT
    // conforme política acima.
  },
});
```

Não escrevi a implementação em código porque a tarefa pede o desenho para o `task-coder` implementar, e a implementação real depende da decisão pendente registrada em `outputs/01-CONFLITO-bloqueante.md`.
