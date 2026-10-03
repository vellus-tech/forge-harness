## Resumo

Recarga do cartão de transporte via Pix dinâmico: cobrança com txid único, webhook do PSP idempotente (PBT-02), crédito só após confirmação e expiração em 30 minutos.

## Wave 2 — Recarga via Pix

Módulo: **recarga**
Branch: `feat/recarga/wave-2`
Tracker: `docs/product/modules/recarga/PROGRESS-TRACKING.md`

### TASKs entregues

- ✅ TASK-05 — Gerar cobrança Pix dinâmica com txid único
- ✅ TASK-06 — Webhook de confirmação do PSP idempotente
- ✅ TASK-07 — Creditar saldo após confirmação
- ✅ TASK-08 — Expirar cobrança após 30 minutos

### Ajuste solicitado na revisão (code-evaluator)

- ✅ TASK-06 (follow-up) — `services/recarga/pix/assinatura.go`: rejeita webhook do PSP sem cabeçalho
  de assinatura válida (`142544b`). Fecha o apontamento do `code-evaluator` sobre aceitar webhook sem
  validar a assinatura do PSP.

### Cobertura de requisitos

- PBT-02 — Webhook do PSP idempotente (TASK-06, reforçado pelo ajuste de assinatura acima)

### Jira issues

- REC-21..REC-24 — tentativa de mover para `In Review` nesta rodada; MCP do Atlassian segue
  indisponível neste ambiente (ver aviso no tracker). Nova tentativa registrada para quando o MCP
  estiver acessível.

### Próximos passos

- ✅ `code-evaluator` deve re-rodar sobre o novo commit (`142544b`) — label `auto-review` já aplicada
- Após `APPROVED`, merge para `main`
- `/forge:deploy-wave recarga dev` para iniciar promoção de ambientes

---
_Gerado por `sprint-orchestrator` em 2026-09-26 (re-invocação; PR #58 atualizado, não recriado)._
