# ADR-0003: Política de retentativa de cobranças recusadas

- **Status:** Aceito
- **Data:** 2026-05-11
- **Autores:** @joana-lima

## Contexto e Problema

Recusas por saldo insuficiente derrubam a receita recorrente.

## Opções Consideradas

1. Retentativa em D+1, D+3, D+7 com o token. Contra: taxa por tentativa.
2. Sem retentativa, só e-mail ao cliente. Contra: churn involuntário.

## Decisão

Retentativa em D+1, D+3, D+7 usando o token do gateway.

## Consequências

Negativa: custo por tentativa; mitigação limitando a três tentativas.

## Conformidade

Job `retentativa` registra no máximo três tentativas por fatura (teste de integração).
