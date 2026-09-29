# Tasks — bloqueio-cartao-perda-roubo

## Wave 1 — Bloqueio

- [ ] TASK-01 — Endpoint de bloqueio com step-up (rastreia: REQ-01; paths: `src/cartoes/api/`; depende: —)
- [ ] TASK-02 — Outbox de `CartaoBloqueado` (rastreia: REQ-01; paths: `src/cartoes/outbox/`; depende: TASK-01)

## Wave 2 — Hotlist e saldo

- [ ] TASK-03 — Gerador incremental de hotlist assinada (rastreia: REQ-02; paths: `src/hotlist/`; depende: TASK-02)
- [ ] TASK-04 — Transferência de saldo pós-janela de 72 h (rastreia: REQ-03; paths: `src/cartoes/segunda-via/`; depende: TASK-02)
