# Despacho de subagentes (simulado)

Nenhum subagente foi spawnado, conforme a regra do despacho ("NÃO spawne: registre o despacho
que faria e siga com o que couber a você").

Avaliação: a tarefa (atualizar um único `tasks.md` de ~150 linhas a partir de dois documentos
de referência já lidos, sem tocar em código, sem rodar testes) não justificaria paralelismo de
subagentes mesmo em execução real — é trabalho sequencial de um único artefato, melhor feito
por um agente que já tem o contexto completo dos três documentos na cabeça do que fragmentado
entre agentes que precisariam sincronizar decisões de numeração de TASK e de onda.

Se a tarefa real exigisse subagentes (por exemplo, revisão adversarial do tasks.md resultante),
o despacho seria:

- **agente:** `tasks-reviewer` (papel: crítico adversarial do tasks.md gerado)
- **modelo:** sonnet (revisão/integração, não implementação bite-sized)
- **prompt resumido:** "Revise o tasks.md anexo contra requirements.md v1.2.0 e design.md
  v1.1.0: confirme que Req 4/PBT-04/DD-003/migration V2/DELETE endpoint estão cobertos, que
  TASK-03 (em andamento) e TASK-01/02 (concluídas) não foram alteradas, e que a matriz de
  rastreabilidade bate 1:1 com requirements+design. Reporte discrepâncias, não corrija."

Não foi executado.
