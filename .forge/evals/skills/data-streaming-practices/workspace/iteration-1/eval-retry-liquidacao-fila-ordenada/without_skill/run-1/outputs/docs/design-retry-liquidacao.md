# Desenho: retry de lançamentos para o banco liquidante

## Problema

A fila `liquidacao.lancamentos` é quorum com Single Active Consumer porque débito, estorno e
ajuste da mesma conta de lojista precisam chegar ao banco liquidante na ordem em que foram
gerados. A API do liquidante cai algumas vezes por semana, por 1 a 15 minutos. Hoje o consumidor
(`src/liquidacao/consumidor.js`) rejeita a mensagem sem requeue nesse caso — o lançamento é
perdido, porque não há dead-letter-exchange configurada.

O pedido original era usar "o delayed retry nativo da quorum queue do RabbitMQ 4.3" com esperas de
5s, 30s e 5min. **Não consegui confirmar essa feature nas notas de release do 4.3 com confiança
suficiente para apostar a liquidação nela** — não vou marcar como verificado algo que não pude
checar. Por isso, o desenho abaixo usa apenas mecanismos que já estão em uso neste projeto
(quorum queue, `delivery-limit`, DLX) e retry em memória no próprio consumidor, e sinaliza como
alternativa a rota com filas de delay (TTL + DLX) caso a feature nativa exista e seja confirmada
depois.

## Restrição que domina a decisão: ordem por conta

Qualquer desenho que tire a mensagem com falha da fila principal e a devolva depois (fila de
espera com TTL, exchange de delay, etc.) quebra a garantia de ordem: enquanto o lançamento com
falha espera do lado de fora, lançamentos seguintes da mesma conta — que chegaram depois, na fila
principal — são consumidos primeiro. Isso é exatamente o cenário que o Single Active Consumer foi
desenhado para evitar.

Descartei o padrão clássico de "3 filas de delay com TTL + DLX apontando de volta para a fila
principal" por esse motivo, mesmo sendo a forma mais comum de implementar retry com espera em
RabbitMQ. Ele resolve retry, mas não resolve retry mantendo a ordem por conta.

## Desenho escolhido: espera dentro do próprio handler, mensagem sempre unacked

Quando `enviarAoLiquidante` lança `ErroTransitorio`, o consumidor não faz `ack` nem `reject` da
mensagem. Ele aguarda (5s na 1ª falha, 30s na 2ª, 5min na 3ª) e tenta de novo, dentro do mesmo
handler. A mensagem some da fila (do ponto de vista do broker) só quando:

- dá certo (`ack`), ou
- esgotam as 3 tentativas locais, ou o erro não é transitório (`reject(msg, false)` → vai para a
  DLQ via `x-dead-letter-exchange`, que hoje não existia e foi adicionada).

Como o consumidor é único (`x-single-active-consumer: true`) e o `prefetch` é 1, nenhuma outra
mensagem da fila é entregue enquanto esse handler está esperando. A ordem por conta de lojista
fica preservada de graça — não porque o RabbitMQ garanta ordem entre filas, mas porque só existe
um lançamento em voo por vez, sempre o mais antigo da fila.

### Trade-off aceito

Durante uma queda do liquidante, a fila inteira para de avançar, não só os lançamentos da conta
afetada. Como a indisponibilidade é da API do liquidante como um todo (não por conta), isso não
piora o problema — hoje, sem retry nenhum, os lançamentos são descartados; com este desenho, eles
esperam e a fila cresce. Volume é ~40 mil/dia, pico de 30/s; `max-length: 200000` na política
atual comporta várias horas de backlog nesse ritmo, então uma janela de 1 a 15 minutos (o range
observado) não estoura a fila. Se a soma das esperas (5s+30s+5min ≈ 5min35s) não for suficiente
para o liquidante voltar, o lançamento vai para a DLQ e passa a exigir reprocessamento manual —
isso precisa de um alerta (não incluído neste change; ver "Pendências").

### Por que não usar `delivery-limit` (já configurado) para o retry inteiro

A política já tem `delivery-limit: 5`, que hoje não tem efeito prático porque não há DLX (a
mensagem rejeitada sem requeue simplesmente desaparece). `delivery-limit` conta reentregas depois
de `nack`/`reject` com requeue, mas cada reentrega volta imediatamente para o topo da fila — não
dá para encaixar 5s/30s/5min nele sem sair do fluxo linear (teria que reprocessar do zero e
inferir o número da tentativa por um header, o que a client library usada aqui não expõe de forma
direta). Por isso ele foi mantido apenas como rede de segurança de infraestrutura (ex.: conexão
cai no meio da espera, o broker reentrega quando o consumidor volta) e não como o mecanismo
primário de retry — o mecanismo primário é o loop em memória descrito acima.

## Mudanças

- `infra/rabbitmq/definitions.json`: adiciona `liquidacao.lancamentos.dlx` (fanout) +
  `liquidacao.lancamentos.dlq` (quorum) e aponta `x-dead-letter-exchange` da fila principal para
  ela. Hoje uma mensagem rejeitada é perdida; com isso, vai para uma fila inspecionável.
- `src/liquidacao/consumidor.js`: troca o `reject` imediato em `ErroTransitorio` por um loop de
  até 3 tentativas com espera de 5s, 30s e 5min entre elas, mantendo a mensagem sem ack durante
  todo o processo. Erros não-transitórios continuam indo direto para a DLQ, sem espera.

## Alternativas descartadas

1. **Filas de delay (TTL + DLX) por estágio, devolvendo para a fila principal.** Padrão mais
   comum para retry com espera em RabbitMQ, mas quebra a ordem por conta (ver acima). Só voltaria
   a ser viável se o consumo fosse particionado por conta de lojista (ex.: routing key por conta +
   múltiplas filas), o que é uma mudança maior e não pedida aqui.
2. **Plugin `rabbitmq_delayed_message_exchange`.** Resolve o delay, mas é plugin comunitário (não
   nativo), teria que ser instalado no cluster, e ainda tem o mesmo problema de ordem do item 1 se
   usado para devolver a mensagem à fila principal por fora do fluxo do SAC.
3. **"Delayed retry nativo da quorum queue" citado no pedido.** Não descartado por mérito — não
   encontrei confirmação suficiente da feature específica no RabbitMQ 4.3 para desenhar em cima
   dela sem verificar primeiro. Se ela existir e preservar a semântica de entrega ordenada do SAC
   (o que precisaria ser confirmado na documentação oficial da versão instalada), é provavelmente
   preferível ao loop em memória deste desenho, porque não deixa o processo do consumidor bloqueado
   em `await` por até 5 minutos. Fica como próximo passo antes de ir para produção.

## Pendências (fora do escopo deste change)

- Alerta/observabilidade quando uma mensagem cai na DLQ (hoje ninguém é avisado).
- Confirmar com a documentação oficial do RabbitMQ 4.3 instalado se existe mesmo o delayed retry
  nativo em quorum queues e, se existir, reavaliar este desenho contra ele.
- Definir processo de reprocessamento manual da DLQ (replay para a fila principal, respeitando a
  ordem por conta).
