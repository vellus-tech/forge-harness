# Requirements — create-forge-project-harness

> Requisitos macro do change, derivados do documento de projeto (`docs/refer/forge-project-harness.md`) e detalhados nos planos por MVP (`docs/plans/0N-*.md`, todos "Aprovado para desenvolvimento" — gate `requirements_reviewed: true`). Cada REQ corresponde ao Definition of Done de um MVP.

## REQ-01 — MVP1: Forge canônico + adapter Claude (CONCLUÍDO)

- **Quando** o instalador roda num projeto, **o sistema deve** instalar `.forge/` canônico, gerar `AGENTS.md` + adapters selecionados (default `claude`) com lockfiles, e passar o contrato `claude-contract.bats` + `doctor` exit 0.
- **Critérios de aceite:** DoD do `docs/plans/01-mvp1-forge-canonico.md` ✓ (gates w12/w13/w14 verdes; saneamento W1.5 aplicado).

## REQ-02 — MVP2: Spec lifecycle change-based

- **Quando** o usuário cria um change, **o sistema deve** gerar `.forge/specs/active/<id>/` válido por schema (manifest §10.2, scale-adaptive §10.3) e conduzir requirements→design→tasks→implement→verify com loops builder→validator e gates HITL, encerrando em `verified` ou `close`.
- **Critérios de aceite:** DoD do `docs/plans/02-mvp2-spec-lifecycle.md`.

## REQ-03 — MVP3: Baseline + archive

- **Critérios de aceite:** DoD do `docs/plans/03-mvp3-baseline-archive.md` (delta apply com substituição integral, archive E2E §8.1).

## REQ-04 — MVP4: Brownfield graph

- **Critérios de aceite:** DoD do `docs/plans/04-mvp4-brownfield-graph.md`.

## REQ-05 — MVP5: Dev loop & quality

- **Critérios de aceite:** DoD do `docs/plans/05-mvp5-devloop-quality.md`.

## REQ-06 — Fase 8: Qualidade, pilotos e rollout v0.1.0

- **Critérios de aceite:** DoD do `docs/plans/06-qualidade-piloto-rollout.md` (pilotos greenfield/brownfield reais; tag `v0.1.0`; delegação do `/init-project`).

## Requisitos não funcionais do change

- **NFR-01 —** Scripts do template zero-dependency (bash + Node ≥ 20 `.mjs`); ajv/yaml apenas como dev-deps do workspace.
- **NFR-02 —** Gates determinísticos com saída de uma linha `OK`/`FAIL (...)` e exit codes honestos (sem pipe mascarando).
- **NFR-03 —** Idempotência: sync/install/spec-new re-executáveis sem efeito colateral (guard + backup/rollback).
