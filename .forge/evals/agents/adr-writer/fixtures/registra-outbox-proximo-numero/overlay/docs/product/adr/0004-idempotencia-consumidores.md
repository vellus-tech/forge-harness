# ADR-0004: Idempotência obrigatória nos consumidores de eventos

- **Status:** Aceito
- **Data:** 2026-03-20
- **Autores:** @rafael-costa

## Contexto e Problema

Entrega at-least-once do RabbitMQ gera duplicatas no serviço de compensação.

## Opções Consideradas

1. Chave de idempotência por evento (`event_id`) com tabela de deduplicação. Contra: escrita extra.
2. Exactly-once via transação distribuída. Contra: complexidade e acoplamento.

## Decisão

Chave de idempotência por `event_id`.

## Consequências

Negativa: tabela de deduplicação cresce; mitigação com TTL de 30 dias.

## Conformidade

Teste de contrato reenviando o mesmo evento duas vezes e esperando um único efeito.
