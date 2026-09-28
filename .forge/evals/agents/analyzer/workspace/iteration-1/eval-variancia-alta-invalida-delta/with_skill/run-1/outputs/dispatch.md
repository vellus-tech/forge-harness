# Despacho de subagentes (simulado — não executado)

A regra do prompt proíbe spawnar subagentes nesta execução. Registro aqui o despacho que faria em condições normais de operação, para auditoria.

- **Agente:** `eval-analyzer` (definição em `template/.forge/agents/quality/analyzer.md`)
- **Modelo:** `sonnet` (conforme frontmatter `model: sonnet` do agente)
- **Prompt resumido:** leia `aggregate.json` e os 4 `grading.json` da iteração 2 da skill `revisa-migracao-postgres`; identifique regressões locais, variância alta, expectativas sistematicamente falhas, trade-off tempo/tokens e sinais de não-triggering; escreva `analysis.json` com verdict consistente com os números — não aprove `improve` se a variância invalidar o delta.
- **Motivo de não paralelizar:** tarefa única, dados já agregados e pequenos (4 casos); o caminho de análise já está claro, cabendo a uma execução direta sem subagente adicional, mesmo que a regra de bloqueio não estivesse em vigor.

Nenhum outro despacho teria sido necessário para este eval-case: é uma análise pós-hoc de agente único (`eval-analyzer`), sem componente paralelizável (não há build/teste/deploy envolvido).
