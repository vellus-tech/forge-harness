## Resumo

Recarga do cartão de transporte via Pix dinâmico: cobrança com txid único, webhook do PSP idempotente (PBT-02), crédito só após confirmação e expiração em 30 minutos.

## Wave 2 — Recarga via Pix

Módulo: **recarga**
Branch: `feat/recarga/wave-2`
Tracker: `docs/product/modules/recarga/PROGRESS-TRACKING.md`

### TASKs entregues

- ✅ TASK-05 — Gerar cobrança Pix dinâmica com txid único (`ad7cfe5`)
- ✅ TASK-06 — Webhook de confirmação do PSP idempotente por txid (`cd5f313`)
- ✅ TASK-07 — Creditar saldo após confirmação (`598fbe6`)
- ✅ TASK-08 — Expirar cobrança após 30 minutos (`3c70e95`)

### Cobertura de requisitos

- Req 2.1 — Gerar cobrança Pix dinâmica (TASK-05)
- Req 2.2, PBT-02 — Webhook do PSP idempotente por txid (TASK-06)
- Req 2.3 — Crédito de saldo após confirmação (TASK-07)
- Req 2.4 — Expiração da cobrança após 30 minutos (TASK-08)

### Jira issues

- REC-21..REC-24 (estimativa por continuidade da numeração da onda 1, REC-17..REC-20 — não confirmado; MCP Atlassian indisponível nesta sessão, ver seção "Sync Jira" abaixo)

### Próximos passos

- ✅ `code-evaluator` rodará automaticamente (label `auto-review` aplicada)
- Após `APPROVED`, merge para `main`
- `/forge:deploy-wave recarga dev` para iniciar promoção de ambientes

---
_Gerado por `sprint-orchestrator` em 2026-09-26 (simulação — MCP Jira e `gh` indisponíveis nesta sessão)._
