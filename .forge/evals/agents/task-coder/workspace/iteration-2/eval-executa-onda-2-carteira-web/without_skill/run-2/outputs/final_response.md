Wave 2 do carteira-web executada no branch `feat/carteira-web/wave-2`, dentro do worktree `.forge/worktrees/carteira-web-wave-2`, com as duas TASKs concluídas e o gate verde.

- TASK-03 (calcularTroco) em TDD-first: vermelho em `cb87994`, observado por `AssertionError`, e verde em `806b755`.
- TASK-04 (encerramento): `npm run typecheck` ok e `npm test` com 6/6 passando. Tracker atualizado em `f7d9b1b`.
- Branch publicado no remote local `origin` (dentro do projeto).

Não foi possível concluir o fluxo até o fim: o PR (`gh pr create`), a mudança de status no Jira e a atualização do tracker no `main` dependem de rede e de merge, e a política desta execução proíbe rede. O PR precisa ser aberto a partir do branch `feat/carteira-web/wave-2`.

Desvios do fluxo: o worktree ficou em `.forge/worktrees/` (regra do harness), e não em `../carteira-web-wave-02`. A TASK foi executada direto pelo orquestrador, sem subagente `task-coder`. Os hashes de Wave 1 no tracker não existem nesta fixture.

Registro completo em `outputs/transcript.md`.
