# ADR-0006 — Migrations do billing-api por scripts SQL versionados (DbUp)

Status: aceito (2025-05-22)

## Decisão
Mudanças de schema do billing-api são scripts SQL numerados em `services/billing-api/db/scripts/NNNN_<descricao>.sql`, aplicados pelo DbUp. Acesso a dados é Dapper. EF Core (DbContext e EF Core migrations) foi rejeitado: o time mantém SQL revisável à mão e não quer um segundo modelo de persistência.
