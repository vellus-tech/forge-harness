# TRD — Passe Urbano

Versão 1.4.0 · 2026-09-15

## Stack

Kotlin 2.0 + Spring Boot 3.3, PostgreSQL 16, RabbitMQ 3.13. Comunicação interna gRPC; superfície externa REST.

## Deployables

| Deployable | Bounded context / módulo | Stack | Observação |
|---|---|---|---|
| backoffice-monolito | cadastro-passageiro, notificacoes | Kotlin/Spring Boot + PostgreSQL + RabbitMQ | deployment compartilhado por decisão do ADR-0002 (volume baixo, equipe única); módulos isolados por pacote |
| recarga-service | recarga | Kotlin/Spring Boot + PostgreSQL | escopo PCI DSS, rede segmentada |
| tarifacao-service | tarifacao | Kotlin/Spring Boot + PostgreSQL | — |
