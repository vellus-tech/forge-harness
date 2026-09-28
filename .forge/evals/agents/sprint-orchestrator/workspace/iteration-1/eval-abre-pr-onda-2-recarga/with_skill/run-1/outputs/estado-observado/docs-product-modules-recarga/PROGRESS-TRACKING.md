# PROGRESS-TRACKING — recarga

Última atualização: 2026-09-22 16:40 (sprint-orchestrator onda 1 mergeada)

| Wave | Status | TASKs | Concluídas | Falhas | PR |
|------|--------|-------|------------|--------|-----|
| 1    | ✅ Merged | 4 | 4 | 0 | #41 |
| 2    | ⏳ Pendente | 4 | 0 | 0 | - |
| 3    | ⏳ Pendente | 4 | 0 | 0 | - |

## Onda 1 — Cadastro e saldo
- [X] TASK-01 — Entidade CartaoTransporte e repositório      [backend-go]  a1b2c3d
- [X] TASK-02 — Endpoint POST /cartoes                       [backend-go]  b2c3d4e
- [X] TASK-03 — Endpoint GET /cartoes/{id}/saldo             [backend-go]  c3d4e5f
- [X] TASK-04 — Encerramento da onda 1                       [task-coder]  d4e5f6a

## Onda 2 — Recarga via Pix
- [ ] TASK-05 — Gerar cobrança Pix dinâmica com txid único   [backend-go]  -
- [ ] TASK-06 — Webhook de confirmação do PSP idempotente    [backend-go]  -
- [ ] TASK-07 — Creditar saldo após confirmação              [backend-go]  -
- [ ] TASK-08 — Expirar cobrança após 30 minutos             [backend-go]  -

## Onda 3 — Estorno
- [ ] TASK-09 — Modelo de solicitação de estorno             [backend-go]  -
- [ ] TASK-10 — Regra de elegibilidade de 7 dias             [backend-go]  -
- [ ] TASK-11 — Devolução Pix via PSP                        [backend-go]  -
- [ ] TASK-12 — Conciliação do estorno com o saldo           [backend-go]  -

## Wave 1 (TASK-01..TASK-04) — Cadastro e saldo ✅ MERGED

- PR: https://github.com/axis-mobfintech/bilhetagem-recarga/pull/41
- Jira: REC-17..REC-20 → `In Review`
