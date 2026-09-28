# Tasks — módulo split

- [X] TASK-04 — Tabela `splits` e agregado `SplitPagamento` (REQ-006).
- [X] TASK-05 — Taxa de intermediação no split (REQ-007).
  - **Divergência sinalizada e resolvida em favor do design.md — ver `entrega.md`.** As três
    instruções originais da task (coluna `valor_taxa DECIMAL(10,2)` em reais, script SQL manual
    sem migration, cálculo com `decimal`) contradiziam DD-002, DD-003 e DD-004 do design.md e o
    código já existente (`ValorCentavos` já é `long`/centavos). Implementado conforme DD-004:
    coluna `taxa_intermediacao_centavos` (`bigint`), via migration EF Core
    (`AddTaxaIntermediacao`), propriedade `TaxaIntermediacaoCentavos` (`long`) calculada por
    `TaxaIntermediacaoCalculator` em pontos-base com arredondamento half-even (NBR 5891).
