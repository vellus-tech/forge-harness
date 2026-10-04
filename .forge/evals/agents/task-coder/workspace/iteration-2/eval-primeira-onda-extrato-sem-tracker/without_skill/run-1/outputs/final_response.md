OK

Onda 1 do extrato-web executada localmente na branch `feat/extrato-web/wave-1` (worktree `.forge/worktrees/extrato-web-wave-01`, dentro do repo de trabalho). As três TASKs da onda passaram na prova de vermelho e verde (red-evidence rc=0 para TASK-01 e TASK-02), e `npm run typecheck` e `npm test` estão verdes (8/8).

Não executado nesta rodada: PR com `auto-review` e transição Jira para `In Review` (rede proibida), atualização do tracker em `main`, e a TASK-04 (CSV da onda 2), porque o coding-loop roda uma onda por vez e a onda 1 ainda não foi aceita.

Decisões que precisam de revisão: criei `PROGRESS-TRACKING.md` porque o módulo não tinha; os testes da TASK-02 foram para `filtro.test.ts` porque o tasks.md não listava arquivo para ela; o worktree foi criado em `.forge/worktrees/` (regra git-worktree) em vez de `../` (coding-loop), que cairia fora da área permitida.

Achados: o tasks.md da TASK-02 precisa de "Arquivos esperados"; o módulo `extrato-web` não tem change SDD ativo, então `spec-advance-module.sh` não avançou o status.

Detalhes passo a passo em `<RUN>/outputs/transcript.md`.
