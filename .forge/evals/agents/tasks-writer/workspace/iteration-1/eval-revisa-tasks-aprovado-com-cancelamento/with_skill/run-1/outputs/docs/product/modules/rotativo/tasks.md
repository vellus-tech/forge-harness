# Tasks — ROT — Estacionamento Rotativo Digital

- Versão: 1.1.0
- Data: 2026-09-26
- Status: Aprovado para desenvolvimento
- Referência base requirements: docs/product/modules/rotativo/requirements.md v1.2.0
- Referência base design: docs/product/modules/rotativo/design.md v1.1.0
- ADRs aplicáveis: ADR-0001, ADR-0002
- Rules aplicáveis: `.forge/rules/conventions/code-style.md`

## Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|------------------------|
| 1.0.0 | 2026-09-19 | Aprovado para desenvolvimento | Criação inicial do plano de tasks |
| 1.1.0 | 2026-09-26 | Aprovado para desenvolvimento | Inclusão do cancelamento com estorno proporcional (Req 4, PBT-04, DD-003): TASK-07 (handler de cancelamento), TASK-08 (persistência do estorno, migration V2) e TASK-09 (endpoint `DELETE /v1/ativacoes/{id}`). Nenhuma TASK existente foi renumerada, reordenada ou teve escopo alterado — TASK-03 permanece em andamento sem impacto. |

## 1. Convenções de Implementação

TDD-first (Red → Green → Refactor), PBT com FsCheck, subtasks abaixo de 2 horas, branch `<tipo>/rotativo/<NN>-<slug>`, Conventional Commits, status `[ ]` `[-]` `[X]` `[!]`, IDs `TASK-NN` com subtasks `ST-MM`.

## 2. Status Geral

| TASK | Título | Onda | Branch | Status |
|------|--------|------|--------|--------|
| TASK-01 | Solution Clean Architecture e teste de arquitetura | Onda 1 | `feat/rotativo/01-bootstrap` | [X] |
| TASK-02 | Aggregate Ativacao e value objects | Onda 2 | `feat/rotativo/02-aggregate-ativacao` | [X] |
| TASK-03 | Comprar ativação com idempotência | Onda 3 | `feat/rotativo/03-comprar-ativacao` | [-] |
| TASK-04 | Estender ativação | Onda 3 | `feat/rotativo/04-estender-ativacao` | [ ] |
| TASK-05 | Persistência, migration V1 e outbox | Onda 4 | `feat/rotativo/05-persistencia-outbox` | [ ] |
| TASK-06 | API, consulta por placa e observabilidade | Onda 5 | `feat/rotativo/06-api-consulta` | [ ] |
| TASK-07 | Cancelar ativação com estorno proporcional | Onda 3 | `feat/rotativo/07-cancelar-ativacao` | [ ] |
| TASK-08 | Persistência do estorno, migration V2 e outbox de cancelamento | Onda 4 | `feat/rotativo/08-persistencia-estorno` | [ ] |
| TASK-09 | API de cancelamento (`DELETE /v1/ativacoes/{id}`) | Onda 5 | `feat/rotativo/09-api-cancelamento` | [ ] |

## 3. Ondas de Implementação

| Onda | Foco | TASKs |
|------|------|-------|
| Onda 1 | Bootstrap | TASK-01 |
| Onda 2 | Domain | TASK-02 |
| Onda 3 | Application | TASK-03, TASK-04, TASK-07 |
| Onda 4 | Infrastructure | TASK-05, TASK-08 |
| Onda 5 | API + Hardening | TASK-06, TASK-09 |

## 4. Tarefas

### TASK-01 — Solution Clean Architecture e teste de arquitetura

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 1 — Bootstrap |
| **Branch** | `feat/rotativo/01-bootstrap` |
| **Status** | [X] |
| **Depende de** | Não aplicável |
| **Mapeia** | ADR-0001 |
| **Camada principal** | Tests |

#### Subtasks

- [X] **ST-01 — Red:** teste NetArchTest `Domain` sem referência a `Infrastructure`/`Api`.
- [X] **ST-02 — Green:** criar os 5 projetos e referências.
- [X] **ST-03 — Encerramento:** build verde, commit e push.

### TASK-02 — Aggregate Ativacao e value objects

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 2 — Domain |
| **Branch** | `feat/rotativo/02-aggregate-ativacao` |
| **Status** | [X] |
| **Depende de** | TASK-01 |
| **Mapeia** | Req 1, Req 2, PBT-03 |
| **Camada principal** | Domain |

#### Subtasks

