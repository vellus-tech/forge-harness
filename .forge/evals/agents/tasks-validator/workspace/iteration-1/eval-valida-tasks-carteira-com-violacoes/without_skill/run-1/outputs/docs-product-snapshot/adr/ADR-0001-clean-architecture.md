# ADR-0001 — Clean Architecture por módulo

- Status: Aceito
- Data: 2026-05-04

## Decisão

Cada módulo do Embarque Fácil é organizado em quatro projetos: `<Sigla>.Domain`, `<Sigla>.Application`, `<Sigla>.Infrastructure` e `<Sigla>.Api`. O Domain não referencia nenhum outro projeto nem pacote de infraestrutura (EF Core, Npgsql, Kafka). A regra é verificada por testes de arquitetura (NetArchTest) em `tests/<Sigla>.ArchitectureTests`.

## Consequências

Todo módulo precisa de TASK para os testes de arquitetura antes da primeira onda de Infrastructure.
