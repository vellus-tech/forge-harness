# Despacho simulado (não executado)

Regra do ambiente de eval: subagentes reais não podem ser spawnados nesta execução. Este arquivo
registra exatamente as chamadas `Agent(...)` que o `data-engineer` faria pelo seu Protocolo (passo 5),
para que a síntese em `resposta-ao-usuario.md` possa ser auditada contra o que teria sido perguntado.

## 1. `data-cache`

```
Agent(subagent_type="data-cache", pergunta="""
Contexto mínimo: endpoint POST /recargas vai exigir header Idempotency-Key. A proposta
(docs/propostas/recarga-via-adquirente.md, item 1) guarda a chave de idempotência e a resposta
gravada SÓ no Redis de cache, política allkeys-lru, TTL 24h — para não criar coleção no MongoDB.
Pergunta: isso é armazenamento primário de estado de coordenação num store cuja política de eviction
(allkeys-lru) pode descartar a chave antes do TTL sob pressão de memória? Redis pode ser usado como
cache/acelerador nessa jornada, mas não como único lugar onde a chave de idempotência vive?
Rode: bash .forge/scripts/check-data-governance.sh --path docs/propostas/recarga-via-adquirente.md
      bash .forge/skills/data-cache-practices/scripts/scan.sh --root docs/propostas
""")
```

Resposta esperada (por `.forge/rules/data/data-cache.md`, que este agente já leu: "Nunca fonte de
verdade — todo dado em cache deve ser derivável/recuperável da fonte primária"): confirma antipattern.
allkeys-lru é política de eviction por escassez de memória, incompatível com garantia de idempotência;
mesmo sem escassez, Redis como único registro de "esta requisição já foi processada" é o store fazendo
o papel de fonte de verdade, o que a rule proíbe explicitamente.

## 2. `data-nosql` (dono do store durável, por não haver ADR de SQL neste projeto)

```
Agent(subagent_type="data-nosql", pergunta="""
Contexto mínimo: mesmo cenário acima. Pela data-governance.md ("transacional de negócio, eventos,
schema flexível, alto volume → MongoDB", H-01(a)) e pela regra de desempate 1 do orquestrador, o store
de idempotency key do REST deve ter dono durável — MongoDB por padrão neste projeto, sem ADR que
escolha SQL. Pergunta: desenho de coleção para idempotency key (chave = hash do Idempotency-Key +
rota, valor = status + resposta serializada), índice, TTL index nativo do Mongo para expurgo, e como
compor com Redis só como acelerador na frente (cache-aside, nunca grava sem o Mongo já ter gravado)?
Rode: bash .forge/scripts/check-data-governance.sh --path docs/propostas/recarga-via-adquirente.md
      bash .forge/skills/data-nosql-practices/scripts/scan.sh --root docs/propostas
""")
```

Resposta esperada (por `data-governance.md` + `.forge/rules/data/data-transactional-nosql.md`, que
prescreve write concern majority e filtro de tenant obrigatório): coleção dedicada com TTL index é a
forma padrão de idempotency key durável no Mongo; Redis cacheia a resposta já persistida, com fallback
seguro para o Mongo quando o cache falhar ou expirar antes da hora.

## 3. `data-streaming`

```
Agent(subagent_type="data-streaming", pergunta="""
Contexto mínimo: a proposta (item 2) cria o usuário adquirente-x DIRETO no cluster RabbitMQ interno,
vhost /recarga, com leitura na fila recarga.confirmada, e manda a credencial por e-mail. O item 3 diz
que o evento recarga.confirmada carrega numeroCartao completo porque a adquirente concilia por cartão.
Pergunta 1: dar a um parceiro externo usuário/ACL num vhost do cluster RabbitMQ interno é permitido sem
ADR, pela Regra de integração (.forge/rules/architecture/internal-grpc-communication.md e a seção
'Regra de integração' do data-engineer.md)? Pergunta 2: PAN completo (numeroCartao) num evento que um
terceiro consome — o que a rule T-02 exige antes disso ser aceitável?
Rode: bash .forge/scripts/check-data-governance.sh --path docs/propostas/recarga-via-adquirente.md
      bash .forge/skills/data-streaming-practices/scripts/scan.sh --root docs/propostas
""")
```

Resposta esperada: (1) vhost de parceiro no cluster interno só é admissível com ADR e limites
(`max-connections`, `max-queues`, `max-length`, `overflow`) — sem ADR, é a forma reprovada; a forma
válida por padrão é fila/tópico dedicado a parceiro num broker de borda separado, com relay/shovel
alimentando a partir do produto. Credencial por e-mail é canal sem controle de distribuição de
segredo — viola o princípio geral de `no-hardcoded-secrets.md` (credencial deve ir por cofre/rotação
controlada, não por canal fora de controle de acesso), mesmo não sendo "hardcoded em arquivo
versionado" no sentido literal da rule. (2) PAN completo em evento de outbox/fila é T-02: só é
aceitável se cifrado em nível de aplicação e com o broker inventariado como CDE — carga operacional
que não cabe em "esta semana" sem essa decisão explícita.
