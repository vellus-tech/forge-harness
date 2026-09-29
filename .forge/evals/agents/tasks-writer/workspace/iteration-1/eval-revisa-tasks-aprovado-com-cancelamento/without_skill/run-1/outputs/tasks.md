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
| 1.1.0 | 2026-09-26 | Aprovado para desenvolvimento | Cobertura do cancelamento com estorno proporcional (Req 4, PBT-04, DD-003, migration V2, `DELETE /v1/ativacoes/{id}`): novas TASK-07 e TASK-08, subtask de endpoint adicionada à TASK-06. Onda 1 e Onda 2 (concluídas) e as TASKs em andamento na Onda 3 (TASK-03, TASK-04) não foram alteradas. |

## 1. Convenções de Implementação

TDD-first (Red → Green → Refactor), PBT com FsCheck, subtasks abaixo de 2 horas, branch `<tipo>/rotativo/<NN>-<slug>`, Conventional Commits, status `[ ]` `[-]` `[X]` `[!]`, IDs `TASK-NN` com subtasks `ST-MM`.

## 2. Status Geral

| TASK | Título | Onda | Branch | Status |
|------|--------|------|--------|--------|
| TASK-01 | Solution Clean Architecture e teste de arquitetura | Onda 1 | `feat/rotativo/01-bootstrap` | [X] |
| TASK-02 | Aggregate Ativacao e value objects | Onda 2 | `feat/rotativo/02-aggregate-ativacao` | [X] |
| TASK-03 | Comprar ativação com idempotência | Onda 3 | `feat/rotativo/03-comprar-ativacao` | [-] |
| TASK-04 | Estender ativação | Onda 3 | `feat/rotativo/04-estender-ativacao` | [ ] |
| TASK-07 | Cancelar ativação com estorno proporcional | Onda 3 | `feat/rotativo/07-cancelar-ativacao` | [ ] |
| TASK-05 | Persistência, migration V1 e outbox | Onda 4 | `feat/rotativo/05-persistencia-outbox` | [ ] |
| TASK-08 | Persistência do cancelamento, migration V2 | Onda 4 | `feat/rotativo/08-persistencia-cancelamento` | [ ] |
| TASK-06 | API, consulta por placa, cancelamento e observabilidade | Onda 5 | `feat/rotativo/06-api-consulta` | [ ] |

## 3. Ondas de Implementação

| Onda | Foco | TASKs |
|------|------|-------|
| Onda 1 | Bootstrap | TASK-01 |
| Onda 2 | Domain | TASK-02 |
| Onda 3 | Application | TASK-03, TASK-04, TASK-07 |
| Onda 4 | Infrastructure | TASK-05, TASK-08 |
| Onda 5 | API + Hardening | TASK-06 |

> Nota (v1.1.0): TASK-07 foi acrescentada à Onda 3 como item novo, sem reordenar ou modificar TASK-03 (em andamento) nem TASK-04. TASK-08 foi acrescentada à Onda 4 após TASK-05, da qual depende. TASK-06 teve escopo estendido (subtask nova) e ganhou uma dependência adicional (TASK-08); ela ainda não foi iniciada, então a extensão não interrompe trabalho em curso.

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

### TASK-07 — Cancelar ativação com estorno proporcional *(novo — v1.1.0)*

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 3 — Application |
| **Branch** | `feat/rotativo/07-cancelar-ativacao` |
| **Status** | [ ] |
| **Depende de** | TASK-03 (reaproveita o padrão de lançamento na carteira usado no débito) |
| **Mapeia** | Req 4, PBT-04, DD-003 |
| **Camada principal** | Application |

#### Subtasks

- [ ] **ST-01 — Red:** PBT-04 (`0 ≤ estorno ≤ valor_total_pago` e `valor_debitado_liquido + estorno = valor_total_pago`) e teste de rejeição ROT-003 ao cancelar ativação não vigente (Req 4.2).
- [ ] **ST-02 — Green:** handler `CancelarAtivacaoCommand` — calcula `floor(minutos_restantes) × tarifa_por_minuto` (Req 4.1), usa a transição de estado `Ativa → Cancelada` já suportada pelo aggregate (PBT-03, TASK-02), gera o lançamento de crédito (DD-003) e o evento de domínio `AtivacaoCancelada` (Req 4.3).
- [ ] **ST-03 — Refactor:** extrair cálculo de minutos restantes para reuso com a política de tempo máximo da zona (mesma extração da TASK-02/TASK-03).
- [ ] **ST-04 — Encerramento:** testes verdes, commit e push.

