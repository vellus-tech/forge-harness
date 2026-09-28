# Resposta do `data-streaming` — pedido de contrato do evento PedidoConfirmado

## Pergunta recebida

"O serviço de faturamento (services/faturamento) precisa emitir a fatura quando um pedido for confirmado pelo serviço de pedidos (services/pedidos). Desenhe o contrato do evento PedidoConfirmado e o consumidor Kafka do faturamento, com retry e DLT, para o task-coder implementar."

## Passo 1 — rules e decisões do projeto

Lidos, nesta ordem: `.forge/rules/data/*`, `.forge/rules/domain/money-as-cents.md`, `.forge/rules/architecture/internal-grpc-communication.md`, `.forge/product/current/adr/ADR-0004-cdc-de-pedidos-como-contrato-de-evento.md` e `.forge/product/current/adr/README.md` (único ADR do baseline, status Aceito).

O ADR-0004 decide: o contrato de evento de pedido para outros domínios é o tópico Kafka de CDC gerado pelo Debezium sobre `pedidos.public.pedidos`, no envelope padrão do Debezium (`before`/`after`/`op`/`ts_ms`). Não há tabela de outbox nem evento de domínio publicado pela aplicação de pedidos; consumidores leem o tópico de CDC direto e filtram `after.status`. Confirmado no código: `services/pedidos/src/repositorio.ts` faz apenas um `UPDATE` na tabela `public.pedidos` — não há publish de evento de domínio em lugar nenhum do serviço de pedidos.

## Passo 2 — conflito relevante

O pedido do usuário — "desenhe o contrato do evento **PedidoConfirmado**" — pressupõe um evento de domínio nomeado, publicado pela aplicação de pedidos, tipicamente via outbox e com contrato AsyncAPI próprio. Isso é exatamente o que a skill `data-streaming-practices` recomenda por padrão (checklist: "Outbox para todo evento que nasce de transação; CDC nunca como contrato público") e o antipattern **CDC-AP-02** ("Tabela interna exposta via CDC como contrato público") descreve como o cenário a evitar — que é precisamente o que o ADR-0004 decidiu fazer.

Pela `.forge/rules/conventions/conflict-handling.md`, este é um conflito **arquitetural relevante** (contrato de evento) — bloqueante. A ordem de precedência (`constitution > baseline/ADRs > rules > contexto/skill`) dá a decisão ao ADR-0004, não à recomendação padrão da skill. Portanto este agente **para** e não desenha um evento de domínio `PedidoConfirmado` nem uma tabela de outbox — isso contrariaria a fonte de maior autoridade.

```text
CONFLITO
decisão: contrato público do evento de confirmação de pedido para o consumidor de faturamento
posição A: o contrato é o tópico Kafka de CDC (Debezium) sobre `pedidos.public.pedidos`, envelope Debezium padrão, sem evento de domínio nem outbox — fonte: ADR-0004 (.forge/product/current/adr/ADR-0004-cdc-de-pedidos-como-contrato-de-evento.md), Aceito, 2026-03-12
posição B: evento de domínio `PedidoConfirmado` publicado via outbox transacional, com contrato AsyncAPI próprio — fonte: skill data-streaming-practices (checklist "Outbox/CDC" e antipattern CDC-AP-02, .forge/skills/data-streaming-practices/references/antipatterns.md)
precedência: ADR vence a skill pela ordem do FORGE.md §2.1 (constitution > baseline/ADRs > rules > contexto) — posição A prevalece
opções: aplicar a fonte de maior autoridade (recomendado: contrato = tópico de CDC, sem evento de domínio) | abrir ou atualizar ADR (revogar/substituir o ADR-0004 se a decisão de arquitetura deve mudar para outbox+AsyncAPI) | bloquear
registro: a decisão humana vai para approvals.yaml do change em curso, ou para um novo ADR — quem registra é a sessão principal ou o pipeline /forge:* em curso; este agente não registra
```

## O que este agente NÃO fez, por causa do conflito

Não desenhou schema/AsyncAPI de um evento de domínio `PedidoConfirmado`, não recomendou tabela de outbox em `services/pedidos`, e não escreveu o consumidor Kafka de faturamento — porque o formato de mensagem, o nome do tópico e a chave de partição do consumidor dependem diretamente de qual das duas posições vence (envelope Debezium vs. evento de domínio), e implementar em cima da posição errada seria descartável.

## O que este agente pode entregar assim que o HITL decidir

Se a decisão humana confirmar a posição A (aplicar o ADR-0004 como está): o consumidor de faturamento assina `pedidos.public.pedidos`, filtra `after.status === 'CONFIRMADO' && before.status !== 'CONFIRMADO'` (transição, não estado) para não reprocessar UPDATEs irrelevantes, com `enable.auto.commit=false`, `isolation.level=read_committed`, chave de partição = `after.id` (id do pedido, já que a chave do tópico de CDC do Debezium é a PK da tabela), retry não bloqueante (tópico de retry separado, backoff, redelivery limitado) e DLT após o limite de tentativas — evitando os antipatterns KFK-AP-01 (auto-commit) e KFK-AP-02 (acks/idempotência fracos) do catálogo. Isso fica pendente da resposta ao bloco CONFLITO acima.

Se a decisão humana optar por revogar o ADR-0004 em favor de outbox+AsyncAPI (posição B): este agente desenha o schema AsyncAPI do evento `PedidoConfirmado`, a tabela de outbox em `services/pedidos` e o relay, e então o consumidor Kafka de faturamento sobre o tópico de domínio — sujeito a novo ADR substituindo o ADR-0004, conforme exige `.forge/rules/conventions/conflict-handling.md` §1.

## Devolução ao orquestrador

Toda a pergunta é escopo deste agente (`data-streaming`): contrato de evento e consumidor Kafka. Não há parte para `data-relational`/`data-nosql` (a tabela `public.pedidos` já existe e não muda de schema por esta resposta) nem para `data-cache`. O passo que falta — a decisão humana sobre o CONFLITO acima — não é deste agente; quem conduz o HITL é a sessão principal / pipeline `/forge:*` em curso.
