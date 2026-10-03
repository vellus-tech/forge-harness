# Tasks — CRT — Carteira

- Versão: 1.0.0
- Data: 2026-09-10
- Status: Aprovado para desenvolvimento
- Base: requirements.md v1.2.0, design.md v0.4.0
- ADRs aplicáveis: ADR-0001, ADR-0002, ADR-0003
- Rules aplicáveis: `.forge/rules/testing/`, `.forge/rules/conventions/`

## Histórico de Versões

| Versão | Data | Autor | Mudança |
|---|---|---|---|
| 1.0.0 | 2026-09-10 | tasks-writer | Versão inicial aprovada |

## Convenções de Implementação

- TDD-first: toda TASK com lógica segue Red → Green → Refactor.
- Branch por TASK no padrão `<tipo>/carteira/<NN>-<slug>`; commits em Conventional Commits.

## Status Geral

| TASK | Título | Onda | Branch | Status |
|---|---|---|---|---|
| TASK-01 | Bootstrap da solução e testes de arquitetura | Onda 1 | `chore/carteira/01-bootstrap` | [ ] |
| TASK-02 | Value Object Saldo e PBT de saldo não negativo | Onda 2 | `feat/carteira/02-saldo` | [ ] |
| TASK-03 | Débito de embarque | Onda 2 | `feat/carteira/03-debito-embarque` | [ ] |
| TASK-04 | Crédito de recarga via webhook Pix | Onda 3 | `feat/carteira/04-credito-recarga` | [ ] |
| TASK-05 | Persistência e migration 0001_carteira | Onda 3 | `feat/carteira/05-persistencia` | [ ] |

## Ondas de Implementação

| Onda | Foco | Critério de fechamento |
|---|---|---|
| Onda 1 | Bootstrap | Solução compila, testes de arquitetura verdes no CI |
| Onda 2 | Domain | Testes de domínio e PBT-01 verdes, cobertura Domain ≥ 95% |
| Onda 3 | Application + Infrastructure + Api | Testes de integração e contrato verdes, PR da onda aprovado |

## Tarefas

### TASK-01 - Bootstrap da solução e testes de arquitetura

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 1 - Bootstrap |
| **Branch** | `chore/carteira/01-bootstrap` |
| **Worktree** | `git worktree add ../worktrees/carteira/01-bootstrap -b chore/carteira/01-bootstrap` |
| **Status** | [ ] |
| **Depende de** | Não aplicável |
| **Entregável** | Solução CRT com 4 projetos e testes NetArchTest do ADR-0001 |
| **Mapeia** | ADR-0001 |
| **Camada principal** | DevOps |

- [ ] 1.1 Red: escrever testes NetArchTest (Domain não referencia EF Core/Npgsql/Kafka)
- [ ] 1.2 Green: criar CRT.Domain, CRT.Application, CRT.Infrastructure, CRT.Api
- [ ] 1.3 Refactor: ajustar Directory.Build.props

**Critérios de aceite:** testes de arquitetura verdes; `dotnet build` sem warnings novos; branch enviada; commit `chore(carteira): bootstrap`.

### TASK-02 - Value Object Saldo e PBT de saldo não negativo

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 2 - Domain |
| **Branch** | `feat/carteira/02-saldo` |
| **Worktree** | `git worktree add ../worktrees/carteira/02-saldo -b feat/carteira/02-saldo` |
| **Status** | [ ] |
| **Depende de** | TASK-01 |
| **Entregável** | `Saldo` (long centavos) com operações Creditar/Debitar e PBT-01 |
| **Mapeia** | Req 3, PBT-01, DD-001, ADR-0002 |
| **Camada principal** | Domain |

- [ ] 2.1 Red: PBT-01 com FsCheck — sequências aleatórias de créditos/débitos nunca produzem saldo negativo
- [ ] 2.2 Green: implementar `Saldo` com `SaldoInsuficienteException`
- [ ] 2.3 Refactor: extrair guardas

**Critérios de aceite:** PBT-01 verde com 1.000 casos gerados; cobertura Domain ≥ 95%; branch enviada; commit `feat(carteira): value object saldo`.

### TASK-03 - Débito de embarque

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 2 - Domain |
| **Branch** | `feat/carteira/03-debito-embarque` |
| **Worktree** | `git worktree add ../worktrees/carteira/03-debito-embarque -b feat/carteira/03-debito-embarque` |
| **Status** | [ ] |
| **Depende de** | TASK-02 |
| **Entregável** | Método `Carteira.DebitarEmbarque(tarifa)` com erro CRT-002 |
| **Mapeia** | Req 3, DD-001 |
| **Camada principal** | Domain |

