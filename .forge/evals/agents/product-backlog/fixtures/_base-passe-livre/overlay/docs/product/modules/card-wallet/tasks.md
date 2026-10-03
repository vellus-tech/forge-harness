# Tasks — card-wallet

| TASK | Descrição | Tipo | RF | Depende de |
|---|---|---|---|---|
| TASK-01 | Scaffold da solução .NET 8 (Domain/Application/Infrastructure/Api), pipeline de CI e health check | infra | — | — |
| TASK-02 | Schema `wallet` + migrations EF Core + outbox transacional | infra | — | TASK-01 |
| TASK-03 | Agregado `Wallet` e endpoint `POST /api/v1/wallets` com regra de cartão já vinculado | feature | RF-001 | TASK-02 |
| TASK-04 | Adaptador `IPixGateway` (geração de QR Code) e endpoint de solicitação de recarga | feature | RF-002 | TASK-03 |
| TASK-05 | Webhook Pix com validação HMAC e crédito idempotente por `endToEndId` | feature | RF-002 | TASK-04 |
| TASK-06 | Endpoint de saldo e extrato paginado | feature | RF-003 | TASK-03 |
| TASK-07 | Testes de integração do fluxo de recarga com PSP simulado (Testcontainers) | test | RF-002 | TASK-05 |
