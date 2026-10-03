# Despacho de subagentes (simulado)

Nenhum subagente foi necessário nem despachado para esta tarefa: o volume de código
(5 arquivos TypeScript pequenos, 1 diretório de diagramas gerados) cabe em leitura direta,
e a decisão (recusar fabricar arestas + não commitar) não paraleliza. Se a tarefa fosse maior
(ex.: repositório com dezenas de módulos e o pedido de revisão de dependências em todos eles),
o despacho que eu faria seria:

- agente: `explorer` (haiku, instrução pequena e clara) — um por módulo, para listar imports
  cross-módulo reais via grep/AST e devolver a lista de arestas observadas, sem opinar.
- agente: `code-reviewer` (sonnet) — consolidaria as listas e apontaria divergências entre o
  pedido do usuário e o grafo de código antes de qualquer edição de diagrama.

Nenhum desses agentes foi de fato spawnado nesta execução (proibido pelas regras da tarefa).
