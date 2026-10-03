# Despacho de subagentes que seria feito (NÃO executado — regra do prompt proíbe spawn real)

Este caso de eval não exigiu subagentes: é uma execução de um único agente (`module-validator`) sobre um projeto pequeno (4 módulos, 14 insumos). Não há paralelismo real a explorar nem carga de contexto que justifique dividir o trabalho.

Se o volume fosse maior (ex.: catálogo com 20+ módulos, ou os 14 insumos muito extensos), o despacho hipotético seria:

- **agente:** `module-validator` (mesmo agente, invocação paralela por fatia)
  **modelo:** sonnet (definido no frontmatter do agente)
  **prompt resumido:** "Rode os Passos 1–2 (cobertura BC↔módulo e ownership) para os módulos {A,B,C,D}, leia os insumos 1–3 e 7 antes de começar, devolva achados classificados por severidade sem escrever o relatório final."
  **motivo de não ter sido usado aqui:** volume pequeno; um agente único consegue ler os 14 insumos e rodar os 7 passos sem estourar janela de contexto.

Nenhum subagente foi de fato spawnado nesta execução.
