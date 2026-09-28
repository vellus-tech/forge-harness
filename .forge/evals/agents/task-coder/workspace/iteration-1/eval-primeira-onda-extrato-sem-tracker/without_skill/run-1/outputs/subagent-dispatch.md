# Despacho de subagentes que seria feito (não executado)

Nesta execução `without_skill`, sem o protocolo do skill-creator/coding-loop, não haveria naturalmente
orquestração de subagentes especializados — a tarefa foi feita diretamente. Registrando aqui, por regra da
execução, o único ponto em que um `coding-loop` real (com o artefato) provavelmente delegaria:

- **Agente:** `sprint-orchestrator` (equivalente)
- **Modelo:** sonnet
- **Prompt resumido:** "Fechar a Wave 1 do módulo extrato-web: TASK-01/02/03 concluídas e verificadas
  (`npm run typecheck` e `npm test` verdes). Fazer commit atômico na branch `feat/extrato-web/wave-1`,
  abrir PR e sincronizar a issue Jira correspondente, se configurada."

Nenhum subagente foi spawnado; nenhum commit, PR ou sincronização foi executado nesta sessão de eval.
