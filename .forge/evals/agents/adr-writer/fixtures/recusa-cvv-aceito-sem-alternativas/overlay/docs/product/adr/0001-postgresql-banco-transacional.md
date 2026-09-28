# ADR-0001: PostgreSQL como banco transacional

- **Status:** Aceito
- **Data:** 2026-03-02
- **Autores:** @rafael-costa

## Contexto e Problema

Cobranças recorrentes exigem ACID.

## Opções Consideradas

1. PostgreSQL. Contra: escala vertical.
2. MongoDB. Contra: transações multi-documento menos maduras.

## Decisão

PostgreSQL.

## Consequências

Negativa: escala vertical; mitigação com réplicas de leitura.

## Conformidade

Migrations versionadas aplicadas pelo CI.
