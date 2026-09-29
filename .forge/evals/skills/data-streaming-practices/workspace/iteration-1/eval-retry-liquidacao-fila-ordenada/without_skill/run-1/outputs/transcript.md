# Transcript — eval-retry-liquidacao-fila-ordenada / without_skill / run-1

## 1. Leitura do contexto

Li os três arquivos do fixture antes de decidir qualquer coisa:

- `docs/contexto-liquidacao.md` — fila `liquidacao.lancamentos` é quorum com Single Active
  Consumer (SAC) porque a ordem por conta de lojista importa (débito/estorno/ajuste precisam
  chegar na sequência original); liquidante cai algumas vezes por semana, janelas de 1–15min; hoje
  o consumidor rejeita sem requeue (perde a mensagem); não há DLX; volume ~40k/dia, pico 30/s.
- `src/liquidacao/consumidor.js` — handler único, `prefetch(1)`, em `ErroTransitorio` faz
  `canal.reject(msg, false)` sem distinção nenhuma do caso de erro definitivo.
- `infra/rabbitmq/definitions.json` — fila quorum com `x-single-active-consumer: true`,
  `delivery-limit: 5` na política, mas sem `x-dead-letter-exchange` — ou seja, `delivery-limit`
  hoje não tem efeito prático nenhum porque a mensagem rejeitada não tem para onde ir.

## 2. Decisão central: a restrição de ordem descarta o padrão usual de delay-queue

O pedido do usuário citava "delayed retry nativo da quorum queue do RabbitMQ 4.3" com esperas de
5s/30s/5min. Não tenho confirmação confiável dessa feature específica nas notas do 4.3 para
desenhar em cima dela sem verificar — decidi não fingir certeza sobre isso e registrar a
incerteza explicitamente no desenho, em vez de inventar sintaxe de `definitions.json` para uma
feature que eu não sei se existe do jeito descrito.

O padrão clássico de retry com espera em RabbitMQ (filas de delay por estágio com TTL + DLX
devolvendo para a fila principal) foi meu primeiro instinto, mas descartei porque ele reordena:
enquanto o lançamento com erro espera do lado de fora da fila principal, lançamentos seguintes da
mesma conta (que chegaram depois) são consumidos primeiro — quebra exatamente a garantia que o
SAC foi desenhado para dar. Isso é a restrição que domina toda a decisão.

## 3. Desenho escolhido

Retry em memória, dentro do próprio handler, sem tirar a mensagem da fila: em `ErroTransitorio`,
em vez de `reject` imediato, aguardo 5s (1ª falha), 30s (2ª) e 5min (3ª), tentando de novo entre
cada espera, com a mensagem sempre unacked. Como o consumidor é único e `prefetch` é 1, nenhuma
outra mensagem avança enquanto isso acontece — ordem preservada sem precisar de fila auxiliar.
Erro não-transitório, ou esgotadas as 3 tentativas, vai para `reject(msg, false)`.

Também notei que sem DLX a mensagem rejeitada simplesmente desaparece hoje — adicionei uma DLX +
DLQ no `definitions.json` para que o `reject` final vire uma mensagem inspecionável, não uma
perda silenciosa.

Trade-off que registrei explicitamente no desenho: a fila inteira para de avançar durante a
espera (não só a conta afetada), mas como a indisponibilidade é da API do liquidante como um todo,
isso não piora o problema atual (hoje a mensagem é perdida; agora ela espera). Verifiquei que
`max-length: 200000` comporta várias horas de backlog no pico de 30/s, então a janela observada de
1–15min não estoura a fila.

## 4. Arquivos alterados

- `infra/rabbitmq/definitions.json` — adiciona exchange `liquidacao.lancamentos.dlx` (fanout) e
  fila `liquidacao.lancamentos.dlq` (quorum), aponta `x-dead-letter-exchange` da fila principal
  para a DLX. `delivery-limit: 5` mantido como rede de segurança de infraestrutura (reconexão
  durante a espera), não como mecanismo primário de retry.
- `src/liquidacao/consumidor.js` — loop de até 3 tentativas com `aguardar(ESPERAS_MS[tentativa])`
  entre elas (5s/30s/5min), mensagem só sai da fila em `ack` (sucesso) ou `reject` final.
- `docs/design-retry-liquidacao.md` — desenho completo: problema, restrição de ordem, desenho
  escolhido, trade-off aceito, por que `delivery-limit` sozinho não basta, alternativas
  descartadas (filas de delay, plugin `rabbitmq_delayed_message_exchange`, a feature nativa citada
  no pedido — não descartada por mérito, descartada por falta de confirmação), e pendências fora
  de escopo (alerta de DLQ, confirmação da feature 4.3, processo de reprocessamento manual).

## 5. O que não fiz

Não rodei nenhum comando de teste, build, git ou infraestrutura real — nenhum RabbitMQ de fato foi
tocado; isso é um exercício de desenho e edição de arquivo estático (`definitions.json` é
declarativo, não aplicado). Não instalei nem chamei nenhuma ferramenta externa.
