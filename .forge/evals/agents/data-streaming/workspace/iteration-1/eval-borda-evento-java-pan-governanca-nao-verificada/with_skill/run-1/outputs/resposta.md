# Revisão do evento `PagamentoAprovado` — resposta do `data-streaming`

## Veredito

Não registre o schema como está. Há um bloqueante de PCI DSS (T-02) e uma lacuna operacional de RabbitMQ que, juntos, tornam o contrato atual não seguro para produção — mesmo sendo só um registro de schema amanhã, ele fixa publicamente a forma do evento e todo consumidor futuro passa a depender do PAN circulando em claro.

## Achados (ordenados por severidade)

### 1. T-02 — PAN em claro no schema do evento (bloqueante, PCI DSS Req. 3) [scan.sh T-02, confirmado]

`src/main/resources/avro/PagamentoAprovado.avsc:7` declara `{ "name": "pan", "type": "string" }`, e `PagamentoAprovadoPublisher.java:19` preenche esse campo com `pagamento.getCartao().getNumero()` — o PAN completo, sem mascaramento nem tokenização.

Por quê importa: fila quorum, stream, tópico, DLQ e parking lot são armazenamento persistente (`RabbitMQ`, disco, backup, réplica). Publicar o PAN em claro no evento estende o escopo de CHD (cardholder data environment) da PCI DSS 4.0.1 para o broker inteiro — todos os nós do cluster, backups e qualquer DLQ que retenha a mensagem. Isso muda materialmente a superfície de auditoria PCI da Vellus/Axis.

Correção: o evento carrega um token opaco (`panToken`) emitido pelo ponto de tokenização — tipicamente o gateway de pagamento/adquirente ou um serviço de tokenização dedicado — nunca o PAN. O domínio de conciliação (`ConciliacaoListener`) deve operar só com token; se precisar do PAN mascarado para exibição, usa `last4` derivado do token, nunca o campo bruto.

Não há `data-classification.json` no projeto (procurei; só existe o schema de referência, não uma instância) — então o campo `pan` também está sem entrada de classificação/mascaramento declarada, o que é finding independente pela `pii-pci-classification.md` (campo sensível sem entrada no mapa = classificação incorreta, não omissão neutra).

### 2. PII sem tratamento declarado: `nomeTitular` e `cpfTitular` no evento [Julgamento manual — scanner não tem antipattern específico para PII fora do PAN]

Os mesmos campos que carregam o nome e o CPF do titular do cartão trafegam em claro no evento, sem `data-classification.json` e sem estratégia de pseudonimização. Não é bloqueante do mesmo jeito que o PAN (não é CHD), mas é dado LGPD sujeito a retenção e minimização: se `ConciliacaoListener` não precisa do nome/CPF para conciliar (normalmente basta um identificador de cliente e o token), a recomendação é remover os dois do evento e resolver via lookup no serviço dono, não propagar PII por fan-out.

### 3. RMQ-AP-28 — sem `default-requeue-rejected: false`, requeue infinito na prática [scan.sh RMQ-AP-28, confirmado]

`src/main/resources/application.yml` configura `listener.simple.acknowledge-mode: auto` e não define `default-requeue-rejected: false`. O default do Spring AMQP é `true`: uma exceção não tratada em `ConciliacaoListener.onPagamentoAprovado` faz a mensagem voltar para a fila e ser reentregue indefinidamente (RMQ-AP-10 implícito) — sem DLX visível no projeto (não há declaração de fila/exchange, `x-dead-letter-exchange` ou `delivery-limit` em lugar nenhum do código lido), a fila `conciliacao.pagamento-aprovado` também não tem um caminho de saída para mensagem envenenada.

Correção: `spring.rabbitmq.listener.simple.default-requeue-rejected: false` **e** DLX com `delivery-limit` na declaração da fila (fila quorum, para dado de negócio) — nunca um dos dois isolado: sem DLX, `false` descarta a mensagem (perda silenciosa); sem `false`, o DLX nunca é acionado por exceção do listener.

### 4. Publisher confirms configurado mas não observado no código [Julgamento manual]

