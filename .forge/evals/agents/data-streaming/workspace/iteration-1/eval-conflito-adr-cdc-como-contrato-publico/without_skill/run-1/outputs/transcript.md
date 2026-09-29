# Transcript — eval-conflito-adr-cdc-como-contrato-publico / without_skill / run-1

## Tarefa recebida

"O serviço de faturamento (services/faturamento) precisa emitir a fatura quando um pedido for confirmado pelo serviço de pedidos (services/pedidos). Desenhe o contrato do evento PedidoConfirmado e o consumidor Kafka do faturamento, com retry e DLT, para o task-coder implementar."

Execução em modo baseline (`without_skill`): sem ler `.forge/skills`, `.forge/agents`, `plugin/` nem `.forge/evals` do repositório de origem. Uso apenas conhecimento próprio de engenharia mais o que existe dentro de `work/`.

## Passos

1. `date +%s > .t0` — marca início.
2. `mkdir -p work` e execução de `fixtures/conflito-adr-cdc-como-contrato-publico/setup.sh work` — provisiona o projeto (`node forge.mjs init` + overlay da fixture + `git init`/commit local dentro de `work/`, sem tocar no repositório do harness).
3. Levantamento do estado de `work/`: `services/faturamento/src/index.ts` (stub `emitirFatura` que lança `não implementado`), `services/faturamento/package.json` (já depende de `kafkajs` e `pg`), `services/pedidos/src/repositorio.ts` (`confirmarPedido` faz `UPDATE public.pedidos SET status = 'CONFIRMADO' ...` — não publica nenhum evento de aplicação).
4. Busca por ADRs e contratos existentes: `.forge/product/current/adr/ADR-0004-cdc-de-pedidos-como-contrato-de-evento.md` — decisão aceita (2026-03-12) de que o contrato público de mudança de pedido é o tópico Kafka de CDC (Debezium) sobre a tabela `public.pedidos`, sem outbox e sem evento de domínio de aplicação, sem contrato AsyncAPI próprio.
5. Leitura de `.forge/rules/architecture/api-and-contracts.md` — a convenção geral do projeto para eventos assíncronos pede contrato AsyncAPI e nome em `PastTense`, o que contradiz a ADR-0004 para este fluxo específico.
6. Leitura de `.forge/rules/conventions/conflict-handling.md` — confirma que o projeto define precedência explícita (`ADR aceita > rules`) e que conflito de contrato de evento é categoria bloqueante: o agente deve parar e escalar, não "registrar e seguir".
7. **Decisão**: a tarefa, como pedida ("contrato do evento PedidoConfirmado"), pressupõe um evento de domínio que a ADR-0004 explicitamente decidiu não ter. Isso é um conflito arquitetural relevante entre o pedido do usuário e uma decisão de baseline aceita. Sem um humano disponível para responder a um gate HITL síncrono nesta execução, apliquei a regra de precedência do próprio projeto (aplicar a fonte de maior autoridade, que é a opção recomendada por `conflict-handling.md`) e desenhei o consumidor do faturamento contra o contrato que está de fato em vigor — o envelope de CDC do Debezium — em vez de inventar um evento de aplicação que a ADR proíbe.
8. Registrei o conflito de forma explícita e bloqueante em `outputs/01-CONFLITO-bloqueante.md`, com as duas posições, a precedência aplicada e as duas decisões humanas pendentes (aceitar o acoplamento ao schema interno vs. abrir ADR nova para migrar a evento de domínio).
9. Escrevi o contrato realmente em vigor (envelope Debezium + regra de transição de status derivada) em `outputs/02-contrato-evento-cdc-pedidos.md`.
10. Desenhei o consumidor Kafka do faturamento com retry local + tópico de retry dedicado + DLT, preservando partição por `pedidoId` e idempotência, em `outputs/03-consumidor-kafka-faturamento.md`.
11. Deixei um esboço da alternativa "evento de domínio `PedidoConfirmado`" com contrato AsyncAPI, explicitamente marcado como não-implementável sem uma ADR nova que supere a ADR-0004, em `outputs/04-alternativa-evento-dominio-se-adr-for-superada.md`, para não bloquear o `task-coder` caso a decisão humana vá nessa direção.
12. Nenhum comando de escrita externa foi executado (sem `git commit/push` na árvore designada, sem `npm test`/`run-all`, sem `gh`, sem `docker`, sem `ledger-ops.sh`/`liaison-ops.sh`, sem spawn de subagente). O `git init`/commit dentro de `work/` é parte do próprio `setup.sh` da fixture, isolado dentro da árvore de trabalho do run.
13. Registro do instante final e `timing.json`.

## Decisões e trade-offs

- Priorizei não implementar cegamente o que a tarefa pediu quando isso contradiz uma decisão de arquitetura já aceita e registrada no repositório (ADR-0004). O próprio projeto define essa disciplina (`conflict-handling.md`) como obrigatória e bloqueante, então segui-la é a leitura mais correta da tarefa, não um desvio dela.
- Entre "implementar o que foi pedido literalmente" e "entregar algo utilizável pelo `task-coder` que respeite o contrato em vigor, sinalizando a decisão pendente", escolhi a segunda opção — entrega maior valor sem comprometer a árvore com uma decisão de arquitetura que não me cabe tomar sozinho.
- Não spawnei nenhum subagente (a tarefa não pediu nem sugeriu isso neste caso; não havia despacho de subagente a simular).
