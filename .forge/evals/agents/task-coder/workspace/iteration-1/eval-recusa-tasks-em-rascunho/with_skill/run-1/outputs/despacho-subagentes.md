# Despacho de subagentes (simulado)

Nenhum. O pipeline do `task-coder` só invoca specialist via Agent tool na Fase 3 (§3.4), depois de
passar pela Fase 0 (leitura + validação de status) e pela Fase 1 (detecção de onda) e Fase 2
(worktree). Esta execução abortou na Fase 0 por `tasks.md` estar em `Rascunho para revisão`, então
nenhum specialist chegou a ser considerado ou despachado.

Se o status estivesse `Aprovado para desenvolvimento`, o despacho que eu registraria para a
TASK-03 (`calcularTroco`) seria:

- **Agente:** `frontend-engineer` (specialist), via Agent tool
- **Modelo:** conforme definição do specialist (não escolhido nesta execução — abortada antes)
- **Motivo da escolha:** `arquivos_esperados` da TASK-03 apontam para
  `apps/web/carteira-web/src/troco.ts` e `troco.test.ts` — path em `apps/web/**`, `*.ts` → mapeia
  para `frontend-engineer` pela regra de seleção por path (§3.2.2)
- **Prompt resumido:** payload estruturado com `task_id: TASK-03`, conteúdo integral da seção
  TASK-03 do `tasks.md`, `module: carteira-web`, branch/worktree da Wave 2, arquivos esperados,
  critérios de aceite TASK-03.1..TASK-03.4, requisitos cobertos (Req 2.1-2.3), paths de contexto
  (requirements.md, design.md, glossário, rules de convenções/domínio/testes), política de commit
  (sem co-autoria de IA, sem push) e política de teste (TDD-first, build+testes locais antes de
  commitar).

A TASK-04 (encerramento da Wave 2) não invocaria specialist em nenhum cenário — é tratada
diretamente pelo `task-coder` (§3.2.4), rodando `npm run typecheck` e `npm test` localmente.

Nenhum desses despachos foi executado nem simulado como ação real; este arquivo apenas documenta o
que teria sido despachado caso a pré-condição de status tivesse sido satisfeita.
