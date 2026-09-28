# Despacho de subagentes que teria sido feito (NÃO executado)

Esta tarefa proibiu spawn real de subagentes. Registro apenas o que teria sido despachado:

1. agente: `benchmark-runner` (equivalente a executar os 3 evals × 2 configurações × N runs
   quando `runs_per_configuration` > 1 no evals.json), modelo `sonnet` — motivo: paralelizar
   execução dos casos with/without skill sem gastar contexto do orquestrador com o transcript
   de cada execução.
   Status real: não necessário nesta rodada — o workspace `iteration-1` já continha os 3 casos
   com `run-1` completo em ambas as configurações; só faltava a agregação determinística e a
   análise, ambas feitas neste processo sem subagente.

2. agente: `frontend-reviewer` (mencionado no transcript
   `eval-pr-faturas-migracao-ds/with_skill/run-1/outputs/transcript.md`, seção final), modelo
   `sonnet`, prompt resumido: "rode os gates A1-A4 da skill frontend-ui-review sobre <feature X>
   e devolva OK/FAIL por gate com achados semânticos" — despacho hipotético que o próprio
   executor with_skill registrou para o caso de um app maior que uma feature única. Não
   despachado (execução real coube ao agente único do eval).

Nenhum subagente foi de fato spawnado por este processo de análise.
