# ADR-0003 - Kafka como broker de eventos

**Status:** Aceito | **Data:** 2026-08-27

## Decisão

Eventos de domínio são publicados em Apache Kafka, com um tópico por tipo de evento, publicação via Outbox Pattern e retenção mínima de 7 dias nos tópicos.

## Alternativas descartadas

RabbitMQ (sem replay nativo, necessário para reprocessar a agregação diária).
