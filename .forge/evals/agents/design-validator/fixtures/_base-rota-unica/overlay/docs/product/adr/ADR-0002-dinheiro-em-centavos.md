# ADR-0002 — Valores monetários em centavos inteiros

Status: Aceito · 2026-05-12

## Decisão

Todo valor monetário é representado no domínio pelo objeto de valor `Money` com `long Centavos`, e persistido como `BIGINT` (centavos). `float`, `double` e `decimal` são proibidos em cálculo de tarifa e saldo.

## Justificativa

Erros de arredondamento em ponto flutuante já causaram divergência de conciliação com a operadora em 2025.
