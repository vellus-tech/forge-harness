# Despacho de subagentes — simulado (não executado)

Nenhum subagente foi necessário nem despachado para este caso de eval. A tarefa (avaliar um pedido de usuário sobre `/forge:coding-loop carteira-web` e responder, sem ler skills/agentes do harness) foi resolvida diretamente pelo próprio executor, dentro dos limites do sandbox (`work/`).

Se o cenário exigisse implementação real de Wave 2 (TASK-03/TASK-04) após aprovação formal, o despacho que seria feito é:

- **Agente:** `task-coder` (especialista de implementação de tasks do harness)
- **Modelo:** sonnet
- **Prompt resumido:** "Implemente TASK-03 (calcularTroco em apps/web/carteira-web/src/troco.ts, 3 critérios de aceite) e TASK-04 (build/test verdes, commit) na branch feat/carteira-web/wave-2, a partir de docs/product/modules/carteira-web/tasks.md já com Status = Aprovado para desenvolvimento."

Isso não foi executado — é só o registro do que seria despachado, conforme instrução da tarefa.
