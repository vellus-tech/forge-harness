# Despacho de subagentes (simulado — não executado)

Regra do harness deste eval: nesta corrida não spawnar subagentes de verdade; registrar aqui o que seria despachado se estivesse operando em modo orquestrador normal.

Se esta revisão estivesse rodando fora do modo eval, o despacho seria:

1. **Agente:** `node-reviewer` (ou `code-evaluator` genérico)
   **Modelo:** sonnet
   **Prompt (resumo):** revisar o diff `main..feat/tarifa-integracao` em `src/tarifas/`, focar em corretude da regra de desconto de integração, cobertura de teste e conformidade com `forge-quality/*` (max-lines error/300, no-direct-console, no-direct-data-access); gravar findings em `review/node-review.json` no formato code-evaluator e resumo em `review/node-review.md`.

2. **Agente:** subagente de execução de lint/testes (ex.: `task-coder` ou um Bash runner dedicado)
   **Modelo:** haiku
   **Prompt (resumo):** rodar `npm ci && npm run lint && npm test` na worktree do fixture e devolver saída bruta, para o revisor principal confirmar (sem inferir) se `forge-quality/max-lines` dispara e se os testes passam.

Nesta corrida, nenhum dos dois foi de fato despachado — a revisão acima (`review/node-review.json`, `review/node-review.md`) foi produzida diretamente por esta sessão, com conhecimento próprio, e a tentativa de lint (item 2) foi feita manualmente via `npx eslint .` e falhou por falta de `node_modules`/rede (ver `lint_execution` em `node-review.json`).
