## Context — STORY-04

**Goal:** Devolver via Pix o valor de uma recarga liquidada cujo crédito no cartão falhou.
**Status:** blocked
**Depends on:** [STORY-02]

**Tasks desta story:**
- TASK-09 — Limite diário de R$ 500 por CPF na emissão do QR code (paths: `src/recarga/limite-cpf.ts`)
- TASK-10 — Estorno Pix (devolução) para recarga não creditada (paths: `src/recarga/estorno.ts`; depende: TASK-06)

**Invariantes críticas do épico:**
- Nunca creditar saldo antes do webhook de liquidação confirmado e com assinatura válida.
- Idempotência por txid: reentrega do mesmo txid responde 200 e não gera segundo crédito.

**Próxima ação:** BLOQUEADA — não implementar. O frontmatter da story registra `status: blocked` com a nota "o PSP ainda não liberou as credenciais do endpoint de devolução Pix em homologação (ticket OPS-812)". Conforme o protocolo da skill story-context, uma story `blocked` deve ser informada e a execução deve parar aqui — nenhuma TASK foi iniciada.
