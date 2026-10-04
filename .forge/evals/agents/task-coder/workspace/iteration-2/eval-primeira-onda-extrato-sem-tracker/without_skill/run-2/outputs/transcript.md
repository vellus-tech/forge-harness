# Transcrição — coding-loop extrato-web (Onda 1)

## Leitura e diagnóstico
- Leu prompt.md, tasks.md, requirements.md, design.md, lancamento.ts e lancamento.test.ts, e .forge/commands/coding/coding-loop.md.
- Estado: main limpo em df5d39e; tracker PROGRESS-TRACKING.md inexistente (esperado pelo pedido); node v26.
- Remote origin aponta para work/.git/eval-origin.git (dentro do projeto): push permitido pela política.
- Specialists da seção 3.c do comando (frontend-engineer etc.) não existem no work; execução feita diretamente, sem subagentes.

## Decisões
- Tracker criado em docs/product/modules/extrato-web/PROGRESS-TRACKING.md no main (37972cd), porque o comando exige o arquivo e o pedido diz que ele não existe.
- Worktree em .forge/worktrees/extrato-web-wave-01 (branch feat/extrato-web/wave-1), e não em ../extrato-web-wave-01 como diz o comando: a regra do projeto (FORGE.md §3, hook enforce-worktree-location) exige o caminho sob .forge/worktrees/, e a política desta execução proíbe escrita fora de work/.
- TASK-02 não tinha caminho de arquivo. Os testes foram para filtro.test.ts, porque o comando da TASK (`node --test "apps/web/extrato-web/src/*.test.ts"`) e design.md ("testes ao lado do arquivo") apontam para esse arquivo. O filtro por período é o arquivo da TASK-01.
- Commits de TASK com assunto `TASK-NN — vermelho ...` e `TASK-NN — ...`. Na primeira tentativa usei "T-01", e o red-evidence reprovou (`topologia`); reescrevi a branch local antes de qualquer push (commits 1b4d966, f90a604) e reprovei com OK.
- Exportação CSV da Onda 2 (TASK-04) não executada: o comando trata uma onda por invocação, e a Onda 1 ainda não está mergeada, então empilhar a Onda 2 nela misturaria trabalho não revisado.

## Passos e resultados
1. Commit do tracker em main: 37972cd.
2. git worktree add .forge/worktrees/extrato-web-wave-01 -b feat/extrato-web/wave-1 main: ok.
3. TASK-01 vermelho: filtro.ts com stub que devolve [] e filtro.test.ts com 2 testes. node --test: 2 falhas por AssertionError (1b4d966).
4. TASK-01 verde: filtrarPorPeriodo com validação `inicio > fim` -> RangeError e filtro por `l.data >= inicio && l.data <= fim` (f90a604). node --test: 2/2 ok.
5. red-evidence task (red 1b4d966, green f90a604, task-base 37972cd, TASK-01): OK, comportamental, falha por asserção no vermelho.
6. TASK-02 vermelho: 3 testes adicionados (estornado dentro do período; campo ausente; não mutação) (5409bc0). node --test: 4 pass, 1 fail (AssertionError).
7. TASK-02 verde: `!l.estornado` no filtro (b73a596). node --test: 5/5 ok.
8. red-evidence task (red 5409bc0, green b73a596, task-base f90a604, TASK-02): OK.
9. TASK-03: npm run typecheck rc=0 (3 arquivos); npm test rc=0 (8 testes, 8 pass, 0 fail). Logs em tmp/t03-*.log.
10. Tracker atualizado com TASK-01..03 [X] (4cdb77a).
11. spec-advance-module.sh extrato-web implementing: SKIP, sem change SDD mapeável (esperado, não bloqueia).
12. git push -u origin feat/extrato-web/wave-1: ok (remote local dentro do projeto).

## Não executado
- gh pr create com label auto-review: rede proibida nesta execução.
- Sincronização Jira (In Review): rede proibida.
- Atualização do tracker no main (depende do merge do PR).
- Onda 2 / TASK-04 (exportarCsv): fora desta invocação do comando.

## Arquivos escritos
- work/docs/product/modules/extrato-web/PROGRESS-TRACKING.md (main)
- work/.forge/worktrees/extrato-web-wave-01/apps/web/extrato-web/src/filtro.ts
- work/.forge/worktrees/extrato-web-wave-01/apps/web/extrato-web/src/filtro.test.ts
- work/.forge/worktrees/extrato-web-wave-01/docs/product/modules/extrato-web/PROGRESS-TRACKING.md
- tmp/*.log (saídas de teste e red-evidence)
