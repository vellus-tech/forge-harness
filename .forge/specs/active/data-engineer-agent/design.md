# Design — data-engineer-agent

> Design técnico do change `data-engineer-agent`. Fonte canônica do que se entrega: `template/.forge/**`. Base de conhecimento: `research/base-consolidada.md` deste change (julgada em 2026-09-26; cópia fiel do insumo); as referências a "base §N" apontam para ela. As decisões estão numeradas D-01 a D-10 e consolidadas no §3.

## 1. Contexto e restrições

- **Plataforma de subagentes (conferido em 2026-09-26 na documentação do Claude Code, `code.claude.com/docs/en/sub-agents`):** um subagente pode criar subagentes até três níveis abaixo da conversa principal (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`); `tools: Agent(a, b)` é allowlist dos tipos que ele pode criar (`Task` é alias legado); o campo `skills` pré-carrega skills no contexto do subagente; `.claude/agents/` é varrido recursivamente, então `agents/data/` funciona como as categorias existentes.
- **Projeção e distribuição já existem:** `sync-adapters.mjs` copia `agents/**` para `.claude/agents/` e `skills/**` para `.claude/skills/` e `.agents/skills/`; `bin/forge.mjs` trata `agents` e `skills` como maquinaria (`MACHINERY_DIRS`) e como diretórios enriquecíveis (`ENRICHABLE_DIRS`) no `forge update`. `evals/` não é maquinaria. Nenhum código de projeção muda.
- **Plugin só carrega commands:** `plugin-build.mjs` gera `plugin/forge/commands/**` a partir de `template/.forge/commands/**`; agentes e skills não passam por ele.
- **Gates existentes que este change toca ou pode derrubar:** `w200` (contagem do README), `w209` bloco B (toda varredura recursiva extratora sob `template/` e `tests/` precisa de `-a`), `w102` (projeção dinâmica de skills), `tests/snapshot/claude-contract.bats` C2/C4 (frontmatter YAML parseável com `description`), `w14` e `npx-pack-gate` (projeção do adapter), `plugin-sync-gate`, check de vazamento `.claude/` do `doctor`, `w213` e a sentinela de árvore rastreada do `run-all.sh` (gate nunca muta arquivo rastreado).
- **Rules que já governam o domínio:** `rules/data/data-governance.md` (matriz transversal e isolamento multi-tenant), `data-config-sql.md`, `data-transactional-nosql.md`, `data-cache.md`, `schema-evolution.md`, e `rules/architecture/internal-grpc-communication.md` (gRPC interno por padrão, REST/mensageria nas fronteiras). Pela ordem de autoridade do `FORGE.md` (constitution > baseline/ADRs > rules > contexto), skill é contexto: rule vence skill.
- **Regra do dono (integração):** interno serviço a serviço é gRPC; externo é REST (síncrono) ou fila/mensageria (assíncrono); nunca gRPC para terceiro. Coincide com a rule `internal-grpc-communication.md` do template, que passa a ser a fonte citada pelos agentes.

## 2. Decisão técnica

### 2.1 Taxonomia de roteamento (D-01)

O orquestrador classifica por três eixos, nesta ordem de precedência: **(1) padrão de acesso dominante** (transação multi-entidade, lookup por chave, varredura histórica, trabalho assíncrono, blob imutável), **(2) forma do dado** (estruturado, semiestruturado, não estruturado — classificação de uso corrente, sem norma que a defina, base §0.1) e **(3) produto** citado no pedido. O produto nunca decide sozinho: Redis como fonte da verdade não é cache, e JSON pode morar em `jsonb`, em documento ou numa tabela analítica. É a leitura dos cinco passos da Microsoft ("Understand data models", [J]) com a ressalva que a própria página faz: persistência poliglota é o destino comum, não o ponto de partida.

Matriz sinal → especialista (base §0.2), que vai literal para o corpo do orquestrador:

| Sinal dominante | Modelo | Especialista |
|---|---|---|
| Transação multi-entidade estrita, integridade referencial, dinheiro, estoque, ledger, cobrança; migração de schema, lock, isolamento, deadlock, N+1, paginação, pool | Relacional OLTP | `data-relational` |
| Agregado de forma evolutiva lido e escrito inteiro, chave de partição, escala horizontal por partição (DynamoDB, MongoDB, Cosmos DB, Cassandra); travessia de relacionamento de profundidade variável (grafo) | Documento, chave-valor persistente, coluna larga, grafo | `data-nosql` |
| Lookup sub-ms de cópia derivada, sessão efêmera, TTL, invalidação, stampede, Redis/Valkey como cache | Chave-valor em memória | `data-cache` |
| Binário grande, arquivo, backup, export, zona bruta de lake, URL pré-assinada, lifecycle, WORM, bucket | Objeto | `data-object-storage` |
| Varredura histórica, agregação, BI, modelagem dimensional, dbt, warehouse, lakehouse, Iceberg/Delta, particionamento e clustering de tabela | Analítico/OLAP | `data-analytical` |
| Trabalho assíncrono, desacoplar cadência, evento de domínio, fan-out, replay, outbox, CDC, saga, idempotência de consumidor, schema de evento, RabbitMQ, Kafka | Fila, stream, log | `data-streaming` |

Regras de desempate (base §0.3), também literais no orquestrador:

1. Fonte da verdade decide o dono: Redis como armazenamento primário vai para `data-nosql`, que herda a checagem "cache como fonte da verdade" de `data-cache`.
2. Fila nunca no cache: fila, lock durável ou job em Redis com eviction é antipattern de `data-cache`; o desenho da fila é de `data-streaming`.
3. Medallion tem dois donos: `data-object-storage` responde por bucket por zona, prefixos, lifecycle, criptografia, acesso público, WORM e small files no nível de objeto; `data-analytical` por formato de tabela, particionamento/clustering de tabela, modelagem, dbt, contratos e manutenção de tabela.
4. Particionamento: diretório estilo Hive é aceitável para arquivo bruto (`data-object-storage`); tabela silver/gold segue `data-analytical` (particionamento oculto, liquid clustering, não particionar abaixo de ~1 TB no Databricks).
5. CDC e invalidação: o mecanismo (outbox, Debezium, slot) é de `data-streaming`; a política de invalidação é de `data-cache`.
6. Séries temporais: ingestão operacional por chave e janela curta vai para `data-nosql` (ou `data-relational` com extensão tipo TimescaleDB quando o volume cabe e a consulta cruza dado transacional); agregação histórica vai para `data-analytical`.
7. Busca textual e vetorial não têm especialista: `data-relational` quando `jsonb`/full-text/`pgvector` bastam; caso contrário, "fora da cobertura", dito explicitamente. Índice de busca nunca é fonte da verdade.
8. Superfície externa: nenhum especialista propõe acesso direto de terceiro a banco, cache, tópico, vhost ou bucket internos (§2.4).

### 2.2 Orquestrador `data-engineer` (D-02, D-04)

Arquivo `template/.forge/agents/data/data-engineer.md`. Frontmatter:

```yaml
---
name: data-engineer
description: |
  Use para qualquer decisão ou revisão de dados — modelagem e migração relacional, chave de partição e consistência em NoSQL, cache, bucket e ciclo de vida de objeto, warehouse/lakehouse e dbt, filas e eventos (RabbitMQ, Kafka, outbox, CDC). Classifica o pedido pelo padrão de acesso, delega ao especialista certo e sintetiza. Não use para busca vetorial dedicada, para código sem persistência nem para infraestrutura de rede.
tools:
  - Agent(data-relational, data-nosql, data-cache, data-object-storage, data-analytical, data-streaming)
  - Read
  - Grep
  - Glob
model: sonnet
---
```

Corpo, nesta ordem: `Missão`; `Taxonomia` (matriz e regras do §2.1); `Protocolo` (1. ler `.forge/rules/data/*`, `rules/architecture/internal-grpc-communication.md`, ADRs e baseline do projeto; 2. classificar e declarar a classificação em uma linha; 3. decompor pedido multi-domínio em uma pergunta por especialista, com o contexto mínimo e os paths relevantes; 4. delegar; 5. sintetizar atribuindo cada recomendação ao especialista de origem e marcando divergências entre eles); `Checklist transversal` (base §0.4 e §7: dado sensível PCI/LGPD, multi-tenant, custo da unidade dominante, reversibilidade e expand/contract, maturidade operacional — backup testado, monitoramento, runbook); `Regra de integração` (§2.4); `Modo degradado`; `Fora da cobertura`.

Modo degradado: sem a ferramenta `Agent` (profundidade máxima atingida, ou ferramenta de IA sem subagentes), o orquestrador não responde no lugar do especialista; devolve

```text
PLANO DE ROTEAMENTO
classificação: <eixo 1> / <eixo 2> / <produto>
especialistas: <esp>[, <esp>...]
pergunta por especialista:
  - <esp>: <pergunta reformulada com contexto mínimo e paths>
checklist transversal: <itens aplicáveis>
```

para que quem o chamou acione os especialistas. Os especialistas continuam utilizáveis diretamente (pela descrição ou por `@<esp>`), e as skills são projetadas também para `.agents/skills/`, onde ferramentas sem subagentes as encontram.

Modelo (D-04): `sonnet` no orquestrador e nos especialistas. A regra do dono proíbe herança implícita de modelo; o valor é sempre explícito.

### 2.3 Especialistas (D-03)

Seis arquivos `template/.forge/agents/data/<esp>.md`, mesmo molde. Frontmatter:

```yaml
---
name: <esp>
description: |
  <quando usar, com gatilhos concretos do domínio; quando não usar, apontando o especialista vizinho>
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - mcp__context7__resolve-library-id
  - mcp__context7__get-library-docs
skills:
  - <esp>-practices
model: sonnet
---
```

Sem `Write`, `Edit` nem `Agent`: o especialista é consultivo — devolve recomendação, DDL, policy ou trecho de código na resposta, e quem escreve é o agente de engenharia ou o `task-coder` (uma árvore, um escritor). `Bash` existe para rodar o `scan.sh` e comandos de leitura. Seções do corpo, nesta ordem: `Missão`, `Escopo` (quando usar e quando não, da base §N.1), `Protocolo` (1. ler rules/ADRs/baseline do projeto e declarar divergência com a skill, seguindo a fonte de maior autoridade e parando em conflito relevante conforme `rules/conventions/conflict-handling.md`; 2. rodar `bash .forge/skills/<esp>-practices/scripts/scan.sh --root <paths afetados>`; 3. julgar cada `FOUND` lendo o arquivo; 4. responder), `Checklist`, `Antipatterns bloqueados` (ids do catálogo), `Regra de integração` (§2.4), `Quando devolver ao orquestrador` (pedido que cruza para outro domínio pela matriz do §2.1).

### 2.4 Frase canônica da regra de integração

Os sete agentes carregam, na seção `Regra de integração`, este parágrafo literal (o gate [10] procura a frase entre aspas):

> "Comunicação interna entre serviços é gRPC por padrão, com contrato `.proto` versionado; comunicação externa é REST (síncrona) ou fila/mensageria (assíncrona); gRPC nunca é exposto a terceiros, e nenhum terceiro recebe acesso direto a banco, cache, tópico, fila, vhost ou bucket internos." Fonte: `.forge/rules/architecture/internal-grpc-communication.md`. Formas válidas de entrega externa: API REST (com idempotency key em POST com efeito), fila ou tópico dedicado por parceiro com vhost/usuário/ACL próprios, webhook, e URL pré-assinada de curta duração para objeto.

### 2.5 Skills de referência (D-07) e `scan.sh`

Estrutura por skill (`<esp>-practices`), no molde de `node-quality-scan`:

```text
template/.forge/skills/<esp>-practices/
├── SKILL.md                     # ≤ 120 linhas: protocolo, o que o scanner não faz, sessão limpa, referências
├── references/best-practices.md # boas práticas por tópico, com marca de evidência e fontes (links)
├── references/antipatterns.md   # catálogo: ### <ID> — <nome> + Sintoma / Por quê / Correção / Detecção / Evidência
└── scripts/scan.sh              # detecção estática das entradas com Detecção: scan.sh <ID>
```

Formato de entrada do catálogo:

```markdown
### RMQ-AP-10 — Requeue infinito
- **Sintoma:** mensagem que falha volta à cabeça da fila e é reentregue sem fim; CPU alta, `redeliver` crescente, fila parada atrás dela.
- **Por quê:** `nack`/`reject` com `requeue=true` recoloca a mensagem; em quorum, `basic.nack` não incrementa `delivery-count`, então o `delivery-limit` não a contém. Em amqplib e Spring AMQP o requeue é `true` por padrão.
- **Correção:** erro permanente com `reject` ou `nack(requeue=false)` para a DLX; erro transitório com retry fora da fila principal (RMQ-BP-12).
- **Detecção:** `scan.sh RMQ-AP-10` (estática); runtime: taxa de redeliver por fila.
- **Evidência:** [J] quorum queues e amqplib channel API; Spring AMQP exception handling.
```

`Detecção` usa quatro rótulos: `scan.sh <ID>` (estática, o scanner executa), `ferramenta` (linter ou analisador externo que o projeto roda: squawk, strong_migrations, SQLFluff, dbt-project-evaluator, Checkov), `runtime` (consulta ou comando contra sistema real, documentado e nunca executado pelo scanner) e `revisão` (sem detector confiável). Comandos de runtime e de ferramenta são os da base, reescritos com `grep -a`/`rg` quando varrem árvore; itens de base §8.2 ("Incerto") entram com o rótulo `[Incerto]` e nunca como detector de severidade `alto`.

Contrato do `scan.sh` (idêntico nos seis; D-08):

- Uso: `scan.sh [--root <dir>] [--json <arquivo>] [--max <n>]`; `--root` default `.`.
- Motor: `rg` quando presente, `grep -arnE` quando não; mesmo padrão nos dois; sem `\b` (o `grep` BSD não o reconhece); exclusão por filtro, nunca por lookahead; bytes de controle removidos da saída como em `node-quality-scan`.
- Diretórios ignorados: `node_modules`, `dist`, `build`, `.git`, `vendor`, `target`, `.venv`, `coverage`, `generated`.
- Saída: uma linha por regra (`OK <ID> [<sev>] nenhuma ocorrência` ou `FOUND <ID> [<sev>] <n> ocorrência(s)` e as localizações `  <arquivo>:<linha>: <trecho>` até `--max`), depois `ARQUIVOS-VARRIDOS <n>` com o total de arquivos do universo de extensões da skill. Universo zero: `NADA-EXAMINADO`, exit 3.
- Severidade: `alto` só quando o detector é preciso e a prática é inequívoca na base ([J], [1F] ou [2F]); todo detector [Heurística] é `aviso`. Exit 0 sem `alto`, 1 com `alto`, 2 uso, 3 nada examinado.
- Sem rede, sem credencial, sem ler variável de ambiente de conexão.

Regras estáticas por skill (as demais entradas do catálogo são `ferramenta`, `runtime` ou `revisão`). "Código" = `ts, tsx, js, jsx, mjs, cjs, py, rb, java, kt, go, cs`; "IaC" = `tf, yaml, yml, json, conf, properties, toml, hcl`.

| Skill | ID | Sev | Detecta (arquivos) |
|---|---|---|---|
| relational | R-03 | alto | `CREATE [UNIQUE] INDEX` sem `CONCURRENTLY`; `ALTER COLUMN … TYPE`; `RENAME COLUMN`/`RENAME TO`; `SET NOT NULL` (`*.sql`) |
| relational | R-04 | aviso | `timestamp` sem fuso, `char(n)`, `money`, `json` (não `jsonb`), `serial` (`*.sql`) |
| relational | R-06 | aviso | `OFFSET` com parâmetro ou literal ≥ 3 dígitos, `.offset(`, `.skip(` (código, `*.sql`) |
| relational | R-10 | alto | `WITH (NOLOCK)`, `READ UNCOMMITTED` (código, `*.sql`) |
| relational | R-12 | aviso | `SET search_path`, `LISTEN`, `pg_advisory_lock(` (código) — só é defeito atrás de PgBouncer em modo transaction |
| relational | R-13 | alto | `ALGORITHM=COPY`, `LOCK=SHARED`/`EXCLUSIVE` (`*.sql`) |
| relational | R-14 | aviso | `SELECT *` (código) |
| nosql | N-01 | aviso | `$push` sem `$slice` na linha (código) |
| nosql | N-04 | aviso | `$lookup` (código) |
| nosql | N-06 | aviso | `hash_key`/`partition_key_path(s)` com `status`, `type`, `date`, `country`, `state`, `category` (IaC) |
| nosql | N-07 | alto | `w: 1`, `w=1`, `WriteConcern.W1`/`ACKNOWLEDGED` (código) |
| nosql | N-08 | aviso | `ScanCommand`, `.scan(`, `Scan(` (código) |
| nosql | N-09 | aviso | `list_append` (código) |
| nosql | N-10 | aviso | `projection_type = "ALL"` (IaC) |
| nosql | N-11 | alto | `ConsistentRead: true` e `IndexName` na mesma linha ou no mesmo objeto de uma linha (código) |
| nosql | N-13 | alto | `ALLOW FILTERING`; `CREATE [CUSTOM] INDEX` em `*.cql` |
| nosql | N-15 | aviso | `BEGIN [UNLOGGED] BATCH` (`*.cql`, código) |
| nosql | N-17 | aviso | `-[:RELATED_TO]`, `HAS`, `LINK`, `CONNECTED` genéricos (`*.cypher`, código) |
| cache | C-02 | aviso | `.set(`/`.hset(`/`.hmset(` sem `ex=`, `px=`, `EX`, `PX`, `expire`, `ttl`, `timeout` na linha (código) |
| cache | C-08 | aviso | `lru_cache`, `Caffeine`, `MemoryCache`, `node-cache` sem `expireAfterWrite`/`ttl`/`maxAge` na linha (código) |
| cache | C-09 | aviso | `"KEYS"` literal de comando ou `.keys(` sobre cliente redis (código) |
| cache | C-10 | alto | `maxmemory-policy noeviction`, `maxmemory 0` (IaC, `redis.conf`) |
| cache | C-11 | alto | `protected-mode no`, `bind 0.0.0.0` (`redis.conf`, IaC) |
| cache | C-15 | alto | escrita em cache com nome de campo de cartão: `pan`, `card_num`, `cardnumber`, `cvv`, `cvc`, `track1/2`, `pin_block`, `expiry` (código) — T-01 da base §7.1 |
| object-storage | O-01 | alto | `acl = "public-read"`/`"public-read-write"`, `block_public_acls = false`, `allUsers`, `allAuthenticatedUsers`, `allowBlobPublicAccess: true` (IaC) |
| object-storage | O-02 | aviso | `ExpiresIn`/`expires_in`/`expiresIn`/`Expires` com 4+ dígitos (código) |
| object-storage | O-08 | aviso | arquivo com `sse_algorithm = "aws:kms"` sem `bucket_key_enabled` (IaC; localização é a linha do kms) |
| object-storage | O-11 | alto | `image: minio/minio` (IaC, `Dockerfile`, compose) |
| object-storage | O-13 | aviso | `overwrite`, `MERGE INTO`, `DELETE FROM` na mesma linha que `raw`/`bronze` (código, `*.sql`) |
| object-storage | O-14 | aviso | `partitionBy(` com coluna `id`, `uuid`, `user`, `customer` (código) |
| analytical | A-06 | aviso | `PARTITIONED BY (`, `INSERT … PARTITION (` (`*.sql`) |
| analytical | A-08 | aviso | modelo com `materialized='incremental'` sem `unique_key` no arquivo (`models/**/*.sql`) |
| analytical | A-10 | alto | `source(` sob `models/marts/` |
| analytical | A-12 | aviso | `SELECT *` sob `models/marts/` |
| analytical | A-14 | alto | `invalidate_hard_deletes` (`snapshots/`, `*.yml`, `*.sql`) |
| streaming | RMQ-AP-01 | alto | auto-ack: `basicConsume(…, true`, `auto_ack=True`, `noAck: true`, `autoAck: true`, `AcknowledgeMode.NONE`, `acknowledge-mode: none` |
| streaming | RMQ-AP-03 | aviso | `newConnection(`, `BlockingConnection(`, `amqp.connect(`, `amqp.Dial(`, `CreateConnection(`/`CreateConnectionAsync(` (código) |
| streaming | RMQ-AP-04 | aviso | `basicGet(`, `basic_get(`, `.Get(` em canal, `BasicGet(` (código) |
| streaming | RMQ-AP-06 | alto | `ha-mode`, `ha-params`, `ha-sync-mode` (IaC, código) |
| streaming | RMQ-AP-07 | aviso | `x-queue-mode`, `queue-mode` (IaC, código) |
| streaming | RMQ-AP-08 | aviso | arquivo que publica (`basicPublish`, `basic_publish`, `.publish(`, `PublishWithContext`, `BasicPublish`) sem `confirmSelect`, `confirm_delivery`, `createConfirmChannel`, `.Confirm(`, `ConfirmSelect`, `publisher-confirm-type` |
| streaming | RMQ-AP-09 | aviso | `waitForConfirms` (código) |
| streaming | RMQ-AP-10 | alto | `basicNack(…, …, true)`, `basic_nack(… requeue=True`, amqplib `.nack(msg)` de um argumento, Go `.Nack(…, true)`, `default-requeue-rejected: true` |
| streaming | RMQ-AP-12 | aviso | arquivo que publica sem `delivery_mode=2`, `PERSISTENT_`, `persistent: true`, `amqp.Persistent`, `DeliveryMode = 2` |
| streaming | RMQ-AP-14 | aviso | `x-dead-letter-exchange`, `x-message-ttl`, `x-max-length`, `x-delivery-limit`, `x-overflow` em código |
| streaming | RMQ-AP-15 | aviso | `queueDeclare(…, false, false`, `durable: false`, `durable=False` (código) |
| streaming | RMQ-AP-17 | alto | `x-delayed-message`, `x-delayed-type`, `rabbitmq_delayed_message_exchange` |
| streaming | RMQ-AP-18 | alto | `basicQos(…, true)`, `basic_qos(… global_qos=True` |
| streaming | RMQ-AP-19 | alto | `cluster_partition_handling` com `pause_minority`/`autoheal`/`pause_if_all_down` |
| streaming | KFK-AP-01 | alto | `enable.auto.commit` `true` explícito (a ausência da chave também é defeito, pois o default é `true`; fica como `revisão`) |
| streaming | KFK-AP-02 | alto | `acks` `0` ou `1`, `enable.idempotence` `false`, `retries` `0` |
| streaming | KFK-AP-03 | aviso | `new ProducerRecord<…>(topic, value)` de dois argumentos (código) |
| streaming | KFK-AP-06 | alto | `replication_factor = 1`, `min.insync.replicas` `1`, `unclean.leader.election.enable` `true` (IaC) |
| streaming | D-AP-01 | aviso | `grpc` em manifests de Ingress, Gateway ou Service `LoadBalancer` (IaC) |
| streaming | SCH-AP-01 | alto | `required` em `*.proto` |
| streaming | T-02 | alto | campo `pan`, `card_number`, `cvv`, `cvc`, `track`, `pin_block` em `*.proto`, `*.avsc` e JSON Schema de evento |

Ids novos (`SCH-AP-*`, `INB-AP-*`, `OBX-AP-*`, `CDC-AP-*`) catalogam antipatterns que a base descreve em prosa sem id (base §6.6); a evidência é a mesma da prosa. Os padrões concretos (regex) são escritos na TASK de cada skill, conferidos contra a fixture suja e a limpa, e documentados em `antipatterns.md`; esta tabela fixa o que cada regra detecta, não a expressão.

`best-practices.md` do `data-streaming` tem a seção `## RabbitMQ` com as treze subseções do REQ-04, na ordem: `Plataforma 4.x` (base §6.2), `Exchanges e roteamento` (topic durável por domínio, alternate exchange e `mandatory` para não roteável, consistent hash para partição por chave; a semântica fina de `headers`/`x-match` e de `basic.return` é [Incerto], base §8.2 item 5), `Filas quorum`, `DLX e poison message`, `Ack e prefetch`, `Publisher confirms`, `Retry` (nativo em 4.3; filas de espera por patamar antes; nunca o plugin), `Idempotência e inbox`, `Ordem`, `Streams`, `Operação e segurança`, `Receita de referência` (base §6.3, literal) e `Migrações` (espelhadas → quorum, Mnesia → Khepri antes do 4.3, delayed exchange → retry nativo; procedimento Mnesia → Khepri marcado [Incerto]). Depois: `## Kafka`, `## Padrões de integração` (inbox, outbox, CDC, saga, schema de evento, event sourcing) e `## Escolha de transporte` (tabela da base §6.7).

### 2.6 Gate `tests/w250-data-engineer-agents-gate.sh` (D-09)

Ordinal: o menor `wNNN ≥ w250` livre em `tests/`, na tabela de ordinais de `docs/plans/2026-09-15-plano-issues-abertas.md` (que vai até w246) e nos refs remotos, conferido em 2026-09-26 (o piso w250 é regra desta rodada, porque w239 a w249 ficam para as frentes em curso — w240 a w246 na tabela do plano, w247 e w248 já tomados; `gate-ordinal.sh next` devolveu w239 pelo tronco, o que confirma que nada acima de w238 está mergeado). O gate é escrito como funções que recebem a raiz (`confere_* <root>`), para que a mutação rode sobre cópia em diretório temporário. Cenários:

- **[0] universo:** sete agentes em `agents/data/` e seis skills `data-*-practices`, via `lib/gate-universe.sh`; zero reprova.
- **[1] frontmatter:** `validate-frontmatter.sh --strict-xml` nos dois diretórios termina em `OK`; o frontmatter dos treze arquivos de entrada (sete agentes e seis `SKILL.md`) parseia com o pacote `yaml` (devDependency do repositório, presente no CI como o `ajv` do [15]) e tem `description` — a mesma propriedade que o C2/C4 do `claude-contract.bats` verifica com PyYAML, que o CI pode não ter; o `lib/yaml-lite.mjs` não serve aqui porque não lê bloco `|`. Sem o pacote, o cenário é `INCONCLUSIVO` e o gate sai 99, nunca aprova.
- **[2] roteamento:** allowlist do `Agent(...)` do orquestrador = conjunto dos seis nomes; todo nome da matriz tem arquivo; todo arquivo de especialista aparece na matriz; nenhum nome fantasma.
- **[3] especialistas:** `skills:` aponta para skill existente; `model` presente; `tools` sem `Write`, `Edit`, `Agent`; as sete seções na ordem do §2.3.
- **[4] skills:** três arquivos (mais `scan.sh`); corpo do `SKILL.md` ≤ 120 linhas; toda entrada `### <ID> —` de `antipatterns.md` tem os cinco rótulos; `best-practices.md` tem as seções de cobertura mínima do REQ-03.
- **[5] bijeção:** ids com `Detecção: scan.sh <ID>` = ids emitidos pelo `scan.sh` sobre a fixture limpa.
- **[6] detecção:** fixture suja faz cada regra emitir `FOUND` com `arquivo:linha`; fixture limpa faz todas emitirem `OK`; duas execuções idênticas (`cmp -s`); exit 1 só quando há `alto`.
- **[7] portabilidade:** mesma saída com `PATH` sem `rg`.
- **[8] contador:** diretório sem arquivo do universo da skill dá `NADA-EXAMINADO` e exit 3.
- **[9] RabbitMQ:** treze subseções e ids `RMQ-BP-01..17`, `RMQ-AP-01..19` contíguos.
- **[10] integração:** frase canônica nos sete agentes; tabela de transporte e `D-AP-01..03` presentes.
- **[11] refutados:** fora de `antipatterns.md`, nenhuma ocorrência de recomendação refutada ou obsoleta: `ha-mode`, `x-queue-mode`/`lazy` como recomendação, `x-delayed-message`, "3–4x"/"4x o WAL", "max.in.flight … desativa", partição Hive recomendada para silver/gold.
- **[12] fiação:** `capability-dispatcher/SKILL.md` cita `data-engineer` e as seis skills; `agents/README.md` tem `### Dados (data/)` com sete links que resolvem; nenhum arquivo novo contém `.claude/`.
- **[13] projeção:** instalação real num temporário com `--adapters claude,agents-skills` projeta sete agentes em `.claude/agents/data/`, seis `SKILL.md` em `.claude/skills/data-*-practices/` e em `.agents/skills/`, com `scan.sh`.
- **[14] mutação (sobre cópia):** (a) tirar `data-cache` da allowlist → [2] reprova nomeando `data-cache`; (b) apagar o rótulo `Correção` de uma entrada → [4] reprova nomeando o id; (c) apagar a regra `RMQ-AP-10` do `scan.sh` → [5] reprova nomeando `RMQ-AP-10`; (d) inserir "use `ha-mode: all`" em `best-practices.md` → [11] reprova. Controle antes (cópia íntegra aprova) e recontrole depois (cópia restaurada por `cp` do original, `cmp -s` contra o original, aprova de novo).
- **[15] evals:** sete `evals.json` válidos no schema (ajv 2020 de `node_modules`, como o w52; sem ajv o cenário é `INCONCLUSIVO` e o gate sai 99), três casos por especialista, oito para o orquestrador, ids únicos, ≥ 2 expectations por caso. Resolução de `ajv` e `yaml`: `node_modules` do próprio checkout; em worktree sem `node_modules`, o do checkout principal (diretório pai de `git rev-parse --git-common-dir`), dito na saída de qual veio.

Fixtures em `tests/fixtures/w250/<esp>/{sujo,limpo}/`, uma linha por regra estática na suja. A fixture suja carrega texto que o w209 aceita (sem byte de controle). O gate nunca escreve em arquivo rastreado.

### 2.7 Evals A/B (D-10)

Local: `.forge/evals/agents/<nome>/evals.json` na raiz do dogfood, fora do `template/`. Formato: `evals.schema.json` sem alteração, com `skill` = nome do agente e `description` explicando variante e baseline. Variante: o especialista, com a skill pré-carregada. Baseline: mesmo modelo, agente genérico sem o prompt do especialista nem a skill, mesmo prompt. Execução pelo orquestrador depois do `/forge:implement` (executor → grader → `eval-aggregate.sh`), com os artefatos em `workspace/iteration-1/` ao lado de cada `evals.json`. Critério: `pass_rate` da variante maior que o da baseline em cada um dos seis especialistas; roteamento ≥ 7/8.

| Agente | Caso | Prompt (resumo) | Expectations centrais |
|---|---|---|---|
| data-relational | desenho | ledger multi-tenant em PostgreSQL 16 com saldo por conta: DDL e isolamento | `bigint` identity ou UUIDv7; `numeric` para valor; `timestamptz`; índice na FK; `tenant_id` à frente do índice composto ou RLS; Serializable ou lock explícito com retry em `40001`/`40P01` |
| data-relational | revisão | migração com `CREATE INDEX` simples e `RENAME COLUMN` em tabela grande, deploy com aplicação no ar | cita R-03; `CONCURRENTLY` fora de transação; expand/contract para o rename; `lock_timeout` na sessão |
| data-relational | fronteira | adquirente quer usuário read-only direto na tabela de transações | recusa acesso direto; propõe REST ou fila dedicada; não propõe gRPC externo; trata PAN como token |
| data-nosql | desenho | DynamoDB para pedidos por cliente e por status a 50 mil/s | partition key de alta cardinalidade; sort key hierárquica; GSI com write sharding para status; sem Scan; cita 3.000 RCU/1.000 WCU por partição |
| data-nosql | revisão | Terraform com `hash_key = "status"`, código com `ScanCommand` e `ConsistentRead: true` em GSI | cita N-06, N-08, N-11 com correção |
| data-nosql | fronteira | MongoDB P-S-A com `w:1` para pagamentos, "o default já é majority" | corrige: com árbitro o default cai para `w:1`; recomenda P-S-S e `majority` (N-07) |
| data-cache | desenho | tarifas lidas 10 mil/s, atualizadas por hora, multi-tenant | cache-aside; TTL com jitter; namespace por tenant; delete após commit; proteção contra stampede; `maxmemory` explícito e política |
| data-cache | revisão | `redis.set` sem TTL, `redis.keys('user:*')`, delete antes do commit | cita C-02, C-09, C-01 com correção |
| data-cache | fronteira | cachear PAN e CVV por 5 min para retentativa | recusa (SAD não persiste após autorização, PCI 3.3.1; Redis persiste); propõe token |
| data-object-storage | desenho | comprovantes PDF com retenção de 5 anos e download pelo app | bucket privado com BPA; SSE-KMS com Bucket Key; versionamento com expiração de não correntes; abort de multipart; URL pré-assinada de minutos; WORM só com obrigação legal e conciliação LGPD |
| data-object-storage | revisão | Terraform com `acl = "public-read"`, `ExpiresIn: 604800`, `image: minio/minio` | cita O-01, O-02, O-11 com correção |
| data-object-storage | fronteira | parceiro pede credencial IAM de leitura no bucket interno | recusa; URL pré-assinada curta ou REST; nunca gRPC externo |
| data-analytical | desenho | vendas de bilhetes para BI com tarifa mudando no tempo | quatro passos de Kimball; grão declarado; SCD2 com chave substituta; `dbt snapshot` estratégia `timestamp`; testes `unique`/`not_null` no grão |
| data-analytical | revisão | incremental sem `unique_key`, mart com `source()`, snapshot com `invalidate_hard_deletes` | cita A-08, A-10, A-14; migração para `hard_deletes` |
| data-analytical | fronteira | "particione por dia a tabela Delta de 50 GB no Databricks" | não particionar abaixo de 1 TB; liquid clustering |
| data-streaming | desenho | fila de pagamentos com retry e DLQ em RabbitMQ 4.3 | quorum; `delayed-retry-*` nativo; DLX at-least-once com `overflow=reject-publish`; `delivery-limit`; confirms; ack manual; prefetch; inbox; não usa plugin delayed nem `ha-mode` |
| data-streaming | revisão | amqplib com `ch.nack(msg)` no catch, `noAck: true`, policy `ha-mode: all` | cita RMQ-AP-10 (requeue default e `nack` fora do `delivery-limit`), RMQ-AP-01, RMQ-AP-06 |
| data-streaming | fronteira | expor o serviço gRPC de eventos de transação ao integrador | recusa gRPC externo; fila dedicada em vhost/usuário próprios, webhook ou REST; payload sem PAN |
| data-engineer | roteamento | oito prompts: relacional; Redis como armazenamento primário de sessão durável (desempate 1 → nosql); cache; objeto; analítico; streaming; outbox com invalidação de cache (streaming + cache); busca vetorial semântica em 50 milhões de documentos (fora da cobertura) | especialista(s) acionado(s) corretos; resposta declara a classificação; fora da cobertura dito explicitamente |

### 2.8 Integrações

- `skills/capability-dispatcher/SKILL.md`: passo novo no protocolo — "se a área afetada envolve persistência, cache, bucket, analítico ou mensageria, indique o `data-engineer` ou carregue só a skill `data-*-practices` do domínio afetado" — e uma tabela área → skill. A `description` não muda, para não alterar o disparo medido da skill.
- `agents/README.md`: seção `### Dados (data/)` no catálogo, com os sete agentes.
- `README.md`: contagens de `agents/` (47 → 54) e `skills/` (20 → 44, se as seis skills tiverem quatro arquivos cada) recalculadas pelo critério do w200 no momento da TASK, e menção ao especialista de dados na lista de capacidades; `CHANGELOG.md` `[Unreleased]`.
- Nenhuma mudança em `rules/data/*`; os especialistas as leem no protocolo.

## 3. Alternativas consideradas

| Decisão | Alternativa | Prós | Contras | Por que não |
|---|---|---|---|---|
| D-01 taxonomia | Rotear pela forma do dado (estruturado/semi/não estruturado), como a issue sugere | Simples, vocabulário conhecido | Forma não determina armazenamento: JSON vai para `jsonb`, documento, evento ou tabela analítica; Redis e Postgres atravessam formas | Mantida como eixo 2, nunca como eixo primário |
| D-01 taxonomia | Rotear pelo produto citado | Classificação trivial | Redis como fonte da verdade não é cache; pedido sem produto fica sem rota; incentiva a resposta "use o que já tem" | Produto é eixo 3 e desempate |
| D-01 taxonomia | Só OLTP × OLAP | Clássico | Não cobre cache, objeto nem mensageria | Insuficiente |
| D-01 taxonomia | Um especialista por modelo de armazenamento (dez, como a Azure) | Cobertura completa | Busca, vetorial e séries temporais sem demanda medida; manutenção de dez catálogos | Seis especialistas, lacunas declaradas e regras de desempate 6 e 7 |
| D-02 orquestrador | Skill roteadora carregada no contexto principal | Funciona em qualquer ferramenta | Sem contexto isolado; o catálogo inteiro competiria com o resto da sessão | A issue pede subagente com contexto próprio; o aninhamento é suportado |
| D-02 orquestrador | Comando `/forge:data` | Entrada explícita | 57º comando, plugin e contagens mudam; o disparo por descrição já existe | Pode vir depois, se o eval de roteamento mostrar disparo fraco |
| D-02 orquestrador | Sem orquestrador, só os seis especialistas | Menos uma peça | Pedido multi-domínio fica sem síntese e sem checklist transversal | Rejeitado |
| D-03 especialistas | Especialista com `Write`/`Edit` | Aplica a correção direto | Dois escritores na árvore; exige disciplina de ferramenta e build | Consultivo; quem escreve é engenharia ou `task-coder` |
| D-04 modelo | `opus` nos especialistas | Julgamento mais forte | Custo por consulta alto para pergunta frequente | `sonnet`; o eval diz se precisa subir |
| D-04 modelo | `haiku` no orquestrador | Barato | Decomposição e síntese multi-domínio exigem mais | `sonnet` |
| D-05 plugin | Tocar o plugin | — | Plugin só carrega commands | Plugin intocado; `plugin-sync-gate` revalidado |
| D-06 conflito | Reescrever `data-governance.md` ("transacional de negócio → MongoDB") para alinhar à taxonomia | Um template coerente | Muda uma rule em uso por consumidores, fora do escopo da issue, e exige ADR de governança | Precedência (rule vence skill), divergência citada na resposta, follow-up registrado |
| D-06 conflito | A skill ignora a rule | — | Viola a ordem de autoridade do FORGE.md | Rejeitado |
| D-07 skills | Uma skill única de dados | Menos arquivos | Contexto grande carregado para pergunta de um domínio só | Seis skills, pré-carga seletiva |
| D-07 skills | Conhecimento no corpo do agente | Menos indireção | Sem progressive disclosure; o catálogo fica ilegível | Agente enxuto, referência na skill |
| D-08 scanner | Scanner que conecta no sistema (`pg_stat`, `redis-cli`, `rabbitmqctl`) | Pega o que o texto não mostra | Credencial, rede, risco operacional, não determinístico | Runtime documentado, não executado |
| D-08 scanner | Scanner como gate bloqueante do verify | Enforcement | Detectores heurísticos; falso positivo treina a ignorar | Instrumento do especialista; `alto` só com detector preciso |
| D-09 gate | Gates separados por especialista | Falha localizada | Seis gates quase idênticos | Um gate com funções por raiz e mensagens que nomeiam o alvo |
| D-10 evals | `template/.forge/evals/agents/` | Chega ao consumidor no init | `workspace/iteration-N` iria para o template; `evals/` não é maquinaria e o update não o leva | Dogfood `.forge/evals/agents/` |
| D-10 evals | Estender `evals.schema.json` com campo `agent` | Semântica exata | Mexe no schema e no w30 | `skill` carrega o nome do agente; `description` explica |

## 4. Contratos e integrações afetados

- **Contrato de subagente do Claude Code:** campos `name`, `description`, `tools`, `skills`, `model`; `Agent(...)` como allowlist. Se a plataforma mudar a sintaxe, o gate [2] e o C2/C4 acusam.
- **Contrato de skill (Agent Skills):** `SKILL.md` com frontmatter validado por `validate-frontmatter.sh`; `references/` sem frontmatter.
- **Contrato do scanner:** saída e códigos de saída do §2.5, iguais nos seis; mudança é breaking para o especialista e exige atualizar o gate.
- **Schema `evals.schema.json`:** sem alteração.
- **Adapters:** sem alteração de código; a projeção é testada no [13].

## 5. Plano de migração / rollout

Aditivo. Consumidores recebem agentes e skills no próximo `forge update` (overlay de `MACHINERY_DIRS`) e no `init`; nenhuma configuração é exigida. Consumidor que tenha agente próprio chamado `data-*` em `agents/` fica protegido pelo tratamento de `ENRICHABLE_DIRS` (arquivo local preservado); o conflito de nome aparece no relatório do update. Nada a desfazer em rollback além de apagar os diretórios novos.

## 6. Riscos e mitigação

| Risco | Probabilidade | Impacto | Mitigação / detecção |
|---|---|---|---|
| Especialista contradiz rule do projeto (ex.: `data-governance.md` manda MongoDB para transacional) | Alta | Médio | Protocolo manda ler rules primeiro e citar divergência; eval de fronteira; follow-up para revisar a rule |
| Falso positivo do scanner | Média | Médio | Severidade `aviso` para heurística; "o que o scanner não faz" no `SKILL.md`; exit 0 só com avisos |
| Fato de plataforma envelhece (RabbitMQ 4.3, Kafka 4.2, Redis 8.6) | Alta | Médio | Marca de evidência com data; `mcp__context7` nos especialistas para versão corrente; revisão semestral |
| Varredura recursiva sem `-a` em arquivo novo | Média | Baixo | Regra de redação no §2.5; revalidar w209 |
| Colisão de ordinal w250 com frente paralela | Média | Baixo | `gate-ordinal.sh check` antes do push; renomear se colidir |
| Eval com delta ≤ 0 em algum especialista | Média | Alto | Não aprova; revisão da skill e novo ciclo; nunca julgamento no olho |
| Aninhamento indisponível no consumidor | Baixa | Médio | Modo degradado com `PLANO DE ROTEAMENTO`; especialistas acionáveis direto |
| Contagem do README errada | Média | Baixo | Recalcular pelo critério do w200 na TASK de inventário |

## 7. Rastreabilidade

| REQ | Seção do design que o atende |
|---|---|
| REQ-01 | §2.1, §2.2 |
| REQ-02 | §2.3 |
| REQ-03 | §2.5 |
| REQ-04 | §2.5 (seção RabbitMQ) |
| REQ-05 | §2.5 (contrato e tabela de regras) |
| REQ-06 | §2.2 (checklist transversal), §2.4 |
| REQ-07 | §2.8, §4, §5 |
| REQ-08 | §2.6 |
| REQ-09 | §2.7 |
