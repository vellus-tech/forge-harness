# Despacho de subagentes (simulado — não executado)

Este caso de eval não exigiu subagentes: é a execução determinística do protocolo wave-advance
(leitura de waves.json/deferrals.json/progress.json via scripts wave-ops.sh e deferral-ops.sh),
sem investigação aberta nem trabalho paralelizável.

Se a tarefa tivesse pedido, por exemplo, investigar por que DEFER-02 ficou aberto por tanto tempo
ou levantar o histórico de aprovações jurídicas de textos de SMS, o despacho seria:

- agente: general-purpose (subagente de investigação)
  modelo: sonnet
  prompt (resumo): "Busque no histórico do change 2026-09-bloqueio-cartao-perdido (commits,
  liaison, comentários) o motivo do atraso na aprovação jurídica de DEFER-02 e reporte prazo
  estimado; não altere nenhum arquivo."

Nenhum subagente foi de fato spawnado.