> Nota: esta TASK só grava o lançamento de crédito e o evento via as mesmas abstrações de repositório/outbox já usadas por TASK-03; a tabela `carteira_lancamentos` e a `V2__cancelamento.sql` propriamente ditas são entregues em TASK-08, da qual TASK-07 não depende para ser implementada com um repositório em memória/fake nos testes de unidade — a integração ponta a ponta fecha quando TASK-08 concluir.

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

### TASK-08 — Persistência do cancelamento, migration V2 *(novo — v1.1.0)*

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 4 — Infrastructure |
| **Branch** | `feat/rotativo/08-persistencia-cancelamento` |
| **Status** | [ ] |
| **Depende de** | TASK-05 (schema base de `ativacoes`/`outbox`), TASK-07 (contrato do lançamento de crédito) |
| **Mapeia** | Req 4, DD-003 |
| **Camada principal** | Infrastructure |

#### Subtasks

- [ ] **ST-01 — Red:** teste de integração (Testcontainers) gravando o lançamento em `carteira_lancamentos`, a coluna `cancelada_em` em `ativacoes` e o evento `AtivacaoCancelada` no outbox, todos na mesma transação (DD-003).
- [ ] **ST-02 — Green:** migration `V2__cancelamento.sql` (coluna `cancelada_em` em `ativacoes`, tabela `carteira_lancamentos`) e repositório de cancelamento.
- [ ] **ST-03 — Encerramento:** testes verdes, commit e push.

### TASK-06 — API, consulta por placa, cancelamento e observabilidade *(escopo estendido — v1.1.0)*

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 5 — API + Hardening |
| **Branch** | `feat/rotativo/06-api-consulta` |
| **Status** | [ ] |
| **Depende de** | TASK-04, TASK-05, TASK-08 |
| **Mapeia** | Req 3, Req 4, RNF 1, RNF 2 |
| **Camada principal** | Api |

#### Subtasks

- [ ] **ST-01 — Red:** testes de contrato dos 3 endpoints originais (`POST /v1/ativacoes`, `POST /v1/ativacoes/{id}/extensoes`, `GET /v1/ativacoes?placa=`) e teste de log sem placa completa.
- [ ] **ST-02 — Green:** endpoints, escopos OAuth e métricas.
- [ ] **ST-03 — Red *(novo — v1.1.0)*:** teste de contrato de `DELETE /v1/ativacoes/{id}` (escopo `motorista:write`, 200 com estorno no corpo, 409/ROT-003 para ativação não vigente).
- [ ] **ST-04 — Green *(novo — v1.1.0)*:** endpoint `DELETE /v1/ativacoes/{id}` chamando `CancelarAtivacaoCommand` (TASK-07).
- [ ] **ST-05 — Encerramento:** testes verdes, commit e push.

## 5. Matriz de Rastreabilidade

| Origem | Descrição | TASKs | Status |
|--------|-----------|-------|--------|
| Req 1 | Comprar ativação | TASK-02, TASK-03 | [-] |
| Req 2 | Estender ativação | TASK-02, TASK-04 | [ ] |
| Req 3 | Consultar por placa | TASK-06 | [ ] |
| Req 4 | Cancelar ativação com estorno proporcional | TASK-07, TASK-08, TASK-06 | [ ] |
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
| ADR-0002 | Outbox | TASK-05 | [ ] |

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
- Concorrência entre extensão (TASK-04) e cancelamento (TASK-07) sobre a mesma ativação (mitigação: mesmo lock otimista por ativação/carteira usado no débito, verificando o estado `Ativa` antes de aplicar a transição).

## 9. Referências

- docs/product/modules/rotativo/requirements.md
- docs/product/modules/rotativo/design.md
