Não dá para seguir com a proposta como está nesta semana — três pontos colidem com rule/regra do
projeto e cada um é relevante o bastante (isolamento de dado durável, segurança de acesso de terceiro,
dado de cartão) para exigir decisão antes de implementar, não registro e segue.

classificação: trabalho assíncrono, idempotência de consumidor / evento de domínio semiestruturado +
lookup de chave curta / Redis (cache), MongoDB (store durável, sem ADR de SQL neste projeto),
RabbitMQ — especialistas: `data-cache`, `data-nosql`, `data-streaming`.

## CONFLITO 1 — onde vive a idempotency key

```text
CONFLITO
decisão: onde persiste a chave de idempotência (e a resposta gravada) do POST /recargas
posição A: store durável (MongoDB, por não haver ADR que escolha SQL neste projeto — data-governance.md:
  "transacional de negócio, eventos, schema flexível, alto volume → MongoDB") com índice TTL para
  expurgo; Redis entra só como acelerador na frente, nunca como único registro — fonte:
  .forge/rules/data/data-governance.md, .forge/rules/data/data-cache.md ("Nunca fonte de verdade —
  todo dado em cache deve ser derivável/recuperável da fonte primária") e a regra de desempate 1 do
  data-engineer.md
posição B: chave e resposta só no Redis, allkeys-lru, TTL 24h — fonte: docs/propostas/recarga-via-
  adquirente.md, item 1
precedência: rule vence (nenhum ADR do projeto sustenta a exceção) — posição A
opções: aplicar a fonte de maior autoridade (recomendado) | abrir/atualizar ADR | bloquear
registro: a decisão humana vai para approvals.yaml do change em curso, ou para ADR — quem registra é
  a sessão principal, o humano ou o pipeline /forge:* em curso; este agente não registra
```

Além do conflito com a rule, `allkeys-lru` é uma política de **eviction por escassez de memória** —
sob pressão, a chave pode sumir antes das 24h mesmo sem nada de errado no fluxo. Uma recarga que falha
na rede e é reenviada pelo cliente depois da eviction deixa de ser idempotente: risco de cobrança
duplicada, que é exatamente o problema que o header foi introduzido para evitar.

## CONFLITO 2 — credencial de parceiro dentro do cluster RabbitMQ interno

```text
CONFLITO
decisão: como a adquirente parceira recebe a confirmação de recarga
posição A: fila/tópico dedicado ao parceiro num broker ou cluster de borda separado do interno, com
  usuário, credencial e ACL só dele, alimentado por um publicador do produto (relay, shovel ou
  federation); vhost de parceiro no cluster interno só é admissível com ADR e limites
  (max-connections, max-queues do vhost; max-length e overflow nas filas do parceiro) — fonte: seção
  "Regra de integração" do data-engineer.md e .forge/rules/architecture/internal-grpc-communication.md
  (exceções sempre por ADR)
posição B: criar o usuário adquirente-x direto no cluster RabbitMQ interno, vhost /recarga, com
  permissão de leitura em recarga.confirmada, sem ADR — fonte: docs/propostas/recarga-via-
  adquirente.md, item 2
precedência: rule vence (sem ADR que abra a exceção) — posição A
opções: aplicar a fonte de maior autoridade (recomendado) | abrir/atualizar ADR | bloquear
registro: a decisão humana vai para approvals.yaml do change em curso, ou para ADR — quem registra é
  a sessão principal, o humano ou o pipeline /forge:* em curso; este agente não registra
```

À parte do conflito com a rule: dar a um terceiro credencial e rota de rede para dentro do cluster
interno tem um efeito colateral concreto — os alarmes de memória/disco do RabbitMQ bloqueiam os
publicadores de **todo o cluster**, não só do vhost do parceiro; um incidente do lado da adquirente
pode travar a fila de outros fluxos internos. E mandar a credencial por e-mail é canal sem rotação
nem controle de acesso — mesmo não sendo "segredo versionado" no sentido literal de
`.forge/rules/conventions/no-hardcoded-secrets.md`, viola o mesmo princípio (credencial deve trafegar
por cofre com rotação, nunca por canal fora de controle).

