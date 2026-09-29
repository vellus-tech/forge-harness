# ADR-0101: Roteamento multiadquirente por BIN

- **Status:** Aceito
- **Data:** 2026-05-18
- **Autores:** @rafael-costa

## Contexto e Problema

Taxas de aprovação variam por adquirente e bandeira.

## Opções Consideradas

1. Roteamento por BIN com fallback. Contra: tabela de BIN a manter.
2. Adquirente único. Contra: ponto único de falha.

## Decisão

Roteamento por BIN com fallback.

## Consequências

Negativa: manter tabela de BIN; mitigação com atualização mensal automatizada.

## Conformidade

Teste de integração cobre fallback quando o adquirente primário responde 5xx.
