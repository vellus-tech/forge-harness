# Tasks — surface-literal-endpoint

## Wave 1 — Medição

- [X] TASK-01 — Medir o repositório de referência com o scanner corrigido e registrar no `LDG-0010` (rastreia: REQ-02; paths: `.forge/ledger/`; depende: —)

## Wave 2 — Insumo

- [X] TASK-02 — `w130[17]` em vermelho e `checkSurfaceChecklistLiteral` fiado no `validate-spec` (rastreia: REQ-01; paths: `tests/w130-tasks-graph-gate.sh`, `template/.forge/scripts/lib/tasks-graph.mjs`, `template/.forge/scripts/lib/validate-spec.mjs`; depende: TASK-01)
- [X] TASK-03 — Documentar o `SRF-03` no comando de tasks e regenerar o plugin (rastreia: REQ-02; paths: `template/.forge/commands/specs/tasks.md`, `plugin/forge/commands/tasks.md`; depende: TASK-02)

## Rastreabilidade

| REQ | Tasks |
|---|---|
| REQ-01 | TASK-02 |
| REQ-02 | TASK-01, TASK-03 |
