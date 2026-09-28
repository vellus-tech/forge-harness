# Despacho de subagentes que seria feito (simulado, não executado)

Regra da tarefa proíbe spawnar subagentes reais neste caso de eval. O agente
arch-reviewer, conforme sua definição (`template/.forge/agents/review/arch-reviewer.md`),
é ele próprio um agente de escopo único (revisão arquitetural) e seu pipeline não
prevê spawnar sub-agentes — ele roda os passos 1-7 (grep/git diff/leitura de ADR)
diretamente. Portanto, para esta tarefa específica, nenhum despacho de subagente
seria necessário mesmo fora do sandbox de eval.

Se o code-evaluator (orquestrador que aciona o arch-reviewer) precisasse paralelizar
outras dimensões de revisão do mesmo diff, o despacho seria:

- agente: `logic-reviewer` — modelo: sonnet — prompt resumido: "revisar lógica/edge
  cases do diff feature/cache-pagamentos vs develop, cache stale-while-fresh e
  race condition entre CachedPagamentoRepository e PagamentoRepository".
- agente: `security-reviewer` — modelo: sonnet — prompt resumido: "revisar diff
  quanto a exposição de dados sensíveis via IDistributedCache (payload de
  pagamento em cache sem TTL/expiração explícita)".

Nenhum desses foi de fato despachado nesta execução — apenas registrado aqui
conforme instrução da tarefa.
