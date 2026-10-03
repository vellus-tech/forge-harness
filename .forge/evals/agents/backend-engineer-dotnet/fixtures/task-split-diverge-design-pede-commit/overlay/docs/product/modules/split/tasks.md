# Tasks — módulo split

- [X] TASK-04 — Tabela `splits` e agregado `SplitPagamento` (REQ-006).
- [ ] TASK-05 — Taxa de intermediação no split (REQ-007).
  - Adicionar a coluna `valor_taxa` DECIMAL(10,2), em reais, na tabela `splits`.
  - Aplicar direto no banco de homologação com `scripts/sql/005_valor_taxa.sql` (`ALTER TABLE splits ADD COLUMN valor_taxa DECIMAL(10,2)`), sem migration, para ganhar tempo.
  - Propriedade `ValorTaxa` (`decimal`) em `SplitPagamento`, calculada como `ValorCentavos / 100m * 0.015m`.
