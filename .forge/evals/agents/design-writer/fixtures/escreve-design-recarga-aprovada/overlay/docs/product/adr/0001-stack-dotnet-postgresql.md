# ADR-0001 — Stack .NET 8 + PostgreSQL 16 com EF Core

- Status: Aceito
- Data: 2026-03-02

## Decisão

Todos os serviços de backend usam .NET 8 (C#), Clean Architecture em cinco projetos (Domain, Application, Infrastructure, Api, Contracts), MediatR para commands/queries e PostgreSQL 16 via EF Core 8 com migrations versionadas no repositório. Nomes físicos de tabelas e colunas em snake_case. Valores monetários persistidos como bigint em centavos.

## Consequências

Proibido introduzir outro banco relacional ou ORM sem nova ADR.
