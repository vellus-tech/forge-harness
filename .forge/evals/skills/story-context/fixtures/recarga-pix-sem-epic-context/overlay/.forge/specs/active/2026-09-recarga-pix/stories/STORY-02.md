---
story_id: STORY-02
epic: 2026-09-recarga-pix
title: Confirmação do Pix por webhook e crédito no cartão
depends_on: [STORY-01]
status: in-progress
---

# STORY-02 — Confirmação do Pix por webhook e crédito no cartão

> Story auto-contida derivada de `2026-09-recarga-pix`.

## Goal

Receber o webhook de liquidação do PSP, validar a assinatura e creditar o saldo do cartão uma única vez por txid.

## Embedded context

### Requirements

- REQ-02: o saldo só é creditado depois que o PSP confirma a liquidação pelo webhook.

### Design

> §3: reentrega do mesmo txid responde 200 sem novo crédito.

## Tasks

- [X] TASK-04 — Validação HMAC do header x-psp-signature (paths: `src/recarga/webhook-signature.ts`)
- [ ] TASK-05 — Handler POST /webhooks/psp/pix idempotente por txid (paths: `src/recarga/webhook.ts`; depende: TASK-04)
- [ ] TASK-06 — Crédito no serviço saldo via gRPC após confirmação (paths: `src/recarga/credit.ts`; depende: TASK-05)

## Acceptance criteria

- [ ] Webhook com assinatura inválida responde 401 e não credita.
- [ ] Segundo webhook com o mesmo txid responde 200 e não credita de novo.

## Out of scope

- Conciliação diária (STORY-03) e estorno (STORY-04).
