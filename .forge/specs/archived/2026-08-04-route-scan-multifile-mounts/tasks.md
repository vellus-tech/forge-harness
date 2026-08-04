# Tasks — route-scan-multifile-mounts

## Wave 1 — Express multi-arquivo

- [X] TASK-01 — Casos `w132[46]`–`[48]` em vermelho: layout canônico, router órfão, montagem dupla (rastreia: REQ-01, REQ-02; paths: `tests/w132-route-surface-gate.sh`; depende: —)
- [X] TASK-02 — Índice global de mounts, pendências resolvidas na passa 2, router por atribuição, prefixos acumulados (rastreia: REQ-01, REQ-02, REQ-03; paths: `template/.forge/scripts/lib/route-scan.mjs`; depende: TASK-01)

## Wave 2 — Vertical slice .NET

- [X] TASK-03 — Casos `w132[49]`–`[50]`: ambiguidade real reportada, ambiguidade aparente resolvida (rastreia: REQ-04; paths: `tests/w132-route-surface-gate.sh`; depende: —)
- [X] TASK-04 — `csScope` por arquivo, `ns` no produtor, candidatas filtradas por visibilidade, ambiguidade por chamada (rastreia: REQ-04; paths: `template/.forge/scripts/lib/route-scan.mjs`; depende: TASK-03)

## Wave 3 — Silêncio

- [X] TASK-05 — Casos `w132[51]`–`[52]`: receptor opaco reportado, cliente HTTP sem ruído (rastreia: REQ-05; paths: `tests/w132-route-surface-gate.sh`; depende: TASK-02)
- [X] TASK-06 — `require(...).Router()` reconhecido e `route-receiver-unknown` ancorado no uso do framework (rastreia: REQ-05; paths: `template/.forge/scripts/lib/route-scan.mjs`; depende: TASK-05)

## Rastreabilidade

| REQ | Tasks |
|---|---|
| REQ-01 | TASK-01, TASK-02 |
| REQ-02 | TASK-01, TASK-02 |
| REQ-03 | TASK-02, TASK-06 |
| REQ-04 | TASK-03, TASK-04 |
| REQ-05 | TASK-05, TASK-06 |
