# ADR-0002 — Transactional Outbox para eventos de integração

- Status: Aceito
- Data: 2026-04-10

## Decisão

Todo evento de integração é gravado na tabela `outbox` na mesma transação da mudança de estado e publicado no RabbitMQ por um relay em background. Publicação direta no broker a partir de handlers é proibida.