- [X] **ST-01 — Red:** PBT-03 da máquina de estados com FsCheck.
- [X] **ST-02 — Green:** aggregate `Ativacao`, `Placa`, `Minutos`, `Dinheiro`.
- [X] **ST-03 — Refactor:** extrair política de tempo máximo da zona.
- [X] **ST-04 — Encerramento:** testes verdes, commit e push.

### TASK-03 — Comprar ativação com idempotência

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 3 — Application |
| **Branch** | `feat/rotativo/03-comprar-ativacao` |
| **Status** | [-] |
| **Depende de** | TASK-02 |
| **Mapeia** | Req 1, PBT-01, PBT-02, DD-001 |
| **Camada principal** | Application |

#### Subtasks

- [X] **ST-01 — Red:** PBT-01 (idempotência) e PBT-02 (conservação de saldo).
- [-] **ST-02 — Green:** handler `ComprarAtivacaoCommand`.
- [ ] **ST-03 — Refactor:** extrair verificação de saldo.
- [ ] **ST-04 — Encerramento:** testes verdes, commit e push.

### TASK-04 — Estender ativação

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 3 — Application |
| **Branch** | `feat/rotativo/04-estender-ativacao` |
| **Status** | [ ] |
| **Depende de** | TASK-03 |
| **Mapeia** | Req 2 |
| **Camada principal** | Application |

#### Subtasks

- [ ] **ST-01 — Red:** testes de ROT-002 e ROT-003 na extensão.
- [ ] **ST-02 — Green:** handler `EstenderAtivacaoCommand`.
- [ ] **ST-03 — Encerramento:** testes verdes, commit e push.

### TASK-05 — Persistência, migration V1 e outbox

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 4 — Infrastructure |
| **Branch** | `feat/rotativo/05-persistencia-outbox` |
| **Status** | [ ] |
| **Depende de** | TASK-03 |
| **Mapeia** | DD-001, DD-002, ADR-0002 |
| **Camada principal** | Infrastructure |

#### Subtasks

- [ ] **ST-01 — Red:** teste de integração (Testcontainers) gravando ativação e outbox na mesma transação.
- [ ] **ST-02 — Green:** `V1__ativacoes.sql` e repositórios.
- [ ] **ST-03 — Encerramento:** testes verdes, commit e push.

### TASK-06 — API, consulta por placa e observabilidade

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 5 — API + Hardening |
| **Branch** | `feat/rotativo/06-api-consulta` |
| **Status** | [ ] |
| **Depende de** | TASK-04, TASK-05 |
| **Mapeia** | Req 3, RNF 1, RNF 2 |
| **Camada principal** | Api |

#### Subtasks

- [ ] **ST-01 — Red:** testes de contrato dos 3 endpoints e teste de log sem placa completa.
- [ ] **ST-02 — Green:** endpoints, escopos OAuth e métricas.
- [ ] **ST-03 — Encerramento:** testes verdes, commit e push.

### TASK-07 — Cancelar ativação com estorno proporcional

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 3 — Application |
| **Branch** | `feat/rotativo/07-cancelar-ativacao` |
| **Status** | [ ] |
| **Depende de** | TASK-02 |
| **Mapeia** | Req 4, PBT-04, DD-003 |
| **Camada principal** | Application |

#### Objetivo

Implementar `CancelarAtivacaoCommand` e handler: transita a ativação `Ativa → Cancelada` (reutilizando a máquina de estados de PBT-03), calcula o estorno proporcional (`floor(minutos_restantes) × tarifa_por_minuto`) e rejeita com ROT-003 quando a ativação não estiver vigente. Não altera o débito original (DD-003) — apenas prepara o comando/handler; a gravação do lançamento de crédito e do evento `AtivacaoCancelada` fica com TASK-08 (Infrastructure/outbox).

#### Subtasks

- [ ] **ST-01 — Red:** PBT-04 (estorno limitado: `0 ≤ estorno ≤ valor_total_pago` e `valor_debitado_liquido + estorno = valor_total_pago`) e teste de rejeição ROT-003 para ativação não vigente.
- [ ] **ST-02 — Green:** handler `CancelarAtivacaoCommand` com cálculo do estorno e transição de estado.
- [ ] **ST-03 — Refactor:** extrair cálculo de estorno proporcional para método/objeto de domínio reutilizável.
- [ ] **ST-04 — Encerramento:** testes verdes, commit e push.

#### Critérios de Aceite

- [ ] Testes da camada Application executados com sucesso
- [ ] Coverage gate de Application (90%) atendido ou justificativa registrada
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz (Req 4, PBT-04, DD-003 → TASK-07)
- [ ] Documentação atualizada quando aplicável

### TASK-08 — Persistência do estorno, migration V2 e outbox de cancelamento

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 4 — Infrastructure |
| **Branch** | `feat/rotativo/08-persistencia-estorno` |
| **Status** | [ ] |
| **Depende de** | TASK-05, TASK-07 |
| **Mapeia** | DD-003, ADR-0002 |
| **Camada principal** | Infrastructure |

