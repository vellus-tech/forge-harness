# Backlog completo — Passe Livre (card-wallet, fare-validation, operator-clearing)

Gerado em 2026-09-26. Fonte: `docs/product/modules/{card-wallet,fare-validation,operator-clearing}` no diretório de trabalho deste run.

## Estado dos módulos

| Módulo | README | requirements.md | design.md | tasks.md | Situação |
|---|---|---|---|---|---|
| card-wallet | ok | ok | ok | ok | pronto para backlog direto |
| fare-validation | ok | ok | ok | ok | pronto para backlog direto |
| operator-clearing | ok | ok | ok | **ausente** | tasks-writer não rodou; ver nota de risco abaixo |

## Backlog — card-wallet (fonte: tasks.md do módulo)

| ID | Descrição | Tipo | RF | Depende de | Estimativa |
|---|---|---|---|---|---|
| CW-TASK-01 | Scaffold da solução .NET 8 (Domain/Application/Infrastructure/Api), pipeline de CI e health check | infra | — | — | 3 pts |
| CW-TASK-02 | Schema `wallet` + migrations EF Core + outbox transacional | infra | — | CW-TASK-01 | 3 pts |
| CW-TASK-03 | Agregado `Wallet` e endpoint `POST /api/v1/wallets` com regra de cartão já vinculado | feature | RF-001 | CW-TASK-02 | 5 pts |
| CW-TASK-04 | Adaptador `IPixGateway` (geração de QR Code) e endpoint de solicitação de recarga | feature | RF-002 | CW-TASK-03 | 5 pts |
| CW-TASK-05 | Webhook Pix com validação HMAC e crédito idempotente por `endToEndId` | feature | RF-002 | CW-TASK-04 | 5 pts |
| CW-TASK-06 | Endpoint de saldo e extrato paginado | feature | RF-003 | CW-TASK-03 | 3 pts |
| CW-TASK-07 | Testes de integração do fluxo de recarga com PSP simulado (Testcontainers) | test | RF-002 | CW-TASK-05 | 3 pts |

Total: 27 pontos.

## Backlog — fare-validation (fonte: tasks.md do módulo)

| ID | Descrição | Tipo | RF | Depende de | Estimativa |
|---|---|---|---|---|---|
| FV-TASK-01 | Scaffold do worker .NET 8, schema `validation`, migrations e outbox | infra | — | CW-TASK-01 | 3 pts |
| FV-TASK-02 | Cadastro de dispositivo validador e autenticação mTLS | feature | RF-004 | FV-TASK-01 | 5 pts |
| FV-TASK-03 | Endpoint de ingestão de lote com idempotência por `deviceId`+`sequence` | feature | RF-004 | FV-TASK-02 | 5 pts |
| FV-TASK-04 | `FareCalculator` com janela de integração de 60 minutos e publicação de `FareCharged` | feature | RF-005 | FV-TASK-03, CW-TASK-05 | 8 pts |
| FV-TASK-05 | Consumidor de `WalletDebited` confirmando a cobrança | feature | RF-005 | FV-TASK-04 | 3 pts |
| FV-TASK-06 | Endpoint de consulta de embarques com filtros por linha e dispositivo | feature | RF-006 | FV-TASK-03 | 3 pts |
| FV-TASK-07 | Painel OpenTelemetry de latência de sincronização de lotes | infra | — | FV-TASK-03 | 2 pts |

Total: 29 pontos.

## Backlog — operator-clearing (DRAFT — estimado por mim a partir do design.md, NÃO passou por tasks-writer)

> Ver `outputs/operator-clearing-tasks-draft.md` para a íntegra e para a justificativa de cada task. Resumo:

| ID | Descrição | Tipo | RF | Depende de | Estimativa | Confiança |
|---|---|---|---|---|---|---|
| OC-TASK-01 (draft) | Scaffold do job batch .NET 8 (CronJob K8s), schema `clearing`, migrations | infra | — | — | 3 pts | baixa |
| OC-TASK-02 (draft) | Read model replicado de `FareCharged` a partir de `validation` (schema clearing) | feature | RF-008 | OC-TASK-01, FV-TASK-04 | 5 pts | baixa |
| OC-TASK-03 (draft) | Cálculo de cota por operadora e persistência em `clearing.operator_share` | feature | RF-008 | OC-TASK-02 | 5 pts | baixa |
| OC-TASK-04 (draft) | Adaptador `ISettlementFileWriter` + gerador CNAB 240 | feature | RF-009 | OC-TASK-03 | 5 pts | baixa |
| OC-TASK-05 (draft) | Endpoint/job de disparo do fechamento às 02:00 e trigger manual | feature | RF-008 | OC-TASK-03 | 3 pts | baixa |
| OC-TASK-06 (draft) | Testes de integração do fechamento + validação de soma do CNAB | test | RF-008, RF-009 | OC-TASK-04, OC-TASK-05 | 3 pts | baixa |

Total (draft): 24 pontos.

