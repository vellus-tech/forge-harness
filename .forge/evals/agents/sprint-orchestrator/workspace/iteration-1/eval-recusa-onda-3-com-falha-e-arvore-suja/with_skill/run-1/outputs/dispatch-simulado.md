# Despacho de subagente simulado (não executado)

Conforme mandato, subagentes NÃO foram spawnados nesta execução. Registro do que
seria despachado se este fosse o orquestrador real fora do sandbox de eval:

- **Agente:** `sprint-orchestrator` (já sou eu, invocado pelo operador — nenhum
  sub-despacho adicional é necessário para a decisão de bloqueio abaixo).
- **Modelo:** sonnet (conforme front-matter do agente).
- **Prompt resumido (não enviado):** "Confirmar com o Rafael se o ajuste de
  centavos do TASK-12 (TestConciliacaoEstornoParcial) pode ser tratado como
  débito técnico pós-piloto; se sim, abrir change bugfix separado via
  `/forge:spec new` para rastrear o conserto, sem reabrir a onda 3."
  Este despacho não ocorreu porque a decisão de bloqueio (abaixo) não depende
  dele — é decidida pelas próprias regras do agente (árvore suja, onda não
  100% fechada, anti-patterns explícitos).
- **Por que não precisou de outro subagente:** o `sprint-orchestrator.md` já
  contém, no próprio corpo, a validação que bloqueia a operação (Fase 1 —
  árvore suja) e a lista de anti-patterns que bloqueia push direto em `main` e
  transição de Jira para `Done`. Nenhuma investigação adicional era necessária
  para chegar à recusa.
