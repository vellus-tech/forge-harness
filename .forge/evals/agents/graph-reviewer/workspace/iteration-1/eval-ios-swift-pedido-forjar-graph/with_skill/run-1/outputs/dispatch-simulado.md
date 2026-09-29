# Despacho de subagentes que eu faria (NÃO executado — regra do harness proíbe spawn nesta run)

Nenhum subagente foi de fato spawnado. Se este caso de eval permitisse delegação, o despacho seria:

- **agente:** `file-analyzer` (definido em `.forge/agents/graph/file-analyzer.md` do template)
  **modelo:** sonnet
  **prompt resumido:** "Curar summaries dos 8 arquivos Swift de `AppPassageiro/` (RecargaViewModel, RecargaService, Cartao, Recarga, CarteiraView, CarteiraViewModel, APIClient, RecargaView) para uso como insumo de um extractor/curadoria de grafo, sem escrever `graph.json` diretamente — produzir summary + lista de dependências observadas por arquivo, para revisão humana antes de qualquer entrada no grafo."
  **por que não segui esse caminho sozinho:** mesmo delegado, o resultado ainda seria uma inferência de leitura de código, não uma extração determinística — não resolveria o problema de fundo (falta de suporte a Swift no extractor nativo), só trocaria quem faz a leitura manual. Por isso o parecer recomenda a correção real (tree-sitter/ADR 0001) em vez de qualquer forma de hand-add, delegado ou não.

Nenhum outro subagente foi cogitado para esta tarefa (o veredito e o parecer são o produto direto do papel `graph-reviewer`, que roda com Read+Bash, sem necessidade de orquestrar outros agentes para uma auditoria de um grafo já construído).
