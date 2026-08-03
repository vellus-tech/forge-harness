# Tasks — tasks-meta-required

> Tasks do change `tasks-meta-required`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task é atômica (1 commit), rastreável a um REQ/seção do design, e declara o que toca.

## Wave 1 — Red observado

- [X] TASK-01 — `w130[16]` reproduz o plano sem metadados atravessando TSK-01/02/03, com os quatro controles (rastreia: bugfix.md §1; paths: `tests/w130-tasks-graph-gate.sh`; depende: —)

## Wave 2 — Correção

- [X] TASK-02 — `hasMeta` no parser distingue campo ausente de campo vazio (rastreia: bugfix.md §2; paths: `template/.forge/scripts/lib/tasks-graph.mjs`; depende: TASK-01)
- [X] TASK-03 — `TSK-06` bloqueia omissão sistemática e avisa omissão pontual (rastreia: bugfix.md §2; paths: `template/.forge/scripts/lib/tasks-graph.mjs`; depende: TASK-02)
- [X] TASK-04 — Documenta o `TSK-06` no comando de tasks e regenera o plugin (rastreia: bugfix.md §2; paths: `template/.forge/commands/specs/tasks.md`, `plugin/forge/commands/tasks.md`; depende: TASK-03)

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| bugfix.md §1 (comportamento incorreto) | TASK-01 |
| bugfix.md §2 (comportamento esperado) | TASK-02, TASK-03, TASK-04 |
| bugfix.md §3 (não regride) | TASK-01 (controles c, d, e), TASK-03 |
