# ADR-0001 — Stack .NET 8 + PostgreSQL com Clean Architecture

- Status: Aceito
- Data: 2026-03-02

## Decisão

Serviços de domínio em .NET 8 com Clean Architecture (Domain, Application, Infrastructure, Api, Contracts), PostgreSQL 16 com migrations Flyway versionadas (`V<n>__<slug>.sql`), testes com xUnit, FsCheck para property-based testing e NetArchTest para regras de dependência entre camadas.
