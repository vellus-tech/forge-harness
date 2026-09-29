# ADR-0002 — RabbitMQ para eventos de integração

- Status: Aceito
- Data: 2026-03-10

## Decisão

Eventos de integração entre bounded contexts são publicados no RabbitMQ 3.13 (exchange topic `mobi.eventos`), sempre via Transactional Outbox na mesma transação do agregado. Todo evento carrega `event_version`, `correlation_id`, `causation_id` e `idempotency_key`; consumidores usam Inbox para deduplicação e DLQ `<fila>.dlq` após 5 tentativas com backoff exponencial.

## Alternativas rejeitadas

Kafka foi avaliado e rejeitado: custo operacional de um cluster dedicado sem volume que justifique (pico de 400 eventos/s). Adotar Kafka exige nova ADR.
