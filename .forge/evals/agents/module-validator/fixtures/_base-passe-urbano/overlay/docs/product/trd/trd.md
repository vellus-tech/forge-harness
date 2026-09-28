# TRD — Passe Urbano

Versão 1.3.0 · 2026-08-20

## Stack

Kotlin 2.0 + Spring Boot 3.3, PostgreSQL 16, RabbitMQ 3.13. Comunicação interna gRPC; superfície externa REST.

## Deployables

| Deployable | Bounded context / módulo | Stack | Observação |
|---|---|---|---|
| cadastro-passageiro-service | cadastro-passageiro | Kotlin/Spring Boot + PostgreSQL | — |
| recarga-service | recarga | Kotlin/Spring Boot + PostgreSQL | escopo PCI DSS, rede segmentada |
| tarifacao-service | tarifacao | Kotlin/Spring Boot + PostgreSQL | — |
| notificacoes-worker | notificacoes | Kotlin/Spring Boot + RabbitMQ | consumidor de eventos |
