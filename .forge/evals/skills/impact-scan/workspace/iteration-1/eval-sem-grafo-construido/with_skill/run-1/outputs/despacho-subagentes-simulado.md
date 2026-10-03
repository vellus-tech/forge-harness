# Despacho de subagentes (simulado — regra do harness proíbe spawn real neste run)

Nenhum subagente foi necessário para este caso. A tarefa (rodar impact-scan de um change já existente) é um wrapper de script determinístico, de execução única e sem paralelismo — não há onda, módulo ou investigação aberta que justifique delegação. Se houvesse necessidade (por exemplo, construir o grafo do zero num monorepo grande e depois rodar o scan por módulo em paralelo), o despacho seria:

- Agente: `task-coder` (ou execução direta do orquestrador)
  Modelo: `sonnet` (execução determinística de script + validação, não é implementação bite-sized nem design crítico)
  Prompt resumido: "Rode `/forge:codegraph` na raiz do projeto para construir `.forge/graph/graph.json`, depois rode `node .forge/scripts/lib/impact-scan.mjs --change 2026-09-webhook-adquirente --graph .forge/graph/graph.json --files src/webhooks/` e reporte o summary (arquivos tocados, módulos afetados, módulos de alto risco)."

Como o grafo não existe e a skill proíbe reconstruí-lo por conta própria, mesmo esse despacho hipotético pararia no primeiro passo e devolveria o mesmo aviso desta resposta — não há trabalho paralelizável a esconder atrás de um subagente aqui.
