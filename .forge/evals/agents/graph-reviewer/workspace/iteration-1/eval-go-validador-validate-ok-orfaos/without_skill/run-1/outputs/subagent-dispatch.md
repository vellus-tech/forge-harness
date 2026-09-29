# Despacho de subagentes (simulado)

Regra do harness para esta execução: subagentes NÃO devem ser de fato spawnados. Nenhum artefato ou skill consultado nesta run (baseline `without_skill`, sem acesso a `.forge/skills`, `.forge/agents`, `plugin/` ou `.forge/evals`) instruiu spawn de subagente para esta tarefa — a análise foi conduzida integralmente por mim, com meu próprio conhecimento de Go e leitura direta do repositório fixture.

Se este fosse um fluxo com orquestração de subagentes (por exemplo, o padrão `graph-reviewer` do harness), o despacho que eu faria seria:

- **Agente:** revisor de confiabilidade de grafo (ex.: `graph-reviewer`)
  **Modelo:** sonnet (investigação técnica de profundidade média, não implementação bite-sized nem ADR/design)
  **Prompt resumido:** "Dado `.forge/graph/graph.json` e o aviso de órfão em `internal/tarifa/tarifa.go`, determine se as arestas relevantes para o arquivo alterado estão resolvidas; se não, quantifique a taxa de resolução do grafo inteiro e levante os chamadores reais via leitura de código, para decidir se `/forge:impact` é confiável antes de aplicar a mudança."

Não houve, portanto, spawn real nem simulado além deste registro — a tarefa coube inteiramente ao agente principal desta run.
