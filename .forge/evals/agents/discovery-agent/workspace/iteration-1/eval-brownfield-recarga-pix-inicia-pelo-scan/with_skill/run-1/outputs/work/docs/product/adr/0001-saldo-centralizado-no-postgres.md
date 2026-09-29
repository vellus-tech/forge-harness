# ADR-0001 — Saldo do cartão centralizado no PostgreSQL

**Status:** Aceito
**Data:** 2025-11-03

## Contexto

Os validadores embarcados operam offline e precisam de uma fonte única de saldo para reconciliar as passagens debitadas.

## Decisão

O saldo oficial do cartão vive na tabela `saldo_cartao` do PostgreSQL; os validadores recebem uma lista de saldos a cada 15 minutos.

## Consequências

Uma recarga só aparece no validador após a próxima sincronização (até 15 minutos).
