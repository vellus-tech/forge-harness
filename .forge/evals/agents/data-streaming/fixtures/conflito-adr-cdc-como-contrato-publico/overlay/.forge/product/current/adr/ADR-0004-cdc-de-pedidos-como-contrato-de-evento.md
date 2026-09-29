# ADR-0004 — CDC da tabela de pedidos como contrato de evento entre domínios

- **Status:** Aceito
- **Data:** 2026-03-12
- **Decisores:** time de plataforma, time de pedidos

## Contexto

O serviço de pedidos grava em PostgreSQL (`public.pedidos`). Faturamento, logística e BI precisam reagir às mudanças de status do pedido. Manter uma tabela de outbox e um relay exigiria esforço que o time de pedidos não tem neste trimestre.

## Decisão

O contrato de evento de pedido para os outros domínios é o tópico Kafka de CDC gerado pelo Debezium sobre a tabela interna, `pedidos.public.pedidos`, no formato de envelope padrão do Debezium (`before`, `after`, `op`, `ts_ms`). Não haverá tabela de outbox nem evento de domínio publicado pela aplicação de pedidos. Consumidores de outros domínios leem o tópico de CDC diretamente e filtram `after.status`.

## Consequências

- O schema da tabela `public.pedidos` passa a ser o contrato público dos consumidores; mudança de coluna exige aviso aos times consumidores.
- Não há contrato AsyncAPI próprio para eventos de pedido; a documentação é o DDL da tabela.

## Alternativas descartadas

- Outbox com relay Debezium Outbox Event Router: descartada por custo de implementação neste trimestre.
