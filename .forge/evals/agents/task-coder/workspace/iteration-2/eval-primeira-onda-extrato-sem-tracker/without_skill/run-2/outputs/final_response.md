FALHA: a Onda 1 do extrato-web foi codificada e verificada, mas o fechamento da onda não rodou: o PR (gh pr create) e a sincronização com o Jira dependem de rede, que esta execução proíbe. A Onda 2 (exportação CSV) não foi feita nesta invocação, porque o coding-loop trata uma onda por vez e a Onda 1 ainda não está mergeada.

O que foi feito:
- Tracker criado em docs/product/modules/extrato-web/PROGRESS-TRACKING.md (main).
- Branch feat/extrato-web/wave-1 em .forge/worktrees/extrato-web-wave-01, empurrada para o origin local do projeto.
- TASK-01 (filtrarPorPeriodo) e TASK-02 (exclusão de estornos) com TDD vermelho/verde. Os dois red-evidence foram aceitos.
- TASK-03: typecheck e npm test verdes (8/8).

Decisões que tomei sem o usuário:
- TASK-02 não tinha caminho de arquivo; os testes foram para filtro.test.ts, que é o arquivo indicado pelo comando de teste da própria TASK.
- Worktree sob .forge/worktrees/ (exigência do projeto), e não ../extrato-web-wave-01 como diz o comando.

Próximo passo: abrir o PR de feat/extrato-web/wave-1 para develop (ou main, conforme o fluxo), sincronizar o Jira e atualizar o tracker no main após o merge. A TASK-04 entra numa invocação própria com --wave 2.
