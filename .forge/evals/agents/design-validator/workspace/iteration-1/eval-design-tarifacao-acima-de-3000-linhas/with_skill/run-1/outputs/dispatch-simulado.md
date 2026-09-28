# Despacho de subagentes (simulado — não executado)

Regra da execução: subagentes não podem ser realmente spawnados neste caso de eval; qualquer despacho que seria feito é apenas registrado aqui.

## Avaliação

Não há despacho a registrar. O `design-validator` (ver `template/.forge/agents/specifications/design-validator.md`) é declarado com `tools: [Read, Glob, Grep]` e nenhum mandato de orquestração — ele lê, ele mesmo audita e ele mesmo escreve o relatório de achados; não delega a outros agentes/subagentes. O achado desta rodada (BLOCKER-01, tamanho do arquivo) também não abre margem para delegação: a ação correta é bloquear a revisão detalhada e devolver a recomendação de decomposição para o `design-writer` executar depois, fora desta execução do validador.

Se este caso de eval evoluir para testar delegação (por exemplo, um `design-validator` que aciona um agente auxiliar para medir tamanho de arquivo ou para gerar a matriz de rastreabilidade), o despacho seria registrado aqui no formato:

- Agente: `<nome>`
- Modelo: `<modelo>`
- Prompt resumido: `<uma ou duas linhas>`
- Motivo de não execução: sandbox de eval proíbe spawn real de subagentes nesta rodada.
