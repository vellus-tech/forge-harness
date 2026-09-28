# Product Backlog

- **Versão:** 1.0.0
- **Data:** 2026-09-26
- **Status:** Em planejamento
- **Total de épicos (módulos):** 2
- **Total de user stories:** 6
- **Total de tasks:** 14

## 1. Épicos (Módulos)

| ID Local | Épico (Módulo) | Subdomínio | Compliance | Stories | Tasks | Status |
|---|---|---|---|---|---|---|
| EP-001 | card-wallet | Supporting | LGPD | 3 | 7 | Em planejamento |
| EP-002 | fare-validation | Core | — | 3 | 7 | Em planejamento |

## 2. User Stories (todas)

| ID Local | Épico | Story | RF | Story Points | Sprint | Status |
|---|---|---|---|---|---|---|
| US-001 | card-wallet | Como passageiro, quero criar minha carteira informando CPF e cartão, para usar o saldo pré-pago no embarque | RF-001 | 5 | Sprint 1 | TO DO |
| US-002 | card-wallet | Como passageiro, quero recarregar minha carteira via Pix, para não depender de ponto de venda físico | RF-002 | 8 | Sprint 2 | TO DO |
| US-003 | card-wallet | Como passageiro, quero ver meu saldo e as últimas 30 movimentações, para controlar meus gastos com transporte | RF-003 | 3 | Sprint 2 | TO DO |
| US-004 | fare-validation | Como validador embarcado, quero enviar o lote de embarques acumulado offline, para que as tarifas sejam cobradas quando houver conectividade | RF-004 | 8 | Sprint 2 | TO DO |
| US-005 | fare-validation | Como passageiro, quero pagar uma única tarifa em embarques feitos em até 60 minutos, para ter integração entre linhas | RF-005 | 8 | Sprint 3 | TO DO |
| US-006 | fare-validation | Como operador de backoffice, quero listar os embarques das últimas 24h filtrando por linha e dispositivo, para auditar cobranças contestadas | RF-006 | 3 | Sprint 2 | TO DO |

**Total de Story Points:** 35

## 3. Tasks (todas)

| ID Local | Story Pai | Task | TASK ref | Status |
|---|---|---|---|---|
| T-001 | — (épico card-wallet) | Scaffold da solução .NET 8 (Domain/Application/Infrastructure/Api), pipeline de CI e health check | card-wallet TASK-01 | TO DO |
| T-002 | — (épico card-wallet) | Schema `wallet` + migrations EF Core + outbox transacional | card-wallet TASK-02 | TO DO |
| T-003 | US-001 | Agregado `Wallet` e endpoint `POST /api/v1/wallets` com regra de cartão já vinculado | card-wallet TASK-03 | TO DO |
| T-004 | US-002 | Adaptador `IPixGateway` (geração de QR Code) e endpoint de solicitação de recarga | card-wallet TASK-04 | TO DO |
| T-005 | US-002 | Webhook Pix com validação HMAC e crédito idempotente por `endToEndId` | card-wallet TASK-05 | TO DO |
| T-006 | US-003 | Endpoint de saldo e extrato paginado | card-wallet TASK-06 | TO DO |
| T-007 | US-002 | Testes de integração do fluxo de recarga com PSP simulado (Testcontainers) | card-wallet TASK-07 | TO DO |
| T-008 | — (épico fare-validation) | Scaffold do worker .NET 8, schema `validation`, migrations e outbox | fare-validation TASK-01 | TO DO |
| T-009 | US-004 | Cadastro de dispositivo validador e autenticação mTLS | fare-validation TASK-02 | TO DO |
| T-010 | US-004 | Endpoint de ingestão de lote com idempotência por `deviceId`+`sequence` | fare-validation TASK-03 | TO DO |
| T-011 | US-005 | `FareCalculator` com janela de integração de 60 minutos e publicação de `FareCharged` | fare-validation TASK-04 | TO DO |
| T-012 | US-005 | Consumidor de `WalletDebited` confirmando a cobrança | fare-validation TASK-05 | TO DO |
| T-013 | US-006 | Endpoint de consulta de embarques com filtros por linha e dispositivo | fare-validation TASK-06 | TO DO |
| T-014 | — (épico fare-validation) | Painel OpenTelemetry de latência de sincronização de lotes | fare-validation TASK-07 | TO DO |

## 4. Bugs ativos

| ID Local | Épico | Bug | Severidade | Sprint | Status |
|---|---|---|---|---|---|

Nenhum bug ativo nesta primeira execução — backlog partiu direto da especificação, sem histórico de defeitos.

## 5. Mapeamento Local ↔ Jira

| ID Local | Issue Key Jira | Sincronizado em | Última sync |
|---|---|---|---|
| EP-001 | — | — | Pendente (ver `progress-tracking.md` §2) |
| EP-002 | — | — | Pendente (ver `progress-tracking.md` §2) |
| US-001 | — | — | Pendente |
| US-002 | — | — | Pendente |
| US-003 | — | — | Pendente |
| US-004 | — | — | Pendente |
| US-005 | — | — | Pendente |
| US-006 | — | — | Pendente |
| T-001..T-014 | — | — | Pendente |

Nenhuma issue foi criada no Jira nesta execução — a sincronização com o projeto Scrum PLD foi simulada e registrada em `progress-tracking.md` §2 e em `outputs/jira-sync-simulation.md`, por restrição do ambiente de avaliação (nenhuma chamada de escrita externa é executada; ver §7.4 do agente `product-backlog` para a sequência real que seria disparada contra o MCP Atlassian).
