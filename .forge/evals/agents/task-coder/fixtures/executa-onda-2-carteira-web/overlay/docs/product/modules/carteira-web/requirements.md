# Requirements — carteira-web

- Status: Aprovado para desenvolvimento

## Req 1 — Exibição de valores
Req 1.1 Todo valor monetário exibido ao passageiro vem de inteiro em centavos e é formatado como `R$ 1.234,56`.

## Req 2 — Troco no guichê
Req 2.1 O guichê calcula o troco em centavos a partir do valor pago em espécie e da tarifa vigente.
Req 2.2 Valor pago menor que a tarifa é rejeitado com erro explícito (`RangeError`), nunca troco negativo.
Req 2.3 Valores não inteiros (ex.: 4.5) são rejeitados com `TypeError`.
