# Tasks — fare-validation

| TASK | Descrição | Tipo | RF | Depende de |
|---|---|---|---|---|
| TASK-01 | Scaffold do worker .NET 8, schema `validation`, migrations e outbox | infra | — | card-wallet TASK-01 |
| TASK-02 | Cadastro de dispositivo validador e autenticação mTLS | feature | RF-004 | TASK-01 |
| TASK-03 | Endpoint de ingestão de lote com idempotência por `deviceId`+`sequence` | feature | RF-004 | TASK-02 |
| TASK-04 | `FareCalculator` com janela de integração de 60 minutos e publicação de `FareCharged` | feature | RF-005 | TASK-03, card-wallet TASK-05 |
| TASK-05 | Consumidor de `WalletDebited` confirmando a cobrança | feature | RF-005 | TASK-04 |
| TASK-06 | Endpoint de consulta de embarques com filtros por linha e dispositivo | feature | RF-006 | TASK-03 |
| TASK-07 | Painel OpenTelemetry de latência de sincronização de lotes | infra | — | TASK-03 |
