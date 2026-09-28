# ADR-0003 — Mensageria com RabbitMQ, outbox transacional e envelope padrão

Status: Aceito · 2026-06-01

## Decisão

Eventos de integração são publicados via outbox transacional (tabela `outbox` no schema do módulo) e consumidos com inbox para idempotência. Todo evento carrega envelope com `event_version`, `correlation_id`, `causation_id`, `tenant_id` e `idempotency_key`. Filas críticas têm DLQ com retry exponencial limitado a 5 tentativas.
