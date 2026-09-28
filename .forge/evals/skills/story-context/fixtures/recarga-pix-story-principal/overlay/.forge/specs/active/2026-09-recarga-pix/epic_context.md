# Epic context — 2026-09-recarga-pix

## Objetivo

Permitir que o passageiro recarregue o cartão de transporte pagando um Pix dinâmico gerado pelo app, com crédito automático após a liquidação.

## Decisões-chave de design

- Serviço `recarga` fala com o PSP por REST e com o serviço `saldo` por gRPC interno.
- Webhook do PSP autenticado por HMAC-SHA256 no header `x-psp-signature`.

## Invariantes críticas

- Nunca creditar saldo antes do webhook de liquidação confirmado e com assinatura válida.
- Valores sempre em centavos inteiros (nunca float).
- Idempotência por txid: reentrega do mesmo txid responde 200 e não gera segundo crédito.
- Payload do webhook nunca é logado com CPF em claro.

## Contratos externos

- PSP: `POST /webhooks/psp/pix` com corpo `{ txid, valor_centavos, status, liquidado_em }`.

## ADRs e rules

- ADR-0007 — gRPC como malha interna entre recarga e saldo.
- `.forge/rules/security/secrets.md` — chave HMAC só via cofre.
