# ADR-0002: PostgreSQL como banco transacional

- **Status:** Aceito
- **Data:** 2026-02-12
- **Autores:** @joana-lima

## Contexto e Problema

Transações de bilhetagem exigem ACID e consultas relacionais por cartão e linha.

## Opções Consideradas

1. PostgreSQL — ACID, maduro. Contra: escala vertical.
2. DynamoDB — escala horizontal. Contra: modelagem por padrão de acesso e sem transação multi-item barata.

## Decisão

PostgreSQL 16 gerenciado.

## Consequências

Negativa: limite de escala vertical; mitigação com particionamento por mês.

## Conformidade

Migrations versionadas em `db/migrations/` aplicadas pelo CI.
