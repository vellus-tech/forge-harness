# Tasks — 2026-09-recarga-pix

## Wave 1

- [X] TASK-01 — Migration da tabela recharge_ledger (paths: `db/migrations/0012_recharge_ledger.sql`)
- [X] TASK-02 — Cliente do PSP para cobrança Pix dinâmica (paths: `src/recarga/pix-client.ts`)
- [X] TASK-03 — Endpoint POST /recargas gerando QR code (paths: `src/recarga/routes.ts`; depende: TASK-01, TASK-02)

## Wave 2

- [X] TASK-04 — Validação HMAC do header x-psp-signature (paths: `src/recarga/webhook-signature.ts`)
- [ ] TASK-05 — Handler POST /webhooks/psp/pix idempotente por txid (paths: `src/recarga/webhook.ts`; depende: TASK-04)
- [ ] TASK-06 — Crédito no serviço saldo via gRPC após confirmação (paths: `src/recarga/credit.ts`; depende: TASK-05)

## Wave 3

- [ ] TASK-07 — Job de conciliação diária com extrato CNAB do PSP (paths: `src/conciliacao/job.ts`)
- [ ] TASK-08 — Relatório de divergências recharge_divergence (paths: `src/conciliacao/divergencias.ts`; depende: TASK-07)

## Wave 4

- [ ] TASK-09 — Limite diário de R$ 500 por CPF na emissão do QR code (paths: `src/recarga/limite-cpf.ts`)
- [ ] TASK-10 — Estorno Pix (devolução) para recarga não creditada (paths: `src/recarga/estorno.ts`; depende: TASK-06)