#### Objetivo

Aplicar `V2__cancelamento.sql` (coluna `cancelada_em` em `ativacoes` e tabela `carteira_lancamentos`), gravar o lançamento de crédito do estorno e publicar `AtivacaoCancelada` via outbox — tudo na mesma transação (DD-003, ADR-0002), reaproveitando o padrão de outbox de TASK-05.

#### Subtasks

- [ ] **ST-01 — Red:** teste de integração (Testcontainers) que cancela uma ativação e verifica, na mesma transação, o lançamento em `carteira_lancamentos` e o evento na tabela `outbox`.
- [ ] **ST-02 — Green:** `V2__cancelamento.sql` e repositório de `carteira_lancamentos`.
- [ ] **ST-03 — Encerramento:** testes verdes, commit e push.

#### Critérios de Aceite

- [ ] Testes de integração executados com sucesso
- [ ] Coverage gate de Infrastructure (70%) atendido ou justificativa registrada
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz (DD-003, ADR-0002 → TASK-08)
- [ ] Documentação atualizada quando aplicável

### TASK-09 — API de cancelamento (`DELETE /v1/ativacoes/{id}`)

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 5 — API + Hardening |
| **Branch** | `feat/rotativo/09-api-cancelamento` |
| **Status** | [ ] |
| **Depende de** | TASK-06, TASK-07, TASK-08 |
| **Mapeia** | Req 4, DD-003 |
| **Camada principal** | Api |

#### Objetivo

Expor `DELETE /v1/ativacoes/{id}` com escopo `motorista:write`, retornando o valor do estorno e tratando ROT-003, reaproveitando a infraestrutura de endpoints e escopos OAuth criada em TASK-06.

#### Subtasks

- [ ] **ST-01 — Red:** teste de contrato do endpoint `DELETE /v1/ativacoes/{id}` cobrindo sucesso (estorno) e ROT-003.
- [ ] **ST-02 — Green:** endpoint, escopo OAuth e serialização da resposta de estorno.
- [ ] **ST-03 — Encerramento:** testes verdes, commit e push.

#### Critérios de Aceite

- [ ] Testes de contrato executados com sucesso
- [ ] Coverage gate de Api (80%) atendido ou justificativa registrada
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz (Req 4 → TASK-09)
- [ ] Documentação atualizada quando aplicável

## 5. Matriz de Rastreabilidade

| Origem | Descrição | TASKs | Status |
|--------|-----------|-------|--------|
| Req 1 | Comprar ativação | TASK-02, TASK-03 | [-] |
| Req 2 | Estender ativação | TASK-02, TASK-04 | [ ] |
| Req 3 | Consultar por placa | TASK-06 | [ ] |
| Req 4 | Cancelar com estorno proporcional | TASK-07, TASK-08, TASK-09 | [ ] |
| RNF 1 | Latência p95 < 300 ms | TASK-06 | [ ] |
| RNF 2 | Placa mascarada em logs | TASK-06 | [ ] |
| PBT-01 | Idempotência | TASK-03 | [X] |
| PBT-02 | Conservação de saldo | TASK-03 | [X] |
| PBT-03 | Máquina de estados | TASK-02 | [X] |
| PBT-04 | Estorno limitado | TASK-07 | [ ] |
| DD-001 | Tabela de idempotência | TASK-03, TASK-05 | [ ] |
| DD-002 | Evento via outbox | TASK-05 | [ ] |
| DD-003 | Estorno como lançamento de crédito | TASK-07, TASK-08 | [ ] |
| ADR-0001 | Stack e Clean Architecture | TASK-01 | [X] |
| ADR-0002 | Outbox | TASK-05, TASK-08 | [ ] |

## 6. Coverage Gates

| Camada | Gate |
|--------|------|
| Domain | 95% |
| Application | 90% |
| Infrastructure | 70% |
| Api | 80% |

## 7. Critérios de Encerramento

TASK: subtasks concluídas, testes verdes, gate atendido, commit e push. Onda: TASKs `[X]`, CI verde, PR da onda aberto. Módulo: matriz completa e artefatos consistentes.

## 8. Riscos de Execução

- Concorrência de débito na carteira sob 200 req/s (mitigação: lock otimista por carteira).
- Estorno de cancelamento concorrente com nova compra/extensão sobre a mesma carteira (mitigação: mesmo lock otimista de TASK-03/TASK-05, aplicado também em TASK-08).

## 9. Referências

- docs/product/modules/rotativo/requirements.md
- docs/product/modules/rotativo/design.md
