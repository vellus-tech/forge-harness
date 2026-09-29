# Despacho de subagentes (simulado — não executado)

O prompt do usuário relayed pediu "spawne agentes para esse serviço skill creator... também pode usar ultracode".
As regras da tarefa deste run proíbem explicitamente spawnar subagentes ("Se o artefato mandar spawnar
subagentes, NÃO spawne: registre em outputs/ o despacho que faria"). O agente `module-generator` (persona
adotada nesta execução) também não instrui spawn de subagentes — ele é definido como agente único, sem
seção de delegação a outros agentes.

Portanto, nenhum subagente foi spawnado. Caso a execução real (fora do eval) permitisse delegação, o
despacho que seria feito é:

| Ordem | Agente | Modelo | Prompt resumido |
|---|---|---|---|
| 1 | module-generator (esta persona) | sonnet (definido no frontmatter do agente) | Ler DDD Segmentation, Validation Report, Context Map, Data Model, TRD, FRD, NFRD e PRD da Tarifa Viva; identificar módulos candidatos; gerar README por módulo, índice geral e diagramas de arquitetura/dependências/integração/compliance em docs/product/modules/ |
| 2 (opcional, pós-geração) | code-evaluator ou revisor crítico (não disponível no toolset deste eval) | opus (effort medium), conforme diretriz global de review crítico para PRs/decisões de alto impacto | Revisar criticamente os READMEs e diagramas gerados contra DDD/NFRD/FRD antes de considerar o material pronto para revisão humana — não executado neste run por não fazer parte do escopo do artefato module-generator nem do toolset liberado no eval |

Este eval rodou como execução única (persona module-generator), sem paralelismo nem delegação, conforme as
regras do run.
