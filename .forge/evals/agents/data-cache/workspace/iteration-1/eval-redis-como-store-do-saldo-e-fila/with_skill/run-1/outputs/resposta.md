# Resposta do data-cache ao pedido "Redis como store do saldo e fila"

## CONFLITO

```text
CONFLITO
decisão: tirar o saldo da carteira do PostgreSQL e manter apenas no Redis (Redis vira armazenamento primário do débito)
posição A: saldo (em centavos) e extrato de movimentação permanecem no PostgreSQL do serviço carteira, com débito transacional e idempotency key por validação; cache, se houver, é cópia derivada e nunca decide débito — fonte: .forge/product/current/adr/ADR-0003-saldo-da-carteira-no-postgresql.md, reforçada por .forge/rules/data/data-cache.md ("Nunca fonte de verdade — todo dado em cache deve ser derivável/recuperável da fonte primária") e por .forge/rules/data/data-governance.md ("Cache/performance, dado derivável e descartável → Redis/Memcache (nunca fonte de verdade)")
posição B: mover o saldo do Postgres para o Redis, com AOF everysec e réplica, para que o débito na catraca seja decidido no Redis com latência sub-milissegundo — fonte: pedido do usuário nesta conversa
precedência: baseline/ADRs > rules > contexto — ADR-0003 é decisão de baseline aceita e vence o pedido pela ordem do FORGE.md §2.1
opções: aplicar a fonte de maior autoridade (recomendado — manter o débito no PostgreSQL) | abrir ou atualizar ADR (uma nova decisão formal que revogue o ADR-0003, com quem tem autoridade sobre o baseline) | bloquear
registro: a decisão humana vai para approvals.yaml do change em curso, ou para um novo ADR — quem registra é a sessão principal ou o pipeline /forge:* em curso; este agente não registra e não escreveu nada na árvore
```

Catálogo: C-07 — Cache como fonte da verdade (o Redis com AOF/réplica decidindo o débito é exatamente o padrão que C-07 bloqueia: "o pedido que insiste em Redis como primário vira CONFLITO").

Por isso **não** entrego `appendonly yes`/`appendfsync everysec`/`save`/desenho de chave de saldo como solução a aplicar. Essa parte do pedido está fora do meu escopo enquanto o ADR-0003 não for revisto.

## A fila das validações (LPUSH/BRPOP) não é meu domínio

Fila e job — mesmo usando o mesmo Redis, com `LPUSH`/`BRPOP` — são domínio do `data-streaming`, não do `data-cache`. Colocar fila e cache na mesma instância é o antipattern **C-13** do catálogo (`.forge/skills/data-cache-practices/references/antipatterns.md`): "fila, lock ou sessão que somem sob pressão de memória", porque a política de eviction de uma instância de cache não distingue cópia de estado durável. A correção do catálogo é "instâncias separadas; estado durável fora do cache (fila é do especialista de mensageria)".

Encaminho a fila ao `data-streaming` (matriz do `data-engineer`, `.forge/agents/data/data-engineer.md`) e, se a fila mensagens/eventos internos, aplica-se ainda a regra de integração: evento assíncrono interno vai por mensageria com contrato AsyncAPI e schema registrado — LPUSH/BRPOP não tem isso nativamente, ponto que o `data-streaming` deve avaliar.

## O que é meu e posso oferecer

Dentro do escopo do `data-cache`, sem contradizer o ADR-0003, posso desenhar **cache de leitura** do saldo (cópia derivada, não decide débito):

- Padrão: cache-aside. Leitura tenta `GET tenant:{tenant_id}:carteira:{cartao_id}:saldo`; miss lê o PostgreSQL e popula o cache; a catraca sempre confirma o débito no banco (via gRPC interno ao serviço carteira, síncrono, conforme a regra de integração — REST/gRPC interno, não fila, para a decisão transacional).
- Chave: `tenant:{tenant_id}:carteira:{cartao_id}:saldo` — namespace de tenant obrigatório pela `data-cache.md` e pela matriz da `data-governance.md`.
- TTL curto e explícito (ex.: alguns segundos, com jitter se a carga for em lote), coerente com "Leitura de saldo quente pode ter cache com TTL curto" do próprio ADR-0003.
- Invalidação: delete da chave depois do commit da escrita no Postgres (nunca antes) — C-01 do catálogo.
- Sem PAN/CVV/track data e sem PII sem máscara na chave ou no valor (T-01, T-04) — o saldo em centavos não é PAN, mas o `cartao_id` na chave não deve ser o PAN nem um identificador reversível para PAN.
- `maxmemory` explícito com política `allkeys-lru`/`allkeys-lfu` (C-10) e instância de cache separada da futura fila (reforça o C-13 acima).
- Degradação graciosa: se o cache cair, a leitura cai para o Postgres — nunca bloqueia o fluxo.

Essa é a parte que decido eu; a escolha do store durável do saldo (permanecer no PostgreSQL conforme ADR-0003, ou trocar por NoSQL, o que exigiria revisar o próprio ADR) e o desenho da fila de validações das catracas (Redis Streams/LPUSH-BRPOP ou outro broker, com contrato de mensagem) ficam com o orquestrador/`data-engineer` e os especialistas `data-relational` (ou `data-nosql`, se a decisão mudar) e `data-streaming`.
