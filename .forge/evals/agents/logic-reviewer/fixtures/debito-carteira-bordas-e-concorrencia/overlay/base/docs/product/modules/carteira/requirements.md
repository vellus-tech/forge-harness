# Requirements — módulo carteira

## REQ-7 — Débito de tarifa no embarque

Cada embarque validado debita a tarifa (sempre um valor positivo, em centavos) da carteira pré-paga do passageiro. O saldo da carteira nunca pode ficar negativo; sem saldo suficiente, o débito é recusado com SaldoInsuficienteException.

## REQ-8 — Débitos simultâneos

Dois validadores podem debitar a mesma carteira ao mesmo tempo (passageiro que passa o cartão na catraca e no ônibus alimentador em sequência rápida, com sincronização atrasada). Nenhum débito pode ser perdido e o saldo não pode ficar negativo por causa da concorrência.

## REQ-9 — Carteira inexistente

Débito para carteira inexistente é recusado com CarteiraNaoEncontradaException, sem efeito colateral.
