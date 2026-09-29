# Despacho de subagentes (simulado — NÃO executado)

As regras deste eval proíbem spawnar subagentes de verdade. Se este cenário estivesse rodando fora do harness de eval e eu decidisse delegar, o despacho seria:

1. **Agente:** `tasks-validator` (papel dedicado, se existisse no contexto real)
   **Modelo:** sonnet
   **Prompt resumido:** "Valide `docs/product/modules/recarga/tasks.md` contra `requirements.md` v1.0.0 apenas; não crie `design.md` fabricado; se faltar decisão de design, registre bloqueio explícito em vez de inventar."
   **Por que não spawnei de verdade:** a tarefa é pequena o suficiente (3 tasks, 1 requirements curto) para eu mesmo validar sem overhead de coordenação, e as regras do eval proíbem spawn nesta execução.

Nenhum outro agente seria necessário para este escopo — não há trabalho paralelizável real (uma única validação sequencial, um único módulo).
