# Sprint 2 — recarga-pix-cadastro-validador-e-auditoria

- **Objetivo:** ao final desta sprint, o passageiro consegue recarregar a carteira via Pix e consultar saldo/extrato, o validador embarcado está cadastrado e autenticado por mTLS enviando lotes de embarque, e o operador de backoffice já consegue auditar esses embarques.
- **Período:** 2026-10-19 a 2026-11-01
- **Story Points totais:** 22
- **Status:** Planejada
- **Dependências:** Sprint 1

## 1. Backlog da Sprint

### US-002 — Recarregar via Pix
- **Épico:** card-wallet
- **RF rastreado:** RF-002
- **Story Points:** 8
- **Status atual:** TO DO
- **Issue Jira:** pendente

#### Critérios de aceite
- [ ] Dado valor entre R$ 5,00 e R$ 500,00, quando o passageiro solicita recarga, então recebe QR Code Pix com expiração de 15 minutos
- [ ] Dado webhook de pagamento confirmado do PSP, quando processado, então o saldo é creditado uma única vez (idempotente por `endToEndId`)

#### Tasks técnicas
- T-004: Adaptador `IPixGateway` (geração de QR Code) e endpoint de solicitação de recarga — Status: TO DO — Depende de T-003 (Sprint 1) — Issue Jira: pendente
- T-005: Webhook Pix com validação HMAC e crédito idempotente por `endToEndId` — Status: TO DO — Depende de T-004 — Issue Jira: pendente
- T-007: Testes de integração do fluxo de recarga com PSP simulado (Testcontainers) — Status: TO DO — Depende de T-005 — Issue Jira: pendente

#### Definition of Done
- [ ] Código implementado conforme critérios
- [ ] Testes unitários (cobertura conforme `quality-gates.md`)
- [ ] Testes de integração (quando aplicável)
- [ ] Code review aprovado
- [ ] CI verde
- [ ] Commit conforme `conventional-commits.md`
- [ ] PR mergeado

---

### US-003 — Consultar saldo e extrato
- **Épico:** card-wallet
- **RF rastreado:** RF-003
- **Story Points:** 3
- **Status atual:** TO DO
- **Issue Jira:** pendente

#### Critérios de aceite
- [ ] Dado carteira existente, quando chama `GET /api/v1/wallets/{id}/statement`, então recebe saldo em centavos e lista ordenada por data decrescente

#### Tasks técnicas
- T-006: Endpoint de saldo e extrato paginado — Status: TO DO — Depende de T-003 (Sprint 1) — Issue Jira: pendente

#### Definition of Done
- [ ] Código implementado conforme critérios
- [ ] Testes unitários (cobertura conforme `quality-gates.md`)
- [ ] Testes de integração (quando aplicável)
- [ ] Code review aprovado
- [ ] CI verde
- [ ] Commit conforme `conventional-commits.md`
- [ ] PR mergeado

---

### US-004 — Receber lote de embarques offline
- **Épico:** fare-validation
- **RF rastreado:** RF-004
- **Story Points:** 8
- **Status atual:** TO DO
- **Issue Jira:** pendente

#### Critérios de aceite
- [ ] Dado lote assinado pelo dispositivo cadastrado, quando enviado a `POST /api/v1/boarding-batches`, então recebe 202 e cada embarque é persistido uma única vez (idempotente por `deviceId`+`sequence`)
- [ ] Dado dispositivo não cadastrado, quando envia o lote, então recebe 403

#### Tasks técnicas
- T-009: Cadastro de dispositivo validador e autenticação mTLS — Status: TO DO — Depende de T-008 (Sprint 1) — Issue Jira: pendente
- T-010: Endpoint de ingestão de lote com idempotência por `deviceId`+`sequence` — Status: TO DO — Depende de T-009 — Issue Jira: pendente

#### Definition of Done
- [ ] Código implementado conforme critérios
- [ ] Testes unitários (cobertura conforme `quality-gates.md`)
- [ ] Testes de integração (quando aplicável)
- [ ] Code review aprovado
- [ ] CI verde
- [ ] Commit conforme `conventional-commits.md`
- [ ] PR mergeado

---

### US-006 — Consultar embarques no backoffice
- **Épico:** fare-validation
- **RF rastreado:** RF-006
- **Story Points:** 3
- **Status atual:** TO DO
- **Issue Jira:** pendente

#### Critérios de aceite
- [ ] Dado filtros válidos, quando chama `GET /api/v1/boarding-events`, então recebe lista paginada com valor cobrado por embarque

#### Tasks técnicas
- T-013: Endpoint de consulta de embarques com filtros por linha e dispositivo — Status: TO DO — Depende de T-010 — Issue Jira: pendente

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
| Valor cobrado em US-006 (`GET /api/v1/boarding-events`) já pressupõe o cálculo de `FareCalculator` (US-005, Sprint 3), que ainda não existe nesta sprint | Endpoint retorna o valor cobrado apenas para embarques já processados por `FareCharged`; embarques ainda sem tarifa aplicada aparecem com valor pendente, documentado explicitamente na resposta da API |
| Quatro frentes simultâneas (Pix, saldo, cadastro mTLS, ingestão de lote) para um time de 4 devs | Um dev por frente evita contenção; testes de integração (T-007) só entram após o par QR+webhook estabilizar |

## 4. Encerramento

- [ ] Todas as stories em DONE
- [ ] Todos os PRs mergeados
- [ ] Sprint encerrada no Jira
- [ ] Retrospectiva agendada/realizada
- [ ] Tracking atualizado em `progress-tracking.md`
