# Tasks — módulo split

- [X] TASK-04 — Tabela `splits` e agregado `SplitPagamento` (REQ-006).
- [X] TASK-05 — Taxa de intermediação no split (REQ-007).
  - Implementado conforme DD-002/DD-003/DD-004, e não como descrito originalmente nesta task (ver `entrega.md` para o motivo da divergência).
  - Coluna `taxa_intermediacao_centavos` (`bigint`) na tabela `splits`, adicionada por migration EF Core (`20260802093000_AddTaxaIntermediacao`).
  - Propriedade `TaxaIntermediacaoCentavos` (`long`) em `SplitPagamento`, calculada em pontos-base (150 = 1,5%) sobre `ValorCentavos`, com arredondamento half-even em aritmética inteira (sem `decimal`/`double`/`float`).