`application.yml` liga `publisher-confirm-type: correlated`, mas `PagamentoAprovadoPublisher.publicar` chama `rabbitTemplate.convertAndSend(...)` sem `CorrelationData` e sem `ConfirmCallback`/`ReturnsCallback` registrado no `RabbitTemplate`. O ack do broker existe no protocolo, mas ninguém no código trata falha de confirm nem mensagem sem rota (`mandatory` + `ReturnsCallback`) — na prática, o publish é fire-and-forget apesar da config sugerir o contrário. Isso é gap operacional, não bloqueante de PCI, mas relevante para a garantia de entrega que a conciliação financeira presume.

### 5. Evento sem contrato AsyncAPI (SCH-AP-04) [Julgamento manual — não há artefato AsyncAPI no projeto]

A regra de integração da casa (`internal-grpc-communication.md`, refletida no protocolo deste agente) exige que todo evento assíncrono interno tenha contrato AsyncAPI versionado e schema registrado. Não encontrei `asyncapi.yaml`/`.yml` no projeto. Registrar o `.avsc` isoladamente no schema registry, sem o AsyncAPI documentando canal, binding RabbitMQ e o contrato dos dois lados (publicador/consumidor), deixa o consumidor futuro sem onde descobrir a forma do evento fora do próprio schema bruto.

### 6. Observação de compatibilidade de schema (não bloqueante)

Nenhum campo do `.avsc` tem `default`. Isso não quebra o registro amanhã, mas qualquer evolução futura em modo `BACKWARD` (o padrão recomendado) que adicione campo terá que vir com `default` explícito desde já — vale já nascer com o hábito, e com `doc` por campo, já que o registro é o ponto de não-retorno de "documentação implícita = o schema".

### 7. Fora do escopo direto deste agente, mas para registrar

`valor` é `double` no `.avsc` e no builder (`pagamento.getValor().doubleValue()`). Ponto flutuante em valor monetário é o antipattern clássico de arredondamento; a rule `domain/money-as-cents.md` da casa não lista `backend-java` em `applies_to` (lista `.NET`, React, Android), então tecnicamente não bloqueia por essa rule específica neste stack — mas o princípio (inteiro em centavos, nunca `double`/`float`/`decimal` em domínio financeiro) é o mesmo e vale trazer para decisão humana. Quem decide o tipo de dado no domínio de pagamento é `data-relational`/o dono do agregado `Pagamento`, não este agente — sinalizo e devolvo.

## Recomendação objetiva

Não registrar amanhã. Ordem sugerida antes do registro:
1. Tokenizar o PAN na borda (produtor) — campo `panToken`, remover `pan` do `.avsc`.
2. Remover ou substituir `nomeTitular`/`cpfTitular` por um identificador que não exponha PII, ou declarar e justificar em `data-classification.json` com `masking`/pseudonimização se o consumidor realmente precisa do dado bruto.
3. `default-requeue-rejected: false` + fila quorum com DLX e `delivery-limit` para `conciliacao.pagamento-aprovado`.
4. `CorrelationData` + `ConfirmCallback`/`ReturnsCallback` no `RabbitTemplate`, ou decisão explícita de aceitar fire-and-forget (registrar por quê).
5. Contrato AsyncAPI do canal antes ou junto do registro do schema no registry.
6. Depois disso, registrar com compatibilidade `BACKWARD` e cada campo com `default` e `doc`.

## Verificação executada

- `check-data-governance.sh --path src`: `FAIL data-governance/universo-vazio` — o verificador só lê `.go/.kt/.ts/.rego/.py/.md`; em projeto Java isso é esperado e **não** é aprovação nem conflito — PAN/PII não foi verificado por esse gate especificamente (fiquei com o detector da skill e a revisão manual abaixo).
- `scan.sh --root src`: 4 arquivos varridos, achados `RMQ-AP-28` e `T-02` (linhas citadas acima); demais 30 antipatterns do catálogo, `OK`.
- Procurei `data-classification.json` e artefato AsyncAPI no projeto: nenhum dos dois existe.

## Devolução ao orquestrador

Este agente cobriu: topologia RabbitMQ (DLX/requeue), publisher confirms, contrato/schema do evento (AsyncAPI, Avro) e o antipattern T-02 (PAN em evento). Não cobri: a modelagem do agregado `Pagamento` e o tipo de `valor` no store relacional (`data-relational`), nem a política de retenção/pseudonimização de PII fora do escopo deste evento (se o time quiser um desenho LGPD completo, acionar o orquestrador `data-engineer` para trazer `data-relational` junto).
