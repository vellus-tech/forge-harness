# Tasks — hookspath-respect-custom

## Wave 1 — Fix + teste de regressão

- [X] TASK-01 — `bin/forge.mjs`: `updateHarness()` e fluxo `init` passam a checar hooksPath atual antes de escrever (ausente/default → seta; já correto → no-op; customizado → preserva + nota) (rastreia: bugfix.md §2, §4; paths: `bin/forge.mjs`; depende: —)
- [X] TASK-02 — `installer/install.sh`: mesma lógica, para paridade (rastreia: bugfix.md §2, §3; paths: `installer/install.sh`; depende: —)
- [X] TASK-03 — Teste de regressão: repo com hooksPath customizado → init/update preserva; repo sem hooksPath → segue setando (rastreia: bugfix.md §5; paths: `tests/`; depende: TASK-01, TASK-02)

## Rastreabilidade

| Bugfix §  | Tasks |
|---|---|
| §2 comportamento esperado | TASK-01, TASK-02 |
| §5 testes de regressão | TASK-03 |
