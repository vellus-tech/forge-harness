# Product Backlog — Passe Livre Digital

- **Fonte:** docs/product/modules/{card-wallet,fare-validation} + docs/product/trd/trd.md
- **Projeto Jira:** PLD (Scrum, já existente)
- **Data de geração:** 2026-09-26

## Critério de estimativa

Story points em escala Fibonacci (1, 2, 3, 5, 8, 13), atribuídos por complexidade técnica e superfície de teste de cada TASK do tasks.md de cada módulo, agrupadas em stories por requisito funcional (RF) ou por entrega de infraestrutura. Tasks de infraestrutura sem RF associado viram stories de habilitação (enabler).

## Épico 1 — Carteira do Passageiro (card-wallet)

| Story | Título | RF | Tasks de origem | Pontos | Depende de |
|---|---|---|---|---|---|
| CW-1 | Scaffold da solução, schema `wallet` e outbox transacional | — (enabler) | TASK-01, TASK-02 | 5 | — |
| CW-2 | Criar carteira vinculada ao CPF | RF-001 | TASK-03 | 5 | CW-1 |
| CW-3 | Recarga via Pix (QR Code + webhook idempotente) | RF-002 | TASK-04, TASK-05 | 8 | CW-2 |
| CW-4 | Consultar saldo e extrato paginado | RF-003 | TASK-06 | 3 | CW-2 |
| CW-5 | Testes de integração do fluxo de recarga (PSP simulado) | RF-002 | TASK-07 | 5 | CW-3 |

Subtotal: **26 pontos**

## Épico 2 — Validação de Embarque (fare-validation)

| Story | Título | RF | Tasks de origem | Pontos | Depende de |
|---|---|---|---|---|---|
| FV-1 | Scaffold do worker, schema `validation` e outbox | — (enabler) | TASK-01 | 5 | CW-1 |
| FV-2 | Cadastro de dispositivo validador e autenticação mTLS | RF-004 | TASK-02 | 5 | FV-1 |
| FV-3 | Ingestão de lote de embarques com idempotência | RF-004 | TASK-03 | 5 | FV-2 |
| FV-4 | Cálculo de tarifa com integração temporal (60 min) e publicação `FareCharged` | RF-005 | TASK-04 | 8 | FV-3, CW-3 |
| FV-5 | Consumidor de `WalletDebited` confirmando cobrança | RF-005 | TASK-05 | 3 | FV-4 |
| FV-6 | Consulta de embarques no backoffice com filtros | RF-006 | TASK-06 | 3 | FV-3 |
| FV-7 | Painel OpenTelemetry de latência de sincronização de lotes | — (enabler / mitigação de ressalva) | TASK-07 | 3 | FV-3 |

Subtotal: **32 pontos**

**Total do backlog: 58 pontos.**

## Observação de risco herdada da validação de módulos

O relatório `docs/product/modules/modules-validation-report.md` registrou ressalva no módulo `fare-validation`: falta de SLO numérico de latência de sincronização offline no NFRD. A story FV-7 (painel de latência) foi incluída como enabler para instrumentar a métrica; o SLO numérico em si continua pendente de definição de produto e não está representado como story — deve voltar ao NFRD antes do fechamento do Épico 2.

## Dependências entre épicos

`fare-validation` depende de `card-wallet` em dois pontos: o scaffold de `validation-sync` depende do scaffold de `wallet-api` estar publicado (FV-1 → CW-1, conforme TRD DEP-01/DEP-02 compartilharem o mesmo Postgres gerenciado), e o cálculo de tarifa (FV-4) depende do webhook Pix idempotente (CW-3) estar concluído, pois o evento `FareCharged` só faz sentido com saldo passível de débito (`WalletDebited`/`FareCharged` conforme descrito nos README de ambos os módulos).
