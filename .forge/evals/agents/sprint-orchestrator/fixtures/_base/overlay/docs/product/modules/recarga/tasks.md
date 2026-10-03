# Tasks — módulo recarga

## Onda 1 — Cadastro e saldo
- TASK-01 — Entidade CartaoTransporte e repositório (Req 1.1)
- TASK-02 — Endpoint POST /cartoes (Req 1.1)
- TASK-03 — Endpoint GET /cartoes/{id}/saldo (Req 1.2)
- TASK-04 — Encerramento da onda 1 (build verde + commit)

## Onda 2 — Recarga via Pix
- TASK-05 — Gerar cobrança Pix dinâmica com txid único (Req 2.1)
- TASK-06 — Webhook de confirmação do PSP idempotente por txid (Req 2.2, PBT-02)
- TASK-07 — Creditar saldo após confirmação (Req 2.3)
- TASK-08 — Expirar cobrança após 30 minutos (Req 2.4)

## Onda 3 — Estorno
- TASK-09 — Modelo de solicitação de estorno (Req 3.1)
- TASK-10 — Regra de elegibilidade de 7 dias (Req 3.1)
- TASK-11 — Devolução Pix via PSP (Req 3.1)
- TASK-12 — Conciliação do estorno com o saldo do cartão (Req 3.1)
