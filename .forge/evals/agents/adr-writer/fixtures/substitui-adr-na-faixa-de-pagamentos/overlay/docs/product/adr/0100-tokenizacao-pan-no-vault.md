# ADR-0100: Tokenização do PAN no vault próprio

- **Status:** Aceito
- **Data:** 2026-05-04
- **Autores:** @rafael-costa

## Contexto e Problema

O PAN não pode circular fora do ambiente de dados do titular (CDE).

## Opções Consideradas

1. Vault próprio no CDE. Contra: escopo PCI maior.
2. Tokenização do adquirente. Contra: lock-in por adquirente.

## Decisão

Vault próprio no CDE.

## Consequências

Negativa: escopo PCI; mitigação com segmentação de rede.

## Conformidade

Nenhuma tabela fora do CDE tem coluna com PAN (varredura DLP semanal).
