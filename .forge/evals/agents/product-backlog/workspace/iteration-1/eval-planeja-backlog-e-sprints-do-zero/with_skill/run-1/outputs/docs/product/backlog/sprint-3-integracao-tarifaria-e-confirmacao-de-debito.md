# Sprint 3 — integracao-tarifaria-e-confirmacao-de-debito

- **Objetivo:** ao final desta sprint, o sistema cobra automaticamente a tarifa com integração de até 60 minutos e confirma o débito na carteira do passageiro, entregando o fluxo ponta-a-ponta do Passe Livre Digital.
- **Período:** 2026-11-02 a 2026-11-15
- **Story Points totais:** 11 (8 de story + 3 infra)
- **Status:** Planejada
- **Dependências:** Sprint 1, Sprint 2

## 1. Backlog da Sprint

### US-005 — Cobrar tarifa com integração temporal
- **Épico:** fare-validation
- **RF rastreado:** RF-005
- **Story Points:** 8
- **Status atual:** TO DO
- **Issue Jira:** pendente

#### Critérios de aceite
- [ ] Dado segundo embarque em até 60 minutos do primeiro, quando processado, então `FareCharged` é publicado com valor 0
- [ ] Dado embarque após 60 minutos, quando processado, então `FareCharged` é publicado com a tarifa cheia da `fare_rule` vigente

#### Tasks técnicas
- T-011: `FareCalculator` com janela de integração de 60 minutos e publicação de `FareCharged` — Status: TO DO — Depende de T-010 (Sprint 2) e T-005 (Sprint 2, card-wallet) — Issue Jira: pendente
- T-012: Consumidor de `WalletDebited` confirmando a cobrança — Status: TO DO — Depende de T-011 — Issue Jira: pendente

#### Definition of Done
- [ ] Código implementado conforme critérios
- [ ] Testes unitários (cobertura conforme `quality-gates.md`)
- [ ] Testes de integração (quando aplicável)
- [ ] Code review aprovado
- [ ] CI verde
- [ ] Commit conforme `conventional-commits.md`
- [ ] PR mergeado

---

### Tasks de fundação (sem story pai)

- T-014: Painel OpenTelemetry de latência de sincronização de lotes — Status: TO DO — Depende de T-010 (Sprint 2) — Issue Jira: pendente

---

## 2. Bugs Acompanhados

| ID | Severidade | Descrição | Status | Issue |
|---|---|---|---|---|

Nenhum bug nesta sprint.

## 3. Riscos da Sprint

| Risco | Mitigação |
|---|---|
| SLO de latência de sincronização offline ainda sem número no NFRD (ressalva do `modules-validation-report.md`) pode mudar o desenho de `FareCalculator` | Capacidade da sprint deixada abaixo do teto do time (11 de ~24 pontos) para absorver ajuste sem estourar o prazo; painel OTel (T-014) entrega o dado real de latência para fechar o SLO ainda nesta sprint |
| US-006 (Sprint 2) mostra valor pendente para embarques ainda sem `FareCharged`; após esta sprint, todo embarque deve ter valor definitivo | Validar em teste de integração que a consulta de auditoria reflete o valor final após `FareCalculator` rodar |

## 4. Encerramento

- [ ] Todas as stories em DONE
- [ ] Todos os PRs mergeados
- [ ] Sprint encerrada no Jira
- [ ] Retrospectiva agendada/realizada
- [ ] Tracking atualizado em `progress-tracking.md`
