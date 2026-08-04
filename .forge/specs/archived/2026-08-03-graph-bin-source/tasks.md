# Tasks — graph-bin-source

> Tasks do change `graph-bin-source`, ordenadas por dependência. Formato de ID: `TASK-NN`.
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada.

## Wave 1 — Red observado

- [X] TASK-01 — `w41[10]` reproduz o entrypoint Node fora do grafo, com os controles de `bin/Debug`, `dist/` e `obj/` (rastreia: bugfix.md §1; paths: `tests/w41-graph-gate.sh`; depende: —)

## Wave 2 — Correção

- [X] TASK-02 — `bin` sai de `SKIP_DIRS` e entra `SKIP_UNDER_BIN`, contextual ao diretório pai (rastreia: bugfix.md §2; paths: `template/.forge/scripts/lib/graph-build.mjs`; depende: TASK-01)

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| bugfix.md §1 (comportamento incorreto) | TASK-01 |
| bugfix.md §2 (comportamento esperado) | TASK-02 |
| bugfix.md §3 (não regride) | TASK-01 (controles), TASK-02 |
