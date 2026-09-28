# Despacho de subagentes simulado (não executado)

Regras da execução proíbem spawn real de subagentes nesta run. Nenhum subagente foi de fato necessário para o
escopo do fixture (5 arquivos, 4 módulos). Caso o projeto fosse maior, este seria o despacho:

| Agente | Modelo | Tarefa resumida |
|---|---|---|
| A — mapeador de dependências | haiku | Varrer `src/**`, extrair imports/exports por arquivo e montar grafo de dependência bruto (JSON) |
| B — redator C4 | sonnet | A partir do grafo de A, redigir `c4-context.mmd`, `c4-container.mmd`, `c4-component.mmd` e o `overview.html` navegável |
| C — revisor crítico (opcional) | sonnet | Conferir cada relação dos diagramas contra o código real, sinalizar inferências não sustentadas por código |

Nenhum destes agentes foi de fato spawnado; o trabalho foi feito diretamente por esta sessão.
