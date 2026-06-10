---
title: Quality Gates e Níveis de Teste
applies_to:
  - all
priority: high
last_reviewed: 2026-05-08
---

# Quality Gates e Níveis de Teste

## Níveis Obrigatórios

| Nível | Escopo | Obrigatório para |
|-------|--------|-----------------|
| **Unit** | Domain + Application isolados | Todo código com lógica de negócio |
| **Integration** | Application + Infrastructure + DB real | Repositórios, handlers, eventos |
| **Contract** | Consumer/Provider via Pact | Toda integração frontend–backend |
| **E2E** | Fluxo completo via API real | Fluxos críticos de negócio |

Nenhuma feature sem testes. Nenhuma lógica financeira sem testes determinísticos.

## Ferramentas por Stack

| Stack | Unit/Integration | Mocks | PBT |
|-------|-----------------|-------|-----|
| .NET | xUnit 2.x + FluentAssertions | NSubstitute | FsCheck |
| React/TypeScript | Jest 30 + @testing-library/react | vi (built-in) | fast-check |
| Android/Kotlin | JUnit 5 + Kotest | MockK | Kotest Property |

## Coverage — Thresholds Mínimos por Camada

| Camada | Threshold Linha | Threshold Branch |
|--------|----------------|-----------------|
| Domain | 95% | 90% |
| Application | 85% | 80% |
| Infrastructure | 70% | — |
| Frontend (features/) | 80% | 75% |

Coverage de linhas é proxy — o objetivo é cobertura de **comportamentos**. Todo caminho de código com lógica de negócio deve ter teste correspondente.

## Property-Based Testing (PBT)

**Obrigatório** quando há propriedades matemáticas verificáveis:

- `Money.Add/Subtract/Split/CalculateFee` — toda operação monetária
- Arredondamento NBR 5891
- Operações sobre coleções com invariantes
- Geração de hashes (ledger chain)

Propriedades típicas: comutatividade, associatividade, idempotência, invariantes de soma.

Ver `tdd.md` para exemplos de FsCheck e fast-check.

## Testes de Dados Financeiros

- Dados de teste reproduzíveis (seed ou fixtures versionados)
- Valores monetários em centavos (inteiros) — nunca float/decimal
- Testar limites: zero, máximo de `long`, overflow

## Análise Estática

| Ferramenta | Stack | Gate |
|------------|-------|------|
| `dotnet format` + Roslyn analyzers | .NET | Bloqueante em CI |
| ESLint | TypeScript/React | Bloqueante em CI |
| commitlint | Todos | Bloqueante em hook |

## Testes de Acessibilidade

- `jest-axe` obrigatório em componentes de UI (unit)
- `@axe-core/playwright` em testes E2E

## Regressão Visual

- Playwright snapshots para componentes do design system
- Workflow `visual-regression.yml` ativado em PRs que tocam `apps/web/**` ou `packages/frontend/**`
- Falha se diff > 0.1%
- Snapshots gerados em CI com imagem Docker para diff determinístico de fonte

## Quality Gates em CI

| Gate | Trigger | Bloqueante |
|------|---------|-----------|
| Unit + Integration tests | Todo PR | Sim |
| Contract tests | PR com mudança de contrato | Sim |
| ESLint / dotnet format | Todo PR | Sim |
| Coverage thresholds | Todo PR | Sim |
| Visual regression | PR em `apps/web/**` ou `packages/frontend/**` | Sim |
| Trivy (CVE) | Todo build de imagem | Sim |
| OWASP ZAP DAST | Schedule semanal | Sim (bloqueia deploy) |

## Proibições Explícitas

- Feature mergeada sem testes correspondentes
- Lógica financeira sem testes determinísticos
- `// @ts-ignore` ou `#pragma warning disable` sem justificativa em comentário
- Testes sem asserção (test que passa sem verificar nada)
- Mock de banco em testes de integração (usar Testcontainers)
