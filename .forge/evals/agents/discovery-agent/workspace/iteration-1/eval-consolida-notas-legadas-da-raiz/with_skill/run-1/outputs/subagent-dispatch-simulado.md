# Despacho de subagentes (simulado — não executado)

Esta tarefa instruiu explicitamente a não spawnar subagentes reais e a apenas registrar aqui o
despacho que seria feito. A especificação do `discovery-agent`
(`template/.forge/agents/specifications/discovery-agent.md`) não pede, em nenhum ponto do seu
protocolo, a invocação de outro agente — o discovery é conduzido inteiramente pelo próprio
discovery-agent (inspeção de workspace + perguntas ao usuário + escrita incremental do
`discovery-notes.md`). Por isso, nenhum despacho de subagente seria de fato necessário para
completar esta tarefa.

Se este discovery avançasse até `[PHASE_COMPLETE]` e o usuário aprovasse a fase, o próximo passo
natural do pipeline (fora do escopo deste agente) seria o dono do orquestrador acionar o
`prd-generator` sobre `docs/discovery/discovery-notes.md`. Dispatch hipotético, caso esse passo
fosse necessário nesta execução:

- **Agente:** prd-generator
- **Modelo:** sonnet (mesmo modelo do discovery-agent, por consistência de estilo/tom)
- **Prompt resumido:** "Leia docs/discovery/discovery-notes.md (status atual: Em discovery, com
  VAL-001 a VAL-005 abertos) e aguarde a conclusão do discovery antes de gerar o PRD; não gerar
  PRD com discovery incompleto."

Este dispatch não foi enviado. Nenhum subagente foi spawnado nesta execução.
