# Product Backlog

- **Versão:** 1.1.0
- **Data:** 2026-09-26
- **Status:** Em planejamento
- **Total de épicos (módulos):** 2
- **Total de user stories:** 7
- **Total de tasks:** 5

## 1. Épicos (Módulos)

| ID Local | Épico (Módulo) | Subdomínio | Compliance | Stories | Tasks | Status |
|---|---|---|---|---|---|---|
| EP-001 | card-wallet | Supporting | LGPD | 4 | 3 | Em planejamento |
| EP-002 | fare-validation | Core | — | 3 | 2 | Em planejamento |

## 2. User Stories (todas)

| ID Local | Épico | Story | RF | Story Points | Sprint | Status |
|---|---|---|---|---|---|---|
| US-001 | card-wallet | Como passageiro, quero criar minha carteira vinculada ao CPF, para usar saldo pré-pago no embarque | RF-001 | 5 | Sprint 1 | TO DO |
| US-002 | card-wallet | Como passageiro, quero recarregar por Pix, para não depender de ponto de venda | RF-002 | 8 | Sprint 2 | TO DO |
| US-003 | card-wallet | Como passageiro, quero ver saldo e extrato, para controlar meus gastos | RF-003 | 3 | Sprint 2 | TO DO |
| US-007 | card-wallet | Como passageiro, quero bloquear meu cartão perdido pelo app, para que ninguém use meu saldo | RF-007 | 5 | Sprint 2 | TO DO |
| US-004 | fare-validation | Como validador embarcado, quero enviar lotes offline, para que as tarifas sejam cobradas | RF-004 | 8 | Sprint 2 | TO DO |
| US-005 | fare-validation | Como passageiro, quero integração de 60 minutos, para pagar uma tarifa só | RF-005 | 8 | Sprint 3 | TO DO |
| US-006 | fare-validation | Como operador de backoffice, quero listar embarques das últimas 24h, para auditar contestações | RF-006 | 3 | Sprint 3 | TO DO |

## 3. Tasks (todas)

| ID Local | Story Pai | Task | TASK ref | Status |
|---|---|---|---|---|
| T-001 | US-001 | Scaffold .NET 8, CI e health check | task:TASK-01 (card-wallet) | TO DO |
| T-002 | US-001 | Schema wallet, migrations e outbox | task:TASK-02 (card-wallet) | TO DO |
| T-003 | US-002 | Testes de integração do fluxo de recarga | task:TASK-07 (card-wallet) | TO DO |
| T-004 | US-004 | Scaffold do worker e schema validation | task:TASK-01 (fare-validation) | TO DO |
| T-005 | US-004 | Painel OTel de latência de sincronização | task:TASK-07 (fare-validation) | TO DO |

## 4. Bugs ativos

| ID Local | Épico | Bug | Severidade | Sprint | Status |
|---|---|---|---|---|---|

## 5. Mapeamento Local ↔ Jira

| ID Local | Issue Key Jira | Sincronizado em | Última sync |
|---|---|---|---|
| EP-001 | PLD-1 | 2026-09-25T18:02:11Z | OK |
| US-001 | PLD-2 | 2026-09-25T18:02:40Z | OK |
| US-002 | PLD-3 | 2026-09-25T18:03:05Z | OK |
| US-003 | PLD-4 | 2026-09-25T18:03:31Z | OK |
