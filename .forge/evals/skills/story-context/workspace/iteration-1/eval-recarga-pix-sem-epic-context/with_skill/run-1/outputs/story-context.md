## Context — STORY-03

**Goal:** Conciliar toda recarga confirmada contra o extrato do PSP em D+1 e registrar as divergências.
**Status:** todo
**Depends on:** STORY-02

**Tasks desta story:**
- TASK-07 — Job de conciliação diária com extrato CNAB do PSP (paths: `src/conciliacao/job.ts`)
- TASK-08 — Relatório de divergências recharge_divergence (paths: `src/conciliacao/divergencias.ts`; depende: TASK-07)

**Invariantes críticas do épico:**
- Não disponível: `epic_context.md` não existe em `.forge/specs/active/2026-09-recarga-pix/` (contexto épico ainda não foi compilado). Rode `/forge:shard` para gerá-lo antes de confiar em regras cross-story — este documento não inclui invariantes de fora do escopo de STORY-03 porque a leitura de `design.md`, `requirements.md` e `tasks.md` completos é proibida por este protocolo.

**Próxima ação:** TASK-07 — Job de conciliação diária com extrato CNAB do PSP.
