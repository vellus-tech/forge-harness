# Sprint 1 — fundacao-e-criacao-de-carteira

- **Objetivo:** ao final desta sprint, a infraestrutura de wallet-api e validation-sync está no ar (CI, schemas, outbox transacional) e o passageiro consegue criar sua carteira vinculada ao CPF via API, viabilizando a primeira integração do app.
- **Período:** 2026-10-05 a 2026-10-18
- **Story Points totais:** 20 (15 infra + 5 de story)
- **Status:** Planejada
- **Dependências:** Nenhuma (sprint de fundação)

## 1. Backlog da Sprint

### Tasks de fundação (sem story pai — infraestrutura dos dois deployables)

- T-001: Scaffold da solução .NET 8 de card-wallet (Domain/Application/Infrastructure/Api), pipeline de CI e health check — Status: TO DO — Issue Jira: pendente
- T-002: Schema `wallet` + migrations EF Core + outbox transacional — Status: TO DO — Depende de T-001 — Issue Jira: pendente
- T-008: Scaffold do worker .NET 8 de fare-validation, schema `validation`, migrations e outbox — Status: TO DO — Depende de T-001 — Issue Jira: pendente

### US-001 — Criar carteira vinculada ao CPF
- **Épico:** card-wallet
- **RF rastreado:** RF-001
- **Story Points:** 5
- **Status atual:** TO DO
- **Issue Jira:** pendente

#### Critérios de aceite
- [ ] Dado CPF válido e cartão ativo não vinculado, quando o passageiro envia `POST /api/v1/wallets`, então recebe 201 com `walletId`
- [ ] Dado cartão já vinculado a outro CPF, quando envia o cadastro, então recebe 409 com código `CARD_ALREADY_LINKED`

#### Tasks técnicas
- T-003: Agregado `Wallet` e endpoint `POST /api/v1/wallets` com regra de cartão já vinculado — Status: TO DO — Depende de T-002 — Issue Jira: pendente

#### Definition of Done
- [ ] Código implementado conforme critérios
- [ ] Testes unitários (cobertura conforme `quality-gates.md`)
- [ ] Testes de integração (quando aplicável)
- [ ] Code review aprovado
- [ ] CI verde
- [ ] Commit conforme `conventional-commits.md`
- [ ] PR mergeado

---

## 2. Bugs Acompanhados

| ID | Severidade | Descrição | Status | Issue |
|---|---|---|---|---|

Nenhum bug nesta sprint.

## 3. Riscos da Sprint

| Risco | Mitigação |
|---|---|
| T-008 (scaffold fare-validation) depende de T-001 (scaffold card-wallet) no mesmo sprint | Sequenciar T-001 nos primeiros dias da sprint; se atrasar, priorizar T-001 sobre T-002 para não bloquear T-008 |

## 4. Encerramento

- [ ] Todas as stories em DONE
- [ ] Todos os PRs mergeados
- [ ] Sprint encerrada no Jira
- [ ] Retrospectiva agendada/realizada
- [ ] Tracking atualizado em `progress-tracking.md`
