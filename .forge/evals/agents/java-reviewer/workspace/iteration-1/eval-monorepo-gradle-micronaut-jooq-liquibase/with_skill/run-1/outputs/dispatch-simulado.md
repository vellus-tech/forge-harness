# Despacho de subagente simulado (não executado)

O agente `java-reviewer` (template/.forge/agents/code-review/java-reviewer.md) não manda spawnar
subagentes — é um revisor single-shot chamado pelo code-evaluator. Nenhum despacho real foi necessário
para completar a tarefa. Registro aqui apenas o que o protocolo pediria caso a revisão precisasse de
paralelismo (ex.: revisor de front separado, já mencionado como existente pela tarefa do usuário):

- agente: front-reviewer (hipotético, não invocado)
- modelo: sonnet
- prompt resumido: "revisar web/src/api/tarifa.ts do mesmo diff feat/tarifa-integracao vs develop —
  fora do escopo deste run"
- status: NÃO SPAWNADO (regra do harness para este run de eval); front deixado como out_of_scope_note
  no JSON de findings.
