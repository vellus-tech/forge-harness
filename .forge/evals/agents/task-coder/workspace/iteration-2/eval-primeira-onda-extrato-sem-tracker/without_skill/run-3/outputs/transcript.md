# Transcrição — coding-loop extrato-web (onda 1)

## Leitura inicial

- `work/AGENTS.md`, `work/package.json`, `work/README.md`: stack TypeScript com type stripping do Node, testes com `node --test`, gates `npm run typecheck` e `npm test`.
- `work/docs/product/modules/extrato-web/tasks.md`: status "Aprovado para desenvolvimento", quatro TASKs em duas ondas (Onda 1: TASK-01, TASK-02, TASK-03; Onda 2: TASK-04).
- `requirements.md` e `design.md`: Req 1.1 (intervalo fechado), 1.2 (RangeError), 1.3 (estornos fora, função pura), 2.1 (CSV). Design diz que a exclusão de estornos entra na TASK-02.
- `apps/web/extrato-web/src/lancamento.ts` e `lancamento.test.ts`: tipo `Lancamento` e `saldo`, sem alterações.
- `.forge/commands/coding/coding-loop.md`: fluxo por onda, tracker `[ ]/[-]/[X]/[!]`, TDD com vermelho commitado separado e validação por `red-evidence.sh task`.
- `.forge/rules/conventions/git-worktree.md`: worktree em `.forge/worktrees/<nome>`, ignorado pelo `.gitignore`.
- `node --version`: v26.0.0.

## Decisões

1. Criei o worktree `work/.forge/worktrees/extrato-web-wave-01` com branch `feat/extrato-web/wave-1` (nome definido em `tasks.md`). Diretório dentro do repositório, conforme a regra de worktree e o `.gitignore`. A convenção `../<modulo>-wave-<NN>` do command apontaria para fora das pastas permitidas.
2. `PROGRESS-TRACKING.md` não existia. Criei em `docs/product/modules/extrato-web/PROGRESS-TRACKING.md` no próprio branch da onda, não no `main`. O command prevê atualizar o tracker no `main` só ao fechar a onda via PR, e o PR não pôde ser aberto (ver abaixo).
3. TASK-02 não tinha "Arquivos esperados". Os testes foram para `apps/web/extrato-web/src/filtro.test.ts`, o arquivo criado pela TASK-01, que é onde o `filtrarPorPeriodo` mora. Esta lacuna do `tasks.md` fica registrada como pendência para o tasks-writer.
4. TASK-02 exige a exclusão de estornos, e o design a põe na TASK-02. Por isso o ciclo vermelho/verde da TASK-02 inclui a implementação da exclusão em `filtro.ts`.
5. Specialist: as TASKs são funções puras TypeScript em `apps/web/**`. O command mapeia `apps/web/**` para `frontend-engineer`, mas não havia `.forge/agents/coding/task-coder.md` nem os agentes especialistas no repositório, e a execução não podia delegar com rede proibida. Implementei diretamente, seguindo o contrato de TDD do command: vermelho só com testes e stub de valor neutro, falha por asserção, verde separado.
6. Não invoquei subagentes. O trabalho coube no próprio orquestrador e a política do ambiente não exige delegação.

## Comandos e resultados

- `git worktree add .forge/worktrees/extrato-web-wave-01 -b feat/extrato-web/wave-1`: ok, HEAD em `df5d39e`.
- Commit `ffab79b`: cria `PROGRESS-TRACKING.md` com TASK-01 em `[-]`.
- TASK-01 vermelho: `filtro.ts` com stub `return []` e `filtro.test.ts` com 2 testes. `node --test apps/web/extrato-web/src/filtro.test.ts` rc=1, `AssertionError` em "Expected values to be strictly deep-equal" e "Missing expected exception (RangeError)". Commit `22f1c41` (reescrito por rebase com o assunto `TASK-01 — vermelho: ...` exigido pelo `red-evidence.sh`; o primeiro commit tinha assunto sem a palavra vermelho e foi rejeitado pela checagem).
- TASK-01 verde: implementação com `RangeError` e filtro de intervalo fechado. Commit `6a772c6`. 2 testes passando.
- `red-evidence.sh task --red HEAD~1 --green HEAD --task-base ffab79b --task-id TASK-01 ...`: `OK task`, teste do verde falha por asserção sobre o vermelho e passa no verde.
- Commit `3c740e4`: TASK-01 `[X]`, TASK-02 `[-]`.
- TASK-02 vermelho: 3 testes novos (estorno dentro do período, campo ausente, não mutação). Execução: `AssertionError` no teste de estorno. Commit `9dc8816` com assunto `TASK-02 — vermelho: ...`.
- TASK-02 verde: `filter((l) => !l.estornado && ...)`. Commit `afef9e8`. `red-evidence.sh` com `--task-base 3c740e4`: `OK task`.
- Commit `818fcce`: TASK-02 `[X]`, TASK-03 `[-]`.
- `npm run typecheck`: rc=0, "typecheck ok: 3 arquivo(s)".
- `npm test`: rc=0, 8 testes passando, 0 falhas.
- Commit `fb7e594`: TASK-03 `[X]`, onda 1 fechada no tracker.
- `git status --short` no worktree: limpo. `git log main..HEAD`: 8 commits no branch da onda.

## Não executado

- Push, `gh pr create` com label `auto-review`, mover issues Jira para `In Review`, `spec-advance-module.sh extrato-web implementing/implemented`, atualização do tracker no `main`: a política desta execução proíbe rede. O `sprint-orchestrator` não foi invocado. Isso precisa ser feito pelo operador quando houver rede.
- Onda 2 (TASK-04, exportarCsv): não executada. O command roda uma onda por invocação, a onda 2 nasce da branch da onda 1 e a Onda 1 ainda não foi integrada, então adiantá-la quebraria o fluxo. Requisito 2.1 e `tasks.md` seguem pendentes.
- Sem `.forge/agents/coding/task-coder.md`, `sprint-orchestrator.md` ou scripts de Jira no repositório; apenas `red-evidence.sh`, `worktree-reconcile.sh` e `spec-advance-module.sh` existem em `.forge/scripts/`.

## Pendências registradas

- `tasks.md` da TASK-02 sem "Arquivos esperados" (tasks-writer).
- Tracker criado no branch da onda, não no `main`.
- Estorno (Req 1.3) cobre "função pura não muta" na TASK-02, mas a TASK-01 não exclui estornados; a separação segue o design.
