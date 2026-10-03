# Tasks — RCG — Recarga

- Versão: 0.1.0
- Data: 2026-09-22
- Status: Rascunho para revisão
- Base: requirements.md v1.0.0
- ADRs aplicáveis: ADR-0001, ADR-0002, ADR-0003
- Rules aplicáveis: `.forge/rules/testing/`

## Histórico de Versões

| Versão | Data | Autor | Mudança |
|---|---|---|---|
| 0.1.0 | 2026-09-22 | tasks-writer | Versão inicial derivada do requirements (design ainda não disponível) |

## Convenções de Implementação

- TDD-first; branch por TASK `<tipo>/recarga/<NN>-<slug>`; Conventional Commits.

## Status Geral

| TASK | Título | Onda | Branch | Status |
|---|---|---|---|---|
| TASK-01 | Bootstrap RCG | Onda 1 | `chore/recarga/01-bootstrap` | [ ] |
| TASK-02 | Cobrança Pix de recarga | Onda 2 | `feat/recarga/02-cobranca-pix` | [ ] |
| TASK-03 | Expiração e estorno | Onda 2 | `feat/recarga/03-expiracao` | [ ] |

## Ondas de Implementação

| Onda | Foco | Critério de fechamento |
|---|---|---|
| Onda 1 | Bootstrap | Solução compila e testes de arquitetura verdes |
| Onda 2 | Domain + Api | Testes de domínio, PBT-01 e contrato verdes |

## Tarefas

### TASK-01 - Bootstrap RCG

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 1 - Bootstrap |
| **Branch** | `chore/recarga/01-bootstrap` |
| **Worktree** | `git worktree add ../worktrees/recarga/01-bootstrap -b chore/recarga/01-bootstrap` |
| **Status** | [ ] |
| **Depende de** | Não aplicável |
| **Entregável** | Solução RCG com testes de arquitetura (ADR-0001) |
| **Mapeia** | ADR-0001 |
| **Camada principal** | DevOps |

- [ ] 1.1 Red: testes NetArchTest
- [ ] 1.2 Green: projetos RCG.*

**Critérios de aceite:** testes de arquitetura verdes; branch enviada; commit `chore(recarga): bootstrap`.

### TASK-02 - Cobrança Pix de recarga

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 2 - Domain + Api |
| **Branch** | `feat/recarga/02-cobranca-pix` |
| **Worktree** | `git worktree add ../worktrees/recarga/02-cobranca-pix -b feat/recarga/02-cobranca-pix` |
| **Status** | [ ] |
| **Depende de** | TASK-01 |
| **Entregável** | `POST /v1/recargas` gerando cobrança Pix com `Idempotency-Key` |
| **Mapeia** | Req 1, RNF 1, PBT-01 |
| **Camada principal** | Api |

- [ ] 2.1 Red: PBT-01 — N requisições com a mesma chave geram uma cobrança
- [ ] 2.2 Green: implementar criação da cobrança
- [ ] 2.3 Red: teste de contrato do `POST /v1/recargas`
- [ ] 2.4 Green: endpoint

**Critérios de aceite:** PBT-01 e contrato verdes; cobertura Api ≥ 80%; branch enviada; commit `feat(recarga): cobranca pix`.

### TASK-03 - Expiração e estorno

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 2 - Domain + Api |
| **Branch** | `feat/recarga/03-expiracao` |
| **Worktree** | `git worktree add ../worktrees/recarga/03-expiracao -b feat/recarga/03-expiracao` |
| **Status** | [ ] |
| **Depende de** | TASK-02 |
| **Entregável** | Expiração em 30 minutos e estorno de pagamento tardio |
| **Mapeia** | Req 2 |
| **Camada principal** | Domain |

- [ ] 3.1 Red: teste de expiração e de estorno de pagamento após 30 minutos
- [ ] 3.2 Green: implementar expiração e estorno

**Critérios de aceite:** testes verdes; cobertura Domain ≥ 95%; branch enviada; commit `feat(recarga): expiracao e estorno`.

## Matriz de Rastreabilidade

| Origem | TASKs |
|---|---|
| Req 1 | TASK-02 |
| Req 2 | TASK-03 |
| RNF 1 | TASK-02 |
| PBT-01 | TASK-02 |

## Coverage Gates

| Camada | Gate |
|---|---|
| Domain | 95%+ |
| Api | 80%+ |
| Architecture | 100% das regras críticas |

## Critérios de Encerramento

- **TASK:** subtasks concluídas, testes verdes, gate atendido, branch enviada.
- **Onda:** CI verde, PR da onda mergeado em `develop`.
- **Módulo:** matriz completa, README sincronizado.

## Riscos de Execução

- PSP ainda não definido; contrato do Pix pode mudar.

## Referências

- requirements.md v1.0.0.
