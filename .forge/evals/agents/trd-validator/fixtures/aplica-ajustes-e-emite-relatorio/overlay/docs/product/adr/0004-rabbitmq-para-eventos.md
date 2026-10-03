# ADR-0004 - RabbitMQ como broker de eventos de domínio

**Status:** Aceito · **Data:** 2026-07-01

## Decisão

Eventos de domínio entre contextos trafegam no RabbitMQ (exchange `dominio.eventos`, tipo topic), com fila de DLQ por consumidor e retenção de 7 dias na DLQ. Consumidores são idempotentes por `event_id`.
