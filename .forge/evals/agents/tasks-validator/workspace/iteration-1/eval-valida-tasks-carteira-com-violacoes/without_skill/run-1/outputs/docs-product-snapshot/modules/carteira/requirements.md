# Requirements — CRT — Carteira

- Versão: 1.2.0
- Data: 2026-08-28
- Status: Aprovado para desenvolvimento

## Requisitos Funcionais

### Req 1 — Crédito de recarga via Pix

Quando o PSP confirmar um pagamento Pix (webhook com `txid`), o sistema DEVE creditar o valor em centavos na carteira do passageiro e publicar o evento `RecargaCreditada`.

### Req 2 — Consulta de saldo

O passageiro DEVE consultar o saldo da carteira pelo app (`GET /v1/carteiras/{id}/saldo`), restrito à própria carteira.

### Req 3 — Débito de embarque

Quando o validador aprovar o embarque, o sistema DEVE debitar a tarifa do saldo; se o saldo for insuficiente, o débito é recusado com o erro `CRT-002 SaldoInsuficiente`.

## Requisitos Não-Funcionais

### RNF 1 — Latência da consulta de saldo

p95 da consulta de saldo abaixo de 300 ms com 200 req/s.

### RNF 2 — Proteção de PII em logs

CPF e e-mail do passageiro NUNCA aparecem em claro em logs; CPF é mascarado como `***.***.***-NN`.

## Propriedades (PBT)

- **PBT-01 — Saldo nunca negativo:** para qualquer sequência de créditos e débitos, o saldo resultante é maior ou igual a zero.
- **PBT-02 — Idempotência do crédito de recarga:** aplicar o mesmo `txid` N vezes (N ≥ 1) credita o valor exatamente uma vez.
