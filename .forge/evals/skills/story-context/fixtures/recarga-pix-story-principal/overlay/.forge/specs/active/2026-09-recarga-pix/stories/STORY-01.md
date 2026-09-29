---
story_id: STORY-01
epic: 2026-09-recarga-pix
title: Emissão da cobrança Pix de recarga
depends_on: []
status: done
---

# STORY-01 — Emissão da cobrança Pix de recarga

## Goal

Gerar a cobrança Pix dinâmica (QR code com txid único) para uma recarga de cartão.

## Tasks

- [X] TASK-01 — Migration da tabela recharge_ledger (paths: `db/migrations/0012_recharge_ledger.sql`)
- [X] TASK-02 — Cliente do PSP para cobrança Pix dinâmica (paths: `src/recarga/pix-client.ts`)
- [X] TASK-03 — Endpoint POST /recargas gerando QR code (paths: `src/recarga/routes.ts`; depende: TASK-01, TASK-02)
