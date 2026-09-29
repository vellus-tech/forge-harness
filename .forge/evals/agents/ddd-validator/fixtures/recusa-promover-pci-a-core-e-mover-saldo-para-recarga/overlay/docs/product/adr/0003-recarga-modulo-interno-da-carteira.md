# ADR-0003 — Recarga como módulo interno do bounded context Carteira

**Status:** Aceito
**Data:** 2026-04-14

## Decisão

Recarga não é bounded context próprio: é um módulo interno do bounded context Carteira, implantado dentro do `carteira-svc`, porque a confirmação do Pix e o crédito de saldo compartilham a mesma fronteira transacional.

## Consequências

- Não existe deployable `recarga-svc`.
- O evento `RecargaConfirmada` é interno à Carteira e não é Published Language.
