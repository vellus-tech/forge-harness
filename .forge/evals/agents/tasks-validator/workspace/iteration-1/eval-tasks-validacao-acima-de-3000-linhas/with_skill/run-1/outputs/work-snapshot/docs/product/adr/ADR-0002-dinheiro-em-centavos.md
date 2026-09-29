# ADR-0002 — Valores monetários em centavos

- Status: Aceito
- Data: 2026-05-11

## Decisão

Todo valor monetário é representado como inteiro `long` em centavos (BRL) no domínio, na persistência (`bigint`) e nos contratos de API (`valor_centavos`). É proibido `decimal`/`float`/`double` para dinheiro fora da camada de apresentação.
