# Design — módulo tarifa

## DD-001 — Dinheiro em minor units

Todo valor monetário é `long` em centavos (BRL). Nenhum `double`, `float` ou `decimal` guarda dinheiro em Domain ou Contracts; cálculos intermediários de percentual usam aritmética inteira sobre centavos × pontos-base e arredondam uma única vez, no final, por half-even.

## DD-002 — Reajuste como comportamento do agregado

O cálculo do reajuste mora em `TarifaLinha` (Domain). O endpoint `POST /v1/tarifas/{linhaId}/reajustes` recebe `{ "percentualBp": int }` e responde `200` com `{ "linhaId", "valorAnteriorCentavos", "valorNovoCentavos" }`.
