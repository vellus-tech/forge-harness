# Design — migra-eventos-para-kafka

## Decisões

1. Todos os eventos de domínio, inclusive os de recarga, migram do RabbitMQ para o tópico Kafka `mobilidade.eventos` com particionamento por `cartao_id`.
2. O outbox passa a usar Debezium (CDC) em vez de polling.
3. ADR-0021 — Kafka como barramento único de eventos.
