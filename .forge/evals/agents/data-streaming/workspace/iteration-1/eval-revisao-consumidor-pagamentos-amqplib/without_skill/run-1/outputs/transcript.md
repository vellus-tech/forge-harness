# Transcript — eval-revisao-consumidor-pagamentos-amqplib / without_skill / run-1

## Contexto da tarefa

Pedido do usuário: fila `pagamentos` entrou em laço (mesma mensagem voltando sem parar), worker a 100% de CPU. Revisar `src/` e `infra/rabbitmq/` (RabbitMQ 4.1, cluster de 3 nós) e diagnosticar + entregar o trecho corrigido, sem alterar o repositório.

Executado como baseline `without_skill`: nenhuma leitura de `template/.forge/skills`, `template/.forge/agents`, `plugin` ou `.forge/evals` — apenas conhecimento próprio sobre amqplib/RabbitMQ.

## Passos executados

1. Bootstrap da árvore: `cd .../worktrees/evals-100 && pwd && git branch --show-current` — confirmou diretório e branch esperados (`chore/evals-skills-agentes`).
2. Gravado instante inicial em `.t0` (`date +%s`).
3. Criado `work/` e executado `setup.sh work` (fixture do caso `revisao-consumidor-pagamentos-amqplib`) para materializar o projeto de teste.
4. Localizados os arquivos alvo: `work/src/consumidor.js`, `work/src/pagamentos.js`, `work/infra/rabbitmq/policy.json`, `work/infra/rabbitmq/README.md` (confirma cluster RabbitMQ 4.1, 3 nós).
5. Leitura integral dos quatro arquivos.
6. Análise técnica (sem alterar nada em `work/`):
   - Identificado o bug central: `ch.consume('pagamentos', handler, { noAck: true })` combinado com chamadas manuais `ch.ack(msg)` / `ch.nack(msg)` dentro do handler — configuração contraditória do amqplib (com `noAck: true` o broker já trata a mensagem como confirmada na entrega; ack/nack manual depois disso é erro de protocolo / comportamento indefinido).
   - Identificado o mecanismo do laço relatado: `ch.nack(msg)` sem argumentos equivale a `requeue: true` por padrão; sem distinguir erro permanente de transitório, uma mensagem que falha de forma permanente (payload malformado, `pedidoId` inválido etc.) é reenfileirada e reentregue instantaneamente, falha de novo, indefinidamente — sem `ch.prefetch`, sem dead-letter exchange e sem limite de tentativas na policy, nada interrompe esse ciclo, explicando o laço e o consumo de CPU.
   - Verificado `infra/rabbitmq/policy.json`: usa `ha-mode: all` / `ha-sync-mode: automatic` (mirror de fila clássica). Esse mecanismo foi removido do RabbitMQ a partir da série 4.0 — em um cluster 4.1 essa policy não produz réplica nenhuma; achado adicional relevante para o pedido do usuário (cluster é 4.1, 3 nós).
   - Achados secundários: segunda conexão AMQP redundante em `pagamentos.js` (`canalDePublicacao`), ausência de handlers `error`/`close` em conexão/canal, ausência de idempotência no `publish` de `pedido.pago` (relevante ao reintroduzir retries corretos).
7. Redigido diagnóstico completo em `outputs/diagnostico.md`.
8. Escrito trecho corrigido de `consumidor.js` em `outputs/consumidor.corrigido.js`: `noAck: false` explícito, `ch.prefetch(1)`, classificação de erro permanente (nack sem requeue → DLQ) vs. transitório (nack com requeue), handlers de erro em conexão/canal.
9. Escrito trecho corrigido de `pagamentos.js` (validação de payload + classe `ErroPermanente`) em `outputs/pagamentos.trecho-corrigido.js`.
10. Escrita a policy corrigida (`dead-letter-exchange` + `delivery-limit`, removendo `ha-mode`/`ha-sync-mode` obsoletos) em `outputs/policy.corrigida.json`, com nota separada (`outputs/nota-quorum-queue.md`) explicando que `delivery-limit` exige a fila declarada como quorum queue (`x-queue-type: quorum` no `assertQueue`), já que a policy sozinha não migra o tipo de uma fila existente.
11. Nenhum arquivo dentro de `work/` foi modificado — apenas lido, conforme instrução do usuário ("não altere nada no repositório").
12. Nenhum subagente foi spawnado (instrução do harness); toda a análise foi feita diretamente.
13. Verificado tamanho de `work/` (~5,5 MB, abaixo do limite de 20 MB) — mantido, sem necessidade de apagar.
14. Ao final: lido `.t0`, calculado `t1 - t0` e escrito `timing.json` com `total_tokens: 0` (não medido nesta execução) e `duration_ms`/`total_duration_seconds` derivados do tempo decorrido.

## Entregáveis em `outputs/`

- `diagnostico.md` — diagnóstico completo (causa raiz + achados adicionais).
- `consumidor.corrigido.js` — versão corrigida de `src/consumidor.js`.
- `pagamentos.trecho-corrigido.js` — trecho corrigido de `src/pagamentos.js` (validação + classificação de erro).
- `policy.corrigida.json` — versão corrigida de `infra/rabbitmq/policy.json`.
- `nota-quorum-queue.md` — nota complementar sobre `x-queue-type: quorum` necessário para `delivery-limit` funcionar.
- `transcript.md` — este arquivo.
