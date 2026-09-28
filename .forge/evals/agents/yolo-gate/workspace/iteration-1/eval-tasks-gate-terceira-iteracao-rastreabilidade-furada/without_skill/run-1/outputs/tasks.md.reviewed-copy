# Tasks — conciliacao-tarifas-onibus

## Wave 1 — Importação

- [ ] TASK-01 — Importador idempotente de validações JSONL (rastreia: REQ-01, INV-02; paths: `services/conciliacao/Importacao/ValidacoesImporter.cs`; depende: —) — DoD: teste de reimportação sem duplicata + PBT-02 verde.
- [ ] TASK-02 — Importador do CSV de liquidação do adquirente (rastreia: REQ-02, INV-02; paths: `services/conciliacao/Importacao/LiquidacaoImporter.cs`; depende: —) — DoD: fixture de 3 arquivos reais anonimizados importa sem erro.

## Wave 2 — Conciliação

- [ ] TASK-03 — Motor de casamento por token + janela de 5 min (rastreia: REQ-03, INV-01; paths: `services/conciliacao/Motor/Casamento.cs`; depende: TASK-01, TASK-02) — DoD: PBT-01 verde com 10k casos.
- [ ] TASK-04 — Persistir divergências classificadas na tabela `divergencias` (rastreia: REQ-03; paths: `services/conciliacao/Persistencia/DivergenciaRepository.cs`; depende: TASK-03) — DoD: teste de integração com Postgres em container.
- [ ] TASK-05 — Agendar `ConciliacaoDiariaJob` ao detectar os dois arquivos do dia (rastreia: REQ-01, REQ-02; paths: `services/conciliacao/Jobs/ConciliacaoDiariaJob.cs`; depende: TASK-04) — DoD: teste do gatilho com os dois arquivos, e com só um (não dispara).

## Rastreabilidade

| REQ / INV / PBT | Tasks |
|---|---|
| REQ-01 | TASK-01, TASK-05 |
| REQ-02 | TASK-02, TASK-05 |
| REQ-03 | TASK-03, TASK-04 |
| REQ-04 | TASK-04 |
| INV-01 / PBT-01 | TASK-03 |
| INV-02 / PBT-02 | TASK-01, TASK-02 |