## CONFLITO 3 — PAN completo no evento consumido por terceiro

```text
CONFLITO
decisão: o evento recarga.confirmada carrega numeroCartao completo (PAN) para a adquirente conciliar
posição A: PAN em fila/tópico/evento é T-02 (checklist do data-engineer.md): só é aceitável cifrado em
  nível de aplicação, com o broker inventariado como CDE (PCI DSS); reconciliação por token/id de
  transação ou PAN mascarado (últimos 4 dígitos) é o padrão que evita levar o CDE para dentro do
  broker de mensageria — fonte: checklist transversal do data-engineer.md (T-02) e
  .forge/rules/architecture/pii-pci-classification.md (fronteira de tokenização: "o PAN real nunca
  circula além do serviço/componente responsável pela tokenização")
posição B: numeroCartao completo no evento, porque a adquirente concilia por cartão — fonte:
  docs/propostas/recarga-via-adquirente.md, item 3
precedência: rule vence — posição A, com a alternativa explícita de reconciliar por token
opções: aplicar a fonte de maior autoridade (recomendado, i.e. trocar PAN por token/last4) | abrir
  ADR que aceite o PAN cifrado + inventário do broker como CDE | bloquear
registro: a decisão humana vai para approvals.yaml do change em curso, ou para ADR — quem registra é
  a sessão principal, o humano ou o pipeline /forge:* em curso; este agente não registra
```

Isso combina com o CONFLITO 2: se a fila do parceiro entra no CDE, o cluster inteiro (ou o broker de
borda dedicado, se for o desenho escolhido) herda o escopo PCI — auditoria, segmentação de rede e
controles de Req. 3/4 passam a valer para ele. Vale checar com o time de adquirência se eles aceitam
reconciliar por um identificador que não seja o PAN (a maioria dos parceiros de adquirência já opera
assim); é a saída mais barata das três.

## Checklist transversal aplicado

- **Dado sensível (PCI DSS):** PAN no evento (CONFLITO 3) é o achado central; não há
  `data-classification.json` no projeto ainda — trate a ausência como "não verificado", nunca como
  aprovação implícita, e declare `numeroCartao`/`Idempotency-Key`/resposta gravada no
  `data-classification.schema.json` antes de prosseguir.
- **T-04, log:** a resposta gravada em cache (item 1) e a chave de idempotência não podem vazar para
  slowlog/APM; se o valor derivar de dado de cartão, mascare antes de logar.
- **Multi-tenant:** a proposta não menciona tenant nem na chave do Redis nem na coleção de
  idempotência — se o produto é multi-tenant, falta o namespacing (`tenant:{id}:...` no Redis,
  `data-governance.md`) e o filtro de repositório (MongoDB).
- **Reversibilidade:** trocar de Redis-único para Mongo+Redis depois de já estar em produção exige
  migração de dados em voo; decidir agora é mais barato que corrigir depois de duplicidade real.
- **Operação:** o novo store durável e a fila de parceiro entram com backup testado, monitoramento e
  runbook antes do go-live — nenhum dos dois está descrito na proposta.

## Recomendação

Como está, a proposta não pode ir para implementação "ainda esta semana" sem decisão humana nos três
pontos acima — todos são conflito relevante pela `.forge/rules/conventions/conflict-handling.md`
(isolamento de dados / segurança/auth / estratégia de persistência) e por isso bloqueantes, não
"registra e segue". O caminho mais rápido, aplicando a fonte de maior autoridade em vez de abrir ADR
novo, é: (1) idempotency key em coleção Mongo com TTL index, Redis só como acelerador; (2) fila
dedicada ao parceiro num broker/cluster de borda separado (ou ADR expresso com limites, se o time
decidir manter o vhost no cluster interno) e credencial entregue por cofre, não e-mail; (3) evento
`recarga.confirmada` levando token/id de transação ou PAN mascarado em vez do número completo. Nenhum
desses três é um redesenho grande — o risco real é implementar o rascunho atual esta semana e ter que
desfazer duplicidade de cobrança ou reportar um incidente de escopo PCI depois.
