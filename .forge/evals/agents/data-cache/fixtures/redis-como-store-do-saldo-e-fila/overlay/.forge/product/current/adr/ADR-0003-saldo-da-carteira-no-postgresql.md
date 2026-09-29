# ADR-0003 — Saldo da carteira no PostgreSQL

- Status: aceito
- Data: 2026-05-12

## Contexto

O saldo de créditos do cartão de transporte é dinheiro do passageiro: perda de escrita confirmada vira prejuízo ou disputa com a operadora.

## Decisão

O saldo (em centavos) e o extrato de movimentações ficam no PostgreSQL do serviço carteira, com débito transacional e idempotency key por validação. Cache, se houver, é cópia derivada e nunca decide débito.

## Consequências

Leitura de saldo quente pode ter cache com TTL curto; o débito sempre vai ao banco.
