# ADR-0004 — Multi-tenancy por operadora com tenant_id

- Status: Aceito
- Data: 2026-04-15

## Decisão

Cada operadora de transporte é um tenant. Toda tabela com dado de negócio tem coluna `tenant_id uuid not null` e índice composto iniciando por `tenant_id`; o EF Core aplica filtro global por tenant resolvido do claim `tenant` do JWT. Cache e routing keys de eventos são prefixados pelo tenant.
