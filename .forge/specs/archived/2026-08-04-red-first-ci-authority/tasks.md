# Tasks — red-first-ci-authority

> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada.

## Wave 1 — Comando

- [X] TASK-01 — Gate `w109` cobre a varredura, os dois controles de escopo e a paridade dos instaladores (rastreia: REQ-01, REQ-03; paths: `tests/w109-red-ci-gate.sh`; depende: —)
- [X] TASK-02 — Subcomando `ci` no `red-evidence.sh`, sem aceitar change-id (rastreia: REQ-01; paths: `template/.forge/scripts/red-evidence.sh`; depende: TASK-01)

## Wave 2 — Fiação

- [X] TASK-03 — Step no `ci.yml` deste repositório, depois do `npm ci` (rastreia: REQ-02; paths: `.github/workflows/ci.yml`; depende: TASK-02)
- [X] TASK-04 — Workflow `red-first.yml` no template, com `fetch-depth: 0` e instalação de dependências (rastreia: REQ-03; paths: `template/github/workflows/red-first.yml`; depende: TASK-02)
- [X] TASK-05 — Materialização em paridade nos dois instaladores (rastreia: REQ-03; paths: `installer/install.sh`, `bin/forge.mjs`; depende: TASK-04)

## Wave 3 — Norma

- [X] TASK-06 — Rule declara o CI como execução de referência e enumera o que permanece aberto (rastreia: REQ-04; paths: `template/.forge/rules/testing/regression-red-first.md`; depende: TASK-03)
- [X] TASK-07 — Comando documenta o subcomando `ci`; plugin regenerado (rastreia: REQ-04; paths: `template/.forge/commands/testing/red.md`, `plugin/forge/commands/red.md`; depende: TASK-06)

## Rastreabilidade

| REQ | Tasks |
|---|---|
| REQ-01 | TASK-01, TASK-02 |
| REQ-02 | TASK-03 |
| REQ-03 | TASK-01, TASK-04, TASK-05 |
| REQ-04 | TASK-06, TASK-07 |

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície | Coberto por task |
|---|---|---|---|
| REQ-01 | subcomando `ci` (sem argumentos) | CLI `red-evidence.sh` | TASK-02 |
| REQ-02 | — | GitHub Actions (`ci.yml`) | TASK-03 |
| REQ-03 | — | GitHub Actions (`red-first.yml` materializado no init/update) | TASK-04, TASK-05 |
| REQ-04 | — | documentação (rule + comando) | TASK-06, TASK-07 |
