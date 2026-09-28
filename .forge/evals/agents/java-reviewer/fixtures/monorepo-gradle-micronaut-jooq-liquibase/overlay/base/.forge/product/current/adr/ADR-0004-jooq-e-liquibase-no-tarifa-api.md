# ADR-0004 — jOOQ e Liquibase no tarifa-api, sem ORM

Status: accepted. Data: 2026-03-10.

## Contexto

O cálculo de tarifa roda em lote sobre milhões de embarques por dia e precisa de SQL explícito, previsível e revisável. O time avaliou Spring Boot + JPA/Hibernate + Flyway e Micronaut + jOOQ + Liquibase.

## Decisão

O serviço services/tarifa-api usa Micronaut 4, build Gradle (Kotlin DSL), jOOQ para acesso a dados e Liquibase para migrations. Não usamos ORM (JPA/Hibernate) neste serviço. Consultas usam a DSL tipada do jOOQ com bind de parâmetros.

## Consequências

Revisões não devem propor migração para Spring, JPA, Hibernate, Flyway ou Maven sem uma nova ADR que substitua esta.
