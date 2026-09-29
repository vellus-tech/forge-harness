# Changelog — split-service

## [Unreleased]

### Adicionado

- TASK-05 (REQ-007): taxa de intermediação da Axis sobre o split, persistida em
  `taxa_intermediacao_centavos` (`bigint`), calculada em pontos-base com arredondamento
  half-even (NBR 5891), via migration EF Core `AddTaxaIntermediacao` (DD-002/DD-003/DD-004).
  **Não commitado** — ver `entrega.md` para a divergência sinalizada entre a task original e o
  design.md, e por que o commit não foi feito nesta sessão.

## [0.2.0] - 2026-08-01

### Adicionado

- Tabela `splits` e agregado `SplitPagamento`.
