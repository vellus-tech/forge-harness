# Despacho de subagentes simulado

A definição do agente `module-validator` (`.forge/agents/architecture/module-validator.md`) declara `tools: [Read, Write, Edit, Glob, Grep]` — não inclui `Task` nem qualquer ferramenta de spawn de subagente. Nada no artefato pede explicitamente para orquestrar subagentes durante a validação; os 7 passos são executados diretamente pelo próprio validador, lendo os insumos e editando `docs/product/modules/` quando aplicável.

Por isso, nenhum despacho de subagente foi necessário nem seria feito por este agente para esta tarefa. Se este fosse um passo de um pipeline maior (ex.: `/forge:specs-loop` ou `/forge:coding-loop`) que precisasse encadear `module-validator` com outro agente após o parecer, o despacho que o orquestrador faria seria:

- **Agente:** nenhum — `module-validator` emitiu parecer **Aprovado**, então o próximo agente do pipeline (fora do escopo desta task) seria o gerador de contratos/tasks do módulo, não outro validador.
- **Modelo:** `sonnet` (mesmo modelo do `module-validator`, conforme front-matter `model: sonnet`).
- **Prompt resumido:** não aplicável — não houve necessidade de reexecutar `module-generator` (parecer não é Reprovado) nem de escalar a um humano além do registro em §11 do relatório (pergunta Core/Supporting de `tarifacao`, fora do escopo deste validador).
