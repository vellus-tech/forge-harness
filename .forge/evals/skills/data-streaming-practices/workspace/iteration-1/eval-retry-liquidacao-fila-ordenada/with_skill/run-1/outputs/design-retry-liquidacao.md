# Retry do consumidor de liquidação — desenho

## Pedido original e por que ele não foi implementado ao pé da letra

O pedido era usar o `delayed-retry-type` nativo da quorum (RabbitMQ 4.3) com patamares de 5s, 30s e 5min na fila `liquidacao.lancamentos`. Essa fila é quorum com Single Active Consumer justamente porque débito, estorno e ajuste da mesma conta de lojista precisam chegar ao banco liquidante na ordem em que foram gerados — o liquidante recusa estorno de lançamento que ainda não recebeu.

O delayed retry nativo — e, pela mesma razão, uma fila de espera com TTL e DLX de volta — tira a mensagem da fila principal enquanto ela aguarda. Nesse intervalo, as mensagens seguintes da fila são entregues e processadas normalmente, ou seja, passam na frente da que está em retry. Numa fila que promete ordem isso quebra a garantia que a fila existe para dar: é o antipattern **RMQ-AP-26** (`.forge/skills/data-streaming-practices/references/antipatterns.md`), e a base é explícita — **RMQ-BP-23**: "em fila que promete ordem (SAC, consistent hash, super stream), erro transitório bloqueia a chave (retry no próprio consumidor, com teto) ou a mensagem vai ao parking lot e a chave fica marcada até a correção; nunca retry atrasado silencioso". Como o `scan.sh` só faz detecção estática de texto, este achado não aparece na varredura (RMQ-AP-26 é `Detecção: revisão`) — ficou por conta do julgamento desta análise, não do scanner.

Optei por retry dentro do próprio consumidor em vez do mecanismo nativo. Fica registrado aqui para quem revisar poder discordar da escolha, não só do código.

## Desenho adotado

**Erro transitório** (`ErroTransitorio`, banco liquidante indisponível): o consumidor tenta de novo sem soltar a mensagem — não faz `ack` nem `reject`, só espera e tenta de novo dentro do mesmo handler. Com `prefetch(1)` e Single Active Consumer, a fila já serializa a entrega: a mensagem seguinte só é entregue depois que esta for resolvida (`ack` ou `reject`). Os patamares pedidos (5s, 30s, 5min) viram os primeiros três intervalos de espera; a partir do quarto, o consumidor continua tentando a cada 5min (o pedido chama isso de "espera de 5min", eu leio como o teto da progressão, não como o fim das tentativas) com jitter de até 3s por chamada — a base recomenda jitter no cliente para retry de chamada remota, porque o retry nativo (que não estamos usando) é linear e sem jitter.

Isso significa que o consumidor não desiste sozinho de uma mensagem só porque o liquidante ficou fora por mais que o teto: como a indisponibilidade descrita no contexto (`docs/contexto-liquidacao.md`) afeta a API inteira, não uma conta específica, bloquear a fila inteira até o liquidante voltar é o comportamento certo — continuar processando as próximas mensagens em paralelo não é uma opção, porque elas ficariam à frente desta na ordem que o liquidante exige.

**Erro permanente** (qualquer erro que não seja `ErroTransitorio` — dado inválido, regra de negócio): não entra no laço de retry. Vai direto para `reject(msg, false)`, sem requeue (por isso nunca `requeue=true` — esse é exatamente o RMQ-AP-10, requeue infinito, que o código evita desde a versão anterior). Tratado como poison message (RMQ-BP-11): incidente pontual, não o caminho normal do liquidante fora do ar.

## Topologia (`infra/rabbitmq/definitions.json`)

A fila não tinha DLX — **RMQ-AP-11** (sem DLX, erro permanente some em silêncio) e, mais grave neste caso, **RMQ-AP-23** (`delivery-limit` sem DLX: desde o RabbitMQ 4.0 o `delivery-limit` padrão da quorum é 20, e a policy já tinha um explícito de 5; sem DLX, a mensagem que estoura esse limite — por exemplo, um consumidor que crasha em loop no meio de um retry — é descartada sem deixar rastro). Corrigido:

- Exchange `liquidacao.dlx` (direct, durável) e fila `liquidacao.parking` (quorum, durável), ligadas entre si.
- Policy da `liquidacao.lancamentos` ganhou `dead-letter-exchange: liquidacao.dlx`, `dead-letter-strategy: at-least-once` e `overflow: reject-publish` (o padrão do `overflow` é `drop-head`, que descarta a mensagem mais antiga em silêncio ao encher — RMQ-AP-24 — e só fica visível para quem publica com confirms).
- `dead-letter-strategy: at-least-once` exige a feature flag `stream_queue` habilitada no cluster. É um pré-requisito operacional, não coberto por este patch — confirmar com `rabbitmqctl list_feature_flags` antes de aplicar as `definitions.json` em produção.
- A fila `liquidacao.parking` precisa de dono e alerta de profundidade > 0 (RMQ-BP-11); provisionar isso é runtime/operação e fica fora do escopo deste patch — o scanner e este diff não cobrem alerta de fila, só a topologia.

## O que fica em aberto (não implementado aqui)

- **Ordem depois de uma mensagem parqueada.** Se uma mensagem cair na DLX por erro permanente, o consumidor segue para a próxima — o que preserva a ordem *global* da fila, mas não garante que a conta da mensagem parqueada não tenha um lançamento seguinte processado antes da correção manual dela. Hoje o consumidor não sabe rastrear "contas bloqueadas"; se isso for um requisito de negócio (parece ser, dado "o liquidante recusa estorno de lançamento que ele ainda não recebeu"), é um registro de contas bloqueadas a mais — não fiz porque o pedido não mencionou reprocesso de parking lot, e é decisão de produto, não só de mensageria. Sinalizado aqui para o time decidir, não decidido por mim.
- Alerta de profundidade da `liquidacao.parking` e confirmação da feature flag `stream_queue` são runtime — ficam para quem tem acesso ao cluster, como o próprio catálogo da skill documenta ("O que o scanner não faz").

## Fontes

`.forge/skills/data-streaming-practices/references/best-practices.md` — RMQ-BP-11, RMQ-BP-12, RMQ-BP-20, RMQ-BP-21, RMQ-BP-23; `.forge/skills/data-streaming-practices/references/antipatterns.md` — RMQ-AP-10, RMQ-AP-11, RMQ-AP-17, RMQ-AP-23, RMQ-AP-24, RMQ-AP-26.
