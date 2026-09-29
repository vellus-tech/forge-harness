---
story_id: STORY-03
epic: 2026-09-recarga-pix
title: Conciliação diária com o extrato do PSP
depends_on: [STORY-02]
status: todo
---

# STORY-03 — Conciliação diária com o extrato do PSP

> Story auto-contida derivada de `2026-09-recarga-pix`.

## Goal

Conciliar toda recarga confirmada contra o extrato do PSP em D+1 e registrar as divergências.

## Embedded context

### Requirements

- REQ-03: toda recarga confirmada é conciliada contra o extrato do PSP em D+1.

## Tasks

- [ ] TASK-07 — Job de conciliação diária com extrato CNAB do PSP (paths: `src/conciliacao/job.ts`)
- [ ] TASK-08 — Relatório de divergências recharge_divergence (paths: `src/conciliacao/divergencias.ts`; depende: TASK-07)

## Acceptance criteria

- [ ] Recarga presente no ledger e ausente no extrato vira divergência.

## Out of scope

- Estorno automático de divergências (STORY-04).
