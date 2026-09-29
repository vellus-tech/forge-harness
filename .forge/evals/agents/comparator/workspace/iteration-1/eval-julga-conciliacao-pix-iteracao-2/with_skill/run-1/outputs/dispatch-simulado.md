# Despacho de subagentes (simulado, não executado)

O agente `eval-comparator` (`template/.forge/agents/quality/comparator.md`) declara `tools: [Read, Write]` e é definido como agente solo — o protocolo não pede spawn de subagentes para este caso de eval. Nenhum despacho real de subagente foi necessário nem executado nesta run.

Se a tarefa exigisse paralelismo (por exemplo, julgar N casos em subagentes separados para preservar a janela de contexto do orquestrador, como sugerido no pedido do usuário sobre o skill-creator), o despacho que eu faria seria:

- **Agente:** `eval-comparator` (um por caso de teste, TC-01/TC-02/TC-03)
- **Modelo:** `sonnet` (conforme frontmatter do agente)
- **Prompt resumido:** "Julgue cego o caso <ID> do skill conciliacao-pix contra as expectativas fornecidas; decida winner A/B/tie com rationale citando trechos literais de A e de B; não leia outros artefatos do change."
- **Motivo de não spawnar de fato:** regra explícita da tarefa proíbe spawn real de subagentes nesta execução; o julgamento foi feito diretamente por mim, seguindo o mesmo protocolo que um subagente `eval-comparator` seguiria.
