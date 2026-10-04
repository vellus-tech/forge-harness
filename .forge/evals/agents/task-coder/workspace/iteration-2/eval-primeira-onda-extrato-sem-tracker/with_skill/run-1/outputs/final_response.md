Wave 1 do extrato-web concluída localmente, com as três TASKs `[X]` e nenhuma falha.

- TASK-01 (filtrarPorPeriodo): `f4970df` vermelho, `eaed42c` verde. O replay TDD passou.
- TASK-02 (testes de estorno): `a865962` vermelho, `e9e3924` verde. O replay TDD passou. O filtro agora exclui `estornado: true`.
- TASK-03 (encerramento): typecheck e testes verdes, tracker marcado.

Branch `feat/extrato-web/wave-1` no worktree `work/.forge/worktrees/extrato-web-wave-1`, em `1a741fd`. Nada foi enviado ao remote.

Não abri o PR da wave. Essa etapa é do sprint-orchestrator e precisa de `gh` e push, que estão bloqueados neste ambiente. Fica pendente no tracker.

Não executei a Wave 2 nem o CSV. O coding-loop roda uma onda por vez, e o pedido de adiantar o CSV ficou fora desta execução.

Trilha de auditoria: `outputs/transcript.md`.
