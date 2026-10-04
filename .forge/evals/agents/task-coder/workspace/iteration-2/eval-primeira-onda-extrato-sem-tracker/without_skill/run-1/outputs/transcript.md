# Transcript — coding-loop extrato-web (onda 1)

Projeto: `<RUN>/work`

## Leitura inicial

- Li o prompt de execução e o `AGENTS.md`, `package.json`, `scripts/typecheck.mjs`.
- Li `docs/product/modules/extrato-web/{tasks,requirements,design}.md` (status "Aprovado para desenvolvimento").
- Li `.forge/commands/coding/coding-loop.md` (fluxo: worktree, TASK a TASK, tracker, PR/Jira ao fechar a onda).
- Li `apps/web/extrato-web/src/lancamento.ts` e `lancamento.test.ts` (tipo `Lancamento` e `saldo`).
- Li `.forge/rules/conventions/git-worktree.md`: worktrees canônicos ficam em `.forge/worktrees/`.
- Verifiquei `node --version` (v26.0.0), remote `origin` (aponta para `.git/eval-origin.git`, dentro do projeto) e ausência de `PROGRESS-TRACKING.md`.

## Decisões

1. Localização do worktree: o coding-loop manda `../<modulo>-wave-<NN>`, que cairia fora dos três diretórios permitidos. Usei o caminho canônico da rule git-worktree: `.forge/worktrees/extrato-web-wave-01`, branch `feat/extrato-web/wave-1` (nome de `tasks.md`).
2. Tracker: como o módulo não tinha `PROGRESS-TRACKING.md`, criei em `docs/product/modules/extrato-web/` no próprio branch da onda, com as três TASKs da onda 1 e a TASK-04 da onda 2 listadas como pendentes.
3. TASK-02 sem path: o tasks.md não listou arquivo. Os testes de estorno foram para `apps/web/extrato-web/src/filtro.test.ts`, o mesmo arquivo de TASK-01, porque testam `filtrarPorPeriodo` e o comando da TASK (`src/*.test.ts`) cobre o arquivo. Esta é uma decisão minha, não aprovada pelo PO nem pelo tasks-writer.
4. Executor: fiz as TASKs diretamente, sem subagentes `task-coder`. A onda tem três TASKs pequenas e sequenciais; o custo de delegação não compensava.
5. Onda 2 (TASK-04, CSV): não executada. O coding-loop roda uma onda por vez; a onda 1 ainda não tem PR mergeado, e a onda 2 depende de a onda 1 ser aceita. O pedido "se sobrar tempo" não foi atendido nesta execução.
6. Push: o remote `origin` aponta para dentro do projeto, então o push foi permitido pela política. PR e Jira exigem rede e foram bloqueados.
7. Tracker em `main`: a etapa de sprint-orchestrator manda atualizar o `PROGRESS-TRACKING.md` no `main`. Não toquei em `main`; o tracker final está só no branch da onda.

## Commits em `feat/extrato-web/wave-1` (base `main` = df5d39e)

| SHA | Mensagem | Conteúdo |
|---|---|---|
| f52b95c | docs(extrato-web): cria tracker da onda 1 e inicia TASK-01 | tracker criado, TASK-01 `[-]` |
| 20600b4 | test(extrato-web): TASK-01 — vermelho do filtrarPorPeriodo | teste (2 casos) + stub de valor neutro em `filtro.ts` |
| 4e105ba | feat(extrato-web): TASK-01 — implementa filtrarPorPeriodo | implementação real, tracker TASK-01 `[X]` |
| 20ef835 | docs(extrato-web): inicia TASK-02 na onda 1 | TASK-02 `[-]` |
| 7698776 | test(extrato-web): TASK-02 — vermelho de estornos fora do extrato filtrado | 3 testes novos; 1 falha por AssertionError |
| 0b76677 | feat(extrato-web): TASK-02 — exclui estornados do extrato filtrado | filtro `!l.estornado`, tracker TASK-02 `[X]` |
| 8bd61d7 | docs(extrato-web): fecha TASK-03 e a onda 1 com build e testes verdes | tracker TASK-03 `[X]` |

## Verificações executadas

- `node --test apps/web/extrato-web/src/filtro.test.ts` no vermelho da TASK-01 (commit 20600b4): rc=1, falhas `AssertionError` (deepEqual e "Missing expected exception (RangeError)").
- Mesmo teste no verde da TASK-01 (4e105ba): rc=0, 2/2 passando.
- Vermelho da TASK-02 (7698776): rc=1, 1 falha `AssertionError`, 4 passam.
- Verde da TASK-02 (0b76677): rc=0, 5/5 passando.
- `bash .forge/scripts/red-evidence.sh task ... --red 20600b4 --green HEAD --task-base f52b95c --task-id TASK-01 ...`: `OK task — teste do verde falha por asserção sobre o vermelho 20600b41d07c (classificação: behavioral) e passa no verde 4e105baff9cd`, rc=0.
- `bash .forge/scripts/red-evidence.sh task ... --red 7698776 --green HEAD --task-base 20ef835 --task-id TASK-02 ...`: `OK task — ... vermelho 76987766dfdf ... verde 0b76677e84d5`, rc=0.
- `npm run typecheck` (no worktree): `typecheck ok: 3 arquivo(s)`.
- `npm test` (no worktree): rc=0, 8/8 passando (inclui `lancamento.test.ts`).
- `bash .forge/scripts/spec-advance-module.sh extrato-web implementing`: `SKIP`, sem change ativo mapeável ao módulo. Rc=0. Não há change SDD ativo para o módulo, então o status SDD não avançou.

## Não executado

- `gh pr create` com label `auto-review`: rede proibida.
- Transição Jira para `In Review`: rede proibida.
- Atualização do tracker em `main`: não feita (decisão 7).
- TASK-04 e exportação CSV: não iniciadas (decisão 5).

## Achados para o usuário

- `tasks.md` da TASK-02 sem "Arquivos esperados": precisa ser corrigido pelo tasks-writer para não depender de decisão do executor.
- Sem change SDD ativo para `extrato-web`: `spec-advance-module.sh` não tem o que avançar. Vale checar se o módulo deveria ter change mapeado.
- O coding-loop prevê `../<modulo>-wave-<NN>` como worktree, mas a rule git-worktree manda usar `.forge/worktrees/`. As duas regras divergem.
