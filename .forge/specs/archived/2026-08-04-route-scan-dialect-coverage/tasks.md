# Tasks — route-scan-dialect-coverage

## Wave 1 — Falso positivo que bloqueia

- [X] TASK-01 — `w132[53]`/`[54]` em vermelho: tabela alheia na superfície declarada, caixa do `[controller]` (rastreia: REQ-01, REQ-02; paths: `tests/w132-route-surface-gate.sh`; depende: —)
- [X] TASK-02 — Âncora com degrade anunciado e case-fold no indexador .NET (rastreia: REQ-01, REQ-02; paths: `template/.forge/scripts/lib/api-surface.mjs`, `template/.forge/scripts/lib/route-scan.mjs`; depende: TASK-01)

## Wave 2 — Dialetos ausentes

- [X] TASK-03 — `w132[55]`/`[56]`: `.py`/`.go` lidos e ignorados, Nest multi-controller (rastreia: REQ-03, REQ-04; paths: `tests/w132-route-surface-gate.sh`; depende: —)
- [X] TASK-04 — `indexPython` (FastAPI, Flask) e `indexGo` (chi/gorilla/net-http) (rastreia: REQ-03; paths: `template/.forge/scripts/lib/route-scan.mjs`; depende: TASK-03)

## Rastreabilidade

| REQ | Tasks |
|---|---|
| REQ-01 | TASK-01, TASK-02 |
| REQ-02 | TASK-01, TASK-02 |
| REQ-03 | TASK-03, TASK-04 |
| REQ-04 | TASK-03 (comportamento já existente, travado por teste) |
