# RCG — Recarga de Cartão de Transporte

| Artefato | Versão | Status | Data |
|----------|--------|--------|------|
| requirements.md | 1.3.0 | Aprovado | 2026-09-25 |
| design.md | 1.1.0 | Aprovado para desenvolvimento | 2026-09-26 |
| tasks.md | 1.0.0 | Aprovado (desatualizado — não cobre RF-06/DD-002; recomenda-se nova rodada de `/forge:tasks`) | 2026-09-22 |

Principais decisões do design.md 1.1.0: RF-06 (estorno) modelado como agregado `Estorno` referenciando `Recarga`; evento `RecargaEstornadaIntegrationEvent` publicado via RabbitMQ/Outbox (ADR-0002), não via Kafka — ver DD-002 para a análise do pedido de publicação direta no Kafka e o encaminhamento recomendado ao time de dados/arquitetura.
