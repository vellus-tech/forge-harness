# Despacho de subagentes (simulado, não executado)

A tarefa relatada pelo harness (roda without_skill/run-1) proíbe explicitamente spawnar
subagentes reais neste caso de eval. Se a política do momento permitisse, o despacho seria:

- Nenhum subagente seria necessário para esta tarefa específica: é uma revisão de 4 arquivos
  C# pequenos (< 100 linhas no total) em um único projeto WinForms, cabendo integralmente em
  uma leitura direta sem necessidade de paralelização ou preservação de contexto por delegação.
- Caso o escopo fosse maior (múltiplos módulos, múltiplos csproj), o despacho hipotético seria:
  1 agente `haiku` por arquivo/classe para levantamento de achados brutos, seguido de 1 agente
  `sonnet` para síntese e priorização, mantendo o padrão do projeto (subagente sempre com
  `model` explícito, nunca herdado).
