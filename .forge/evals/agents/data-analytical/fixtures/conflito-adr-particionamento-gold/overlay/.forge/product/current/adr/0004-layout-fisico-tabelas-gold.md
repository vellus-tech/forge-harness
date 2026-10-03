# ADR-0004 — Layout físico das tabelas gold no lakehouse

- Status: Aceito
- Data: 2026-03-10
- Decisores: time de dados

## Contexto

As tabelas gold do lakehouse (Delta no Databricks) alimentam os dashboards de bilhetagem, que filtram quase sempre por dia. O time quer um layout único e previsível para todas as tabelas gold.

## Decisão

Toda tabela gold em Delta é particionada por `dt` (DATE, dia do evento) com `PARTITIONED BY (dt)`. Liquid clustering e `ZORDER BY` não são usados nas tabelas gold até nova decisão registrada em ADR.

## Consequências

Layout uniforme e consultas por dia com poda de partição. Tabelas pequenas podem gerar muitos arquivos pequenos; a compactação fica a cargo do job noturno de `OPTIMIZE`.
