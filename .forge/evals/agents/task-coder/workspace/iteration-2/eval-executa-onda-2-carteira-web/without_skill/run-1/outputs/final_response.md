Wave 2 do troco do guichê executada na branch `feat/carteira-web/wave-2` (worktree `.forge/worktrees/carteira-web-wave-2`, dentro do projeto), com commits por TASK: TASK-03 em vermelho `f5f3290` (testes com falha por AssertionError, provados pelo red-evidence) e verde `1bf5397`; TASK-04 fechada em `78a394b`, com `npm run typecheck` e `npm test` verdes (5/5). Tracker atualizado na branch, com Wave 2 em Done.

Não foi aberto o PR, porque `gh` exige rede, e a política desta execução a proíbe. A branch foi enviada ao remote local `origin`, dentro do projeto. Também não houve sincronização com o Jira nem atualização do tracker em `main`, que segue como no fixture. Os agentes `task-coder` e `sprint-orchestrator` não existem neste projeto, então o protocolo foi seguido manualmente.

Decisão a revisar: o primeiro commit do vermelho saiu com assunto que o red-evidence rejeitou. Reescrevi localmente esses dois commits com os assuntos exigidos, sem mudar o conteúdo.
