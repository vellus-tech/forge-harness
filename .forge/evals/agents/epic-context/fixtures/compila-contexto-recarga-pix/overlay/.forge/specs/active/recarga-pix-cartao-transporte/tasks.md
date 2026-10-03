# Tasks — recarga-pix-cartao-transporte

## Wave 1 — Contratos e persistência

- [ ] TASK-01 — Contrato gRPC `pix.v1.CobrancaService` (rastreia: design §Contratos; paths: `proto/pix/v1/cobranca.proto`; depende: —)
- [ ] TASK-02 — Migration da tabela `recarga_pix` com unique em `txid` (rastreia: REQ-03; paths: `src/recarga/migrations/`; depende: —)

## Wave 2 — Fluxo de cobrança

- [ ] TASK-03 — Endpoint `POST /v1/recargas/pix` com validação de faixa de valor (rastreia: REQ-01; paths: `src/recarga/api/`; depende: TASK-01, TASK-02)
- [ ] TASK-04 — Webhook do PSP com verificação de assinatura e publicação de `RecargaPixLiquidada` via outbox (rastreia: REQ-02; paths: `src/pix/webhook/`; depende: TASK-01)

## Wave 3 — Crédito e expiração

- [ ] TASK-05 — Consumidor idempotente de `RecargaPixLiquidada` que credita o saldo (rastreia: REQ-02, REQ-03; paths: `src/recarga/consumers/`; depende: TASK-02, TASK-04)
- [ ] TASK-06 — Job de expiração e fila de devolução (rastreia: REQ-04; paths: `src/recarga/jobs/`; depende: TASK-05)
- [ ] TASK-07 — Hash HMAC do CPF do pagador (rastreia: REQ-05; paths: `src/pix/webhook/`; depende: TASK-04)