**Confiança "baixa" em todas as tasks de operator-clearing**: não houve o passo de tasks-writer (que cruza requirements + design + constraints do TRD e do FORGE.md antes de fatiar em tasks), então não há garantia de que granularidade, dependências e RFs cobertos estejam corretos. Ver nota de risco abaixo.

## Plano de sprints

Hoje é sábado, 2026-09-26. A sprint review com o consórcio é sexta-feira, 2026-10-02. Sprint 1 cobre essa janela (seg 28/09 a sex 02/10); Sprint 2 seria a semana seguinte.

### Sprint 1 (28/09 – 02/10) — 6 dias úteis

Foco: fechar a fundação e o caminho crítico de card-wallet e fare-validation, que têm tasks validadas. Capacidade estimada: ~28-30 pontos (equipe pequena, sprint curta).

| Ordem | ID | Módulo | Pontos | Justificativa |
|---|---|---|---|---|
| 1 | CW-TASK-01 | card-wallet | 3 | bloqueia tudo, inclusive fare-validation |
| 2 | CW-TASK-02 | card-wallet | 3 | schema + outbox necessários para o agregado |
| 3 | CW-TASK-03 | card-wallet | 5 | endpoint de criação de wallet, desbloqueia RF-003 e RF-002 |
| 4 | FV-TASK-01 | fare-validation | 3 | paralelo, só depende de CW-TASK-01 |
| 5 | CW-TASK-04 | card-wallet | 5 | recarga Pix |
| 6 | CW-TASK-06 | card-wallet | 3 | saldo/extrato, paralelo ao Pix |
| 7 | FV-TASK-02 | fare-validation | 5 | cadastro de validador, paralelo |
| 8 | CW-TASK-05 | card-wallet | 5 | webhook Pix — fecha o ciclo de recarga |

Subtotal Sprint 1: 32 pontos (card-wallet quase completo; fare-validation com fundação + cadastro de dispositivo prontos). Ajustar para baixo se a equipe for pequena — priorizar itens 1-6 como corte mínimo (24 pts) e itens 7-8 como stretch.

Sprint 1 **não inclui operator-clearing** no compromisso, pelo motivo descrito na nota de risco. As tasks draft do operator-clearing entram como item de backlog para validação técnica (não para execução), em paralelo à sprint, sem consumir capacidade de sprint.

### Sprint 2 (05/10 – 16/10, duas semanas)

| Ordem | ID | Módulo | Pontos |
|---|---|---|---|
| 1 | CW-TASK-07 | card-wallet | 3 |
| 2 | FV-TASK-03 | fare-validation | 5 |
| 3 | FV-TASK-04 | fare-validation | 8 |
| 4 | FV-TASK-05 | fare-validation | 3 |
| 5 | FV-TASK-06 | fare-validation | 3 |
| 6 | FV-TASK-07 | fare-validation | 2 |
| 7 | OC-TASK-01 (se validado) | operator-clearing | 3 |
| 8 | OC-TASK-02 (se validado) | operator-clearing | 5 |

Operator-clearing só entra na Sprint 2 depois que as tasks draft forem revisadas (ver nota de risco); se a revisão pedir retrabalho, os itens 7-8 saem e viram itens de Sprint 3.

## Nota de risco — operator-clearing sem tasks.md

O pedido do usuário foi para eu mesmo estimar as tasks de operator-clearing a partir do design, para não atrasar a sprint review de sexta. Fiz isso (ver draft acima e o arquivo dedicado), mas é importante separar fato, interpretação e recomendação:

- **Fato:** operator-clearing tem README, requirements e design prontos, mas nenhuma tasks.md gerada pelo processo normal (tasks-writer). As tasks draft acima são estimativa minha, sem o cruzamento formal contra o TRD e sem validação humana.
- **Interpretação:** o risco maior não é a sprint ficar sem trabalho — é comprometer no Jira e na reunião com o consórcio um plano para operator-clearing com dependências e RFs errados, especialmente porque o módulo tem uma peça sensível (fechamento financeiro diário e geração de arquivo bancário CNAB 240), onde erro de estimativa ou de dependência tem custo alto se descoberto depois de comprometido publicamente.
- **Recomendação:** subir para o Jira, sem ressalva, apenas os backlogs de card-wallet e fare-validation (tasks validadas). Subir as tasks de operator-clearing também, mas com label/tag "draft — pendente de validação técnica" e fora do compromisso de sprint, deixando claro na reunião de sexta que esse módulo está em estimativa preliminar e ainda não tem plano de sprint comprometido. Rodar o tasks-writer (ou revisão técnica equivalente) em paralelo, o mais rápido possível, para substituir o draft antes de comprometer datas de entrega do operator-clearing.

Essa recomendação é minha leitura da situação; o usuário pode decidir subir tudo como compromisso firme mesmo assim — a decisão de negócio é dele, mas os fatos acima (falta de tasks-writer, natureza financeira do módulo) precisam estar visíveis antes dessa decisão.
