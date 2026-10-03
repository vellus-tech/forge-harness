# ADR-0001 — Clean Architecture em .NET 8 para todos os módulos

Status: Aceito · 2026-05-10

## Decisão

Cada módulo é organizado em `<Modulo>.Domain`, `<Modulo>.Application`, `<Modulo>.Infrastructure`, `<Modulo>.Api`, `<Modulo>.Contracts` e `<Modulo>.Architecture.Tests` (NetArchTest). O projeto Domain não referencia nenhum pacote de infraestrutura (EF Core, Npgsql, MassTransit, AWS SDK, StackExchange.Redis).

## Consequências

Violação da regra de dependência quebra o build via `Architecture.Tests`.