- [ ] 3.1 Implementar `Carteira.DebitarEmbarque` e o mapeamento para `CRT-002 SaldoInsuficiente`
- [ ] 3.2 Escrever testes unitários de débito com saldo suficiente e insuficiente
- [ ] 3.3 Refactor

**Critérios de aceite:** testes de débito verdes; cobertura Domain ≥ 95%; branch enviada; commit `feat(carteira): debito de embarque`.

### TASK-04 - Crédito de recarga via webhook Pix

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 3 - Application + Infrastructure + Api |
| **Branch** | `feat/carteira/04-credito-recarga` |
| **Worktree** | `git worktree add ../worktrees/carteira/04-credito-recarga -b feat/carteira/04-credito-recarga` |
| **Status** | [ ] |
| **Depende de** | TASK-05 |
| **Entregável** | Handler `CreditarRecargaHandler` + `POST /v1/webhooks/pix` + evento `RecargaCreditada` |
| **Mapeia** | Req 1, DD-002 |
| **Camada principal** | Application |

- [ ] 4.1 Red: teste do handler — webhook confirmado credita o valor e grava outbox `RecargaCreditada`
- [ ] 4.2 Green: implementar handler e endpoint
- [ ] 4.3 Red: teste de contrato do `POST /v1/webhooks/pix`
- [ ] 4.4 Green: ajustar contrato OpenAPI

**Critérios de aceite:** testes de aplicação e contrato verdes; cobertura Application ≥ 90%; branch enviada; commit `feat(carteira): credito de recarga`.

### TASK-05 - Persistência e migration 0001_carteira

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 3 - Application + Infrastructure + Api |
| **Branch** | `feat/carteira/05-persistencia` |
| **Worktree** | `git worktree add ../worktrees/carteira/05-persistencia -b feat/carteira/05-persistencia` |
| **Status** | [ ] |
| **Depende de** | TASK-04 |
| **Entregável** | Migration `0001_carteira`, `CarteiraRepository` e tabela `recarga_processada` |
| **Mapeia** | DD-002, Req 1 |
| **Camada principal** | Infrastructure |

- [ ] 5.1 Red: teste de integração com Testcontainers (PostgreSQL) do repositório
- [ ] 5.2 Green: migration e repositório
- [ ] 5.3 Refactor

**Critérios de aceite:** testes de integração verdes; cobertura Infrastructure ≥ 70%; commit `feat(carteira): persistencia` e push direto em `main` para liberar o time de app.

### TASK-06 - Consulta de saldo

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 3 - Application + Infrastructure + Api |
| **Branch** | `feat/carteira/06-consulta-saldo` |
| **Worktree** | `git worktree add ../worktrees/carteira/06-consulta-saldo -b feat/carteira/06-consulta-saldo` |
| **Status** | [ ] |
| **Depende de** | TASK-05 |
| **Entregável** | `GET /v1/carteiras/{id}/saldo` com autorização CRT-003 |
| **Mapeia** | Req 2, RNF 1 |
| **Camada principal** | Api |

- [ ] 6.1 Red: teste de contrato e de autorização (passageiro lendo carteira alheia recebe 403 CRT-003)
- [ ] 6.2 Green: implementar query e endpoint
- [ ] 6.3 Red: teste de carga k6 (p95 < 300 ms a 200 req/s)
- [ ] 6.4 Green: índice/cache conforme necessário

**Critérios de aceite:** testes de contrato e autorização verdes; k6 com p95 < 300 ms; cobertura Api ≥ 80%; branch enviada; commit `feat(carteira): consulta de saldo`.

## Matriz de Rastreabilidade

| Origem | TASKs |
|---|---|
| Req 1 | TASK-04, TASK-05 |
| Req 2 | TASK-06 |
| Req 3 | TASK-02, TASK-03 |
| RNF 1 | TASK-06 |
| PBT-01 | TASK-02 |
| DD-001 | TASK-02, TASK-03 |
| DD-002 | TASK-04, TASK-05 |
| ADR-0001 | TASK-01 |

## Coverage Gates

| Camada | Gate |
|---|---|
| Domain | 95%+ |
| Application | 90%+ |
| Infrastructure | 70%+ |
| Api | 80%+ |
| Architecture | 100% das regras críticas |

## Critérios de Encerramento

- **TASK:** subtasks concluídas, testes verdes, coverage gate atendido, commit em Conventional Commits e branch enviada.
- **Onda:** critério de fechamento da onda atendido, CI verde, PR da onda aprovado e mergeado em `develop`.
- **Módulo:** todas as ondas fechadas, matriz completa, README sincronizado.

## Riscos de Execução

- Webhook do PSP pode reenviar a mesma confirmação; mitigado pela idempotência por `txid` (DD-002).

## Referências

- requirements.md v1.2.0, design.md v0.4.0, ADR-0001, ADR-0002, ADR-0003.
