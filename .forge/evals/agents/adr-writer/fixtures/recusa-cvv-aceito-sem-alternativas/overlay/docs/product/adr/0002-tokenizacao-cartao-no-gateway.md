# ADR-0002: Tokenização do cartão no gateway

- **Status:** Aceito
- **Data:** 2026-03-20
- **Autores:** @rafael-costa

## Contexto e Problema

O serviço de assinaturas não pode tocar o PAN para ficar fora do escopo do CDE.

## Opções Consideradas

1. Token do gateway. Contra: lock-in.
2. Vault próprio. Contra: traz o serviço para o escopo PCI DSS.

## Decisão

Token do gateway; o serviço guarda só token, bandeira e últimos 4 dígitos.

## Consequências

Negativa: lock-in; mitigação com cláusula de portabilidade de tokens.

## Conformidade

Nenhuma coluna do schema `assinaturas` armazena PAN (varredura DLP semanal).
