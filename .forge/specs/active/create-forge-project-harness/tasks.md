# Tasks — create-forge-project-harness

> Tasks do change, espelhando as waves dos planos (`docs/plans/`). Formato `TASK-NN`; status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada.
> Este arquivo é o tracking oficial do dogfooding a partir da W2.0; `waves.json`/`progress.json` assumem na W5.1.

## Wave 0 — Fundação (Fase 0)

- [X] TASK-01 — W0.1 git init + estrutura do workspace
- [X] TASK-02 — W0.2 snapshot congelado + MANIFEST.sha256 + path-inventory
- [X] TASK-03 — W0.3 contrato Claude (claude-adapter-contract.md + bats)

## Wave 1 — MVP1: Forge canônico (Fases 1–3)

- [X] TASK-04 — W1.0 esqueleto canônico .forge + schemas (ajv)
- [X] TASK-05 — W1.1 migração dos 87 arquivos + rewrite de paths
- [X] TASK-06 — W1.2 sync-adapters + adapter claude + lockfiles
- [X] TASK-07 — W1.3 installer determinista + doctor + git infra
- [X] TASK-08 — W1.4 adapters multi-agente + loss_warnings + smoke
- [X] TASK-09 — W1.4b seleção de adapters (ativo vs disponível, reconcile/prune)
- [X] TASK-10 — W1.5 saneamento universal de agents/skills (revisão aplicada)

## Wave 2 — MVP2: Spec lifecycle (Fase 4)

- [X] TASK-11 — W2.0 spec-manifest.schema + templates spec/bugfix/refactor + /forge:spec new + validate-spec mínimo + dogfooding
- [X] TASK-12 — W2.1 pipeline SDD com loops builder→validator + gates HITL (depende: TASK-11)
- [X] TASK-13 — W2.2 implement + verify + close + state machine mínima + gate-runner v0 (depende: TASK-12)
- [X] TASK-14 — W2.3 /forge:discover lite → graph/manifest.json (depende: TASK-11)

## Wave 3 — MVP3: Baseline + archive (Fase 5)

- [X] TASK-15 — W3.0 schemas delta/baseline/traceability/state-machine + product/current (depende: TASK-13)
- [X] TASK-16 — W3.1 validadores §19.1–19.4 completos (depende: TASK-15)
- [X] TASK-17 — W3.2 archive E2E (pré-flight → dry-run → apply → move → index) (depende: TASK-16)
- [X] TASK-18 — W3.3 publish-docs + adr new + constitution + backlog (depende: TASK-15)

## Wave 4 — MVP4: Brownfield graph (Fase 6)

- [ ] TASK-19 — W4.0 spike Graphify vs subset local → ADR (depende: TASK-13)
- [ ] TASK-20 — W4.1 graph build + validate + update incremental (depende: TASK-19)
- [ ] TASK-21 — W4.2 graph query + impact + onboard (depende: TASK-20)
- [ ] TASK-22 — W4.3 c4 + overview.html + skill c4-render (depende: TASK-20)

## Wave 5 — MVP5: Dev loop & quality (Fase 7)

- [ ] TASK-23 — W5.0 shard + STORY.md + contexto de épico (depende: TASK-13)
- [ ] TASK-24 — W5.1 waves/progress/deferrals + comandos de sessão longa (depende: TASK-23)
- [ ] TASK-25 — W5.2 runners.yaml + agents quality + skill eval A/B (depende: TASK-24)
- [ ] TASK-26 — W5.3 meta-avaliação §18 (caso real: /forge:requirements) (depende: TASK-25)

## Wave 8 — Qualidade, pilotos e rollout (Fase 8)

- [ ] TASK-27 — W8.0 fixtures finais + run-all.sh (depende: TASK-26)
- [ ] TASK-28 — W8.1 piloto greenfield real até archive (depende: TASK-17, TASK-27)
- [ ] TASK-29 — W8.2 piloto brownfield real (depende: TASK-21, TASK-27)
- [ ] TASK-30 — W8.3 tag v0.1.0 + delegação /init-project + política de sync (depende: TASK-28, TASK-29)

## Rastreabilidade

| REQ | Tasks |
|---|---|
| REQ-01 | TASK-01..TASK-10 |
| REQ-02 | TASK-11..TASK-14 |
| REQ-03 | TASK-15..TASK-18 |
| REQ-04 | TASK-19..TASK-22 |
| REQ-05 | TASK-23..TASK-26 |
| REQ-06 | TASK-27..TASK-30 |

## Pendências fora de wave

- Teste manual C10 no Claude Code real: **em andamento no piloto azim-crm** (status/doctor/commands ✓ em 2026-06-10; falta exercitar agents, skills e o bloqueio do worktree-guard).
- Decisão sobre rules/context.md acopladas ao projeto de referência (descoberta W1.5 — ver `docs/plans/revisao-agents-skills.md` §Descobertas).
