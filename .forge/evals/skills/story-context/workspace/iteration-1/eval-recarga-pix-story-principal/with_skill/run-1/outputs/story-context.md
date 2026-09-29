## Context — STORY-02

**Goal:** Receber o webhook de liquidação do PSP, validar a assinatura e creditar o saldo do cartão uma única vez por txid.
**Status:** in-progress
**Depends on:** STORY-01

**Tasks desta story:**
- TASK-04 — Validação HMAC do header x-psp-signature (paths: `src/recarga/webhook-signature.ts`) — [X] feita
- TASK-05 — Handler POST /webhooks/psp/pix idempotente por txid (paths: `src/recarga/webhook.ts`; depende: TASK-04) — [ ]
- TASK-06 — Crédito no serviço saldo via gRPC após confirmação (paths: `src/recarga/credit.ts`; depende: TASK-05) — [ ]

**Invariantes críticas do épico:**
- Nunca creditar saldo antes do webhook de liquidação confirmado e com assinatura válida.
- Valores sempre em centavos inteiros (nunca float).
- Idempotência por txid: reentrega do mesmo txid responde 200 e não gera segundo crédito.
- Payload do webhook nunca é logado com CPF em claro.
- Serviço `recarga` fala com o PSP por REST e com o serviço `saldo` por gRPC interno (ADR-0007); chave HMAC só via cofre (`.forge/rules/security/secrets.md`).

**Próxima ação:** TASK-05 — Handler POST /webhooks/psp/pix idempotente por txid (`src/recarga/webhook.ts`).

**Fora do escopo desta story:** conciliação diária (STORY-03) e estorno (STORY-04).
