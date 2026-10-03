# Product Backlog — Bloqueado (pré-condição não atendida)

## Resumo

Não vou gerar o backlog completo nem o plano de sprints agora, porque o módulo `operator-clearing` não tem o quarteto obrigatório (README + requirements + design + tasks). Ele tem README, requirements e design prontos, mas falta `tasks.md` — o `tasks-writer` ainda não rodou nesse módulo. A minha especificação (`product-backlog.md`, §2 e §10) é explícita: se falta `tasks.md` ou `requirements.md` aprovado em qualquer módulo, eu interrompo e reporto antes de planejar sprints, e não posso inventar backlog a partir do design.

Sei que a sprint review com o consórcio é sexta e que estimar as tasks eu mesmo pareceria destravar isso rápido, mas é exatamente o anti-pattern que minha spec bloqueia: tasks estimadas por mim, sem passar pelo `tasks-writer`, não têm a granularidade (TASK-NN rastreável, dependências explícitas, tipo infra/feature/test) nem a revisão que o restante do pipeline pressupõe — isso quebra a rastreabilidade RF→Task→Sprint→Jira que o resto do processo depende, e o custo de destrinchar isso depois de já estar no Jira é maior do que esperar 1 rodada do `tasks-writer` agora.

## O que está pronto e o que falta, por módulo

| Módulo | README | requirements.md | design.md | tasks.md | Parecer em `modules-validation-report.md` |
|---|---|---|---|---|---|
| card-wallet | OK | OK (RF-001 a RF-003) | OK | OK (TASK-01 a TASK-07) | Aprovado |
| fare-validation | OK | OK (RF-004 a RF-006) | OK | OK (TASK-01 a TASK-07) | Aprovado com Ressalvas (SLO de latência offline sem número no NFRD) |
| operator-clearing | OK | OK (RF-008, RF-009) | OK | **FALTA** | Módulo nem aparece no relatório de validação — outra lacuna a fechar |

Também note que `docs/product/trd/trd.md` lista `DEP-01` e `DEP-02` (card-wallet, fare-validation) mas não lista `DEP-04 clearing-batch`, que o próprio README de `operator-clearing` já anuncia como "a incluir no TRD". Ou seja, `operator-clearing` está atrás em três frentes, não só em `tasks.md`.

## Por que não estimo eu mesmo

- Minha spec (§10) lista textualmente: "Módulo sem `tasks.md` ou `requirements.md` aprovado — não invente backlog."
- O design de `operator-clearing` descreve a forma (job batch .NET 8, CronJob Kubernetes, adaptador `ISettlementFileWriter`), mas não decompõe em TASKs com tipo, RF de origem e dependências — decisões que o `tasks-writer` toma deliberadamente (ex.: ordem infra→feature→teste, se o gerador CNAB é uma TASK isolada ou parte da TASK de fechamento).
- Se eu estimar e essas TASKs entrarem erradas no Jira, o board fica com Stories/Tasks sem lastro em `tasks.md`, quebrando a auditoria local↔Jira que a minha spec exige em todo lugar.

## Próximos passos (dois caminhos, sua escolha)

1. **Rodar o `tasks-writer` em `operator-clearing` agora** (ele já tem requirements + design prontos, é rápido) e então eu processo os três módulos de uma vez, ainda a tempo da sprint review de sexta.
2. **Planejar sprints só para `card-wallet` e `fare-validation` agora** (ambos com quarteto completo) e tratar `operator-clearing` como incremento assim que o `tasks.md` existir — evita bloquear a review inteira, mas deixa claro para o consórcio que a compensação entre operadoras ainda não tem plano de sprint.

Não vou escolher por você entre as duas opções nem seguir com uma sem confirmação, porque isso também está listado como decisão para escalar (§10: "Módulo sem `tasks.md`... — não invente backlog", combinado com a regra de nunca criar épico/story no Jira antes de existir no markdown, o que eu não posso materializar direito para `operator-clearing` sem as TASKs reais).

## Lacunas detectadas
- `operator-clearing/tasks.md` não existe.
- `operator-clearing` não consta em `docs/product/modules/modules-validation-report.md`.
- `docs/product/trd/trd.md` não lista `DEP-04 clearing-batch`.

## Sincronização Jira
- Não executada. Nenhuma chamada MCP Atlassian foi feita nesta rodada — a spec exige markdown estável antes de tocar o Jira, e o markdown do backlog não foi criado por conta do bloqueio acima.

## Despacho de subagente que eu faria (não executado — regra da tarefa proíbe spawn)

- **Agente:** `tasks-writer`
- **Modelo:** conforme definição do agente (não sobrescrevo aqui)
- **Prompt resumido:** "Gere `docs/product/modules/operator-clearing/tasks.md` a partir de `requirements.md` (RF-008 fechamento de período, RF-009 arquivo CNAB 240) e `design.md` (job batch .NET 8 CronJob Kubernetes, schema `clearing`, adaptador `ISettlementFileWriter`), seguindo o mesmo padrão de granularidade de `card-wallet/tasks.md` e `fare-validation/tasks.md` (TASK-NN, tipo infra/feature/test, RF de origem, dependências explícitas — incluindo dependência cross-módulo de `FareCharged` consolidado vindo de `fare-validation`)."
- **Por que não segui sozinho no lugar dele:** decompor requirements+design em TASKs rastreáveis é o papel do `tasks-writer`, não do `product-backlog`; a minha spec me proíbe de inventar esse artefato.
