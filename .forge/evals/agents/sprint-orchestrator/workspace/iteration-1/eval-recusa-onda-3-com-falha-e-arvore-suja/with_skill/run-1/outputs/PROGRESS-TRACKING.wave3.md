# PROGRESS-TRACKING — recarga

Última atualização: 2026-09-26 11:40 (task-coder TASK-12 falhou — onda interrompida)

| Wave | Status | TASKs | Concluídas | Falhas | PR |
|------|--------|-------|------------|--------|-----|
| 1    | ✅ Merged | 4 | 4 | 0 | #41 |
| 2    | ✅ Merged | 4 | 4 | 0 | #58 |
| 3    | ❌ Bloqueada | 4 | 3 | 1 | - |

## Onda 1 — Cadastro e saldo
- [X] TASK-01 — Entidade CartaoTransporte e repositório      [backend-go]  a1b2c3d
- [X] TASK-02 — Endpoint POST /cartoes                       [backend-go]  b2c3d4e
- [X] TASK-03 — Endpoint GET /cartoes/{id}/saldo             [backend-go]  c3d4e5f
- [X] TASK-04 — Encerramento da onda 1                       [task-coder]  d4e5f6a

## Onda 2 — Recarga via Pix
- [X] TASK-05 — Gerar cobrança Pix dinâmica com txid único   [backend-go]  ad7cfe5
- [X] TASK-06 — Webhook de confirmação do PSP idempotente    [backend-go]  cd5f313
- [X] TASK-07 — Creditar saldo após confirmação              [backend-go]  598fbe6
- [X] TASK-08 — Expirar cobrança após 30 minutos             [backend-go]  3c70e95

## Onda 3 — Estorno
- [X] TASK-09 — Modelo de solicitação de estorno             [backend-go]  61cb4b1
- [X] TASK-10 — Regra de elegibilidade de 7 dias             [backend-go]  8de7f1e
- [X] TASK-11 — Devolução Pix via PSP                        [backend-go]  9c5f67b
- [!] TASK-12 — Conciliação do estorno com o saldo           [backend-go]  FALHA: TestConciliacaoEstornoParcial (saldo -150 != esperado 0)

## Wave 1 (TASK-01..TASK-04) — Cadastro e saldo ✅ MERGED

- PR: https://github.com/axis-mobfintech/bilhetagem-recarga/pull/41
- Jira: REC-17..REC-20 → `In Review`
