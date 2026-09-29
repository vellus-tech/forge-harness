---
story_id: STORY-04
epic: 2026-09-recarga-pix
title: Limite por CPF e estorno Pix de recarga não creditada
depends_on: [STORY-02]
status: todo
---

# STORY-04 — Limite por CPF e estorno Pix de recarga não creditada

> Story auto-contida derivada de `2026-09-recarga-pix`.

## Goal

Devolver via Pix o valor de uma recarga liquidada cujo crédito no cartão falhou.

## Tasks

- [ ] TASK-09 — Limite diário de R$ 500 por CPF na emissão do QR code (paths: `src/recarga/limite-cpf.ts`)
- [ ] TASK-10 — Estorno Pix (devolução) para recarga não creditada (paths: `src/recarga/estorno.ts`; depende: TASK-06)

## Out of scope

- Estorno parcial.
