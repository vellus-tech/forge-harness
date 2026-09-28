# Base consolidada — skill de engenharia de dados (seis especialistas)

Data do julgamento: 2026-09-26. Insumo: `pesquisa-taxonomia-relacional-analitico.md`, `pesquisa-nosql-cache-objetos.md` e `pesquisa-streaming-eventos-rabbitmq.md` (mesma pasta). Este arquivo é a base de conhecimento FINAL: só entra aqui o que se sustentou; o que caiu ou ficou em aberto está na seção "Refutado ou incerto" no fim.

## Como ler as marcas de evidência

- **[J]** — afirmação reconferida pelo juiz nesta rodada, na fonte primária (documentação oficial, código-fonte do produto ou texto normativo). É a marca mais forte deste documento.
- **[2F]** — herdada da pesquisa: triangulada em duas fontes independentes; o juiz não reabriu, mas amostrou a mesma frente sem encontrar erro.
- **[1F]** — herdada da pesquisa: documentação oficial do próprio produto, autoritativa para limite e default do produto; não reaberta pelo juiz.
- **[Interp.]** — leitura técnica derivada das fontes; defensável, mas é interpretação, não fato.
- **[Heurística]** — detector ou limiar de partida; não vira gate bloqueante sem calibração em caso real.

Regra de uso para a skill: detector marcado [Heurística] produz aviso, não bloqueio. Consultas SQL, greps e comandos de runtime foram redigidos pelos pesquisadores e, salvo indicação, **não foram executados** contra sistema real; a skill deve testá-los em fixture antes de promovê-los a gate.

---

## 0. Taxonomia de roteamento (recomendada)

### 0.1 Princípio

Rotear pelo **padrão de acesso dominante**, depois pela forma do dado, e só então pelo produto. A Microsoft organiza a escolha em cinco passos (identificar padrões de acesso; mapear para modelos; listar serviços; aplicar critérios de consistência, latência, escala, governança e custo; combinar modelos só onde padrões de acesso ou ciclos de vida divergem claramente) [J: Azure "Understand data models"]. A mesma página diz que a maioria dos sistemas de produção acaba poliglota e, ao mesmo tempo, manda evitar fragmentação prematura ("use one service when it still meets performance, scale, and governance objectives") [J]. A pesquisa citou só a segunda metade; as duas convivem: poliglotismo é o destino comum, não o ponto de partida.

Três eixos independentes: forma do dado (estruturado, semiestruturado, não estruturado — classificação de uso corrente, sem norma ISO/ANSI que a defina [2F]); modelo de armazenamento (relacional, documento, chave-valor, coluna larga, grafo, séries temporais, busca, vetorial, objeto, analítico) [J: Azure; 2F com DB-Engines]; carga (OLTP × OLAP) [2F: Azure OLTP; DDIA cap. 3].

### 0.2 Matriz sinal → especialista

| Sinal dominante no pedido | Modelo | Especialista |
| --- | --- | --- |
| Transação multi-entidade estrita, integridade referencial, dinheiro, estoque, ledger, cobrança | Relacional OLTP | **relacional** |
| Migração de schema, lock, isolamento, deadlock, N+1, paginação, pool de conexões | Relacional OLTP | **relacional** |
| Agregado JSON de forma evolutiva lido/escrito inteiro; chave de partição; escala horizontal por partição; DynamoDB, MongoDB, Cosmos DB, Cassandra | Documento, chave-valor persistente, coluna larga | **nosql** |
| Travessia de relacionamento de profundidade variável (anel de fraude, dependências, linhagem) | Grafo | **nosql** (subdomínio grafo) |
| Lookup de latência sub-ms, cópia derivada de outra fonte, sessão efêmera, TTL, invalidação, stampede, Redis/Valkey como cache | Chave-valor em memória | **cache** |
| Binário grande, arquivo, backup, export, zona bruta de lake, URL pré-assinada, lifecycle, WORM, bucket | Objeto | **object-storage** |
| Varredura histórica, agregação, BI, modelagem dimensional, dbt, warehouse, lakehouse, formato de tabela (Iceberg/Delta), particionamento/clustering de tabela | Analítico/OLAP | **analitico** |
| Trabalho assíncrono, desacoplar cadência, evento de domínio, fan-out, replay, outbox, CDC, saga, idempotência de consumidor, schema de evento, RabbitMQ, Kafka | Fila, stream, log | **streaming-eventos** |

### 0.3 Regras de desempate e de fronteira

1. **Fonte da verdade decide o dono.** Se o dado só existe ali, não é cache: Redis como armazenamento primário vai para **nosql** (e herda a checagem "cache como fonte da verdade" do especialista cache) [Interp. sobre Redis eviction/cluster spec, J].
2. **Fila nunca no cache.** Fila, lock distribuído durável ou job em Redis na mesma instância com eviction é antipattern do especialista cache; o desenho da fila em si é de **streaming-eventos** [J: Redis recomenda instâncias separadas para cache e chaves persistentes].
3. **Medallion tem dois donos, por camada de preocupação.** **object-storage** responde por bucket/contêiner por zona, prefixos, lifecycle, criptografia, acesso público, WORM e small files no nível de objeto; **analitico** responde por formato de tabela, particionamento/clustering de tabela, modelagem, dbt, contratos e manutenção de tabela (OPTIMIZE/VACUUM/expire snapshots).
4. **Particionamento: layout de arquivo × layout de tabela.** Diretórios estilo Hive (`dt=AAAA-MM-DD/`) são aceitáveis para a zona bruta de arquivos (object-storage). Para tabelas silver/gold o padrão é o do analítico: particionamento oculto (Iceberg) ou liquid clustering, e nada de partição em tabela abaixo de ~1 TB no Databricks [J] — a pesquisa de object-storage recomendava "partição Hive" em silver/gold e contradizia a frente analítica; prevalece a analítica (ver 5.4).
5. **CDC e invalidação de cache** atravessam dois domínios: o mecanismo (outbox, Debezium, slot de replicação) é de **streaming-eventos**; a política de invalidação (delete após commit, TTL) é de **cache**.
6. **Séries temporais:** ingestão operacional de alta taxa com consulta por chave e janela curta → **nosql** (coluna larga/Cassandra, ou extensão tipo TimescaleDB no **relacional** quando o volume cabe e a consulta cruza dados transacionais [J: Azure cita TimescaleDB]); agregação histórica e dashboards → **analitico**.
7. **Busca textual e vetorial não têm especialista.** Lacuna declarada: quando `jsonb`/full-text/pgvector do PostgreSQL bastarem, **relacional**; caso contrário, a skill deve dizer que o pedido está fora da cobertura em vez de improvisar. Regra transversal que já vale: índice de busca nunca é fonte da verdade [J: Azure].
8. **Superfície externa (regra do dono):** interno serviço-a-serviço é gRPC com `.proto` versionado; externo é REST (síncrono) ou fila/mensageria (assíncrono); nunca expor gRPC a terceiro. Consequência para os seis especialistas: nenhum deles propõe dar a terceiro acesso direto a banco, cache, tópico interno, vhost interna ou bucket interno. Formas válidas de entrega externa: API REST, fila/tópico dedicado por parceiro (vhost/usuário/ACL próprios), webhook, URL pré-assinada de curta duração para objeto. Nenhuma das três pesquisas contradiz essa regra; a de streaming a reforça com a limitação técnica do gRPC-Web em navegador [1F: grpc.io].

### 0.4 Checklist transversal (todo especialista aplica antes de responder)

1. **Dado sensível (PCI DSS / LGPD):** o dado contém PAN, SAD, CPF ou dado pessoal? Onde ele persiste (disco, snapshot, réplica, DLQ, log, backup)? Ver seção 7.
2. **Multi-tenant:** qual é a fronteira de isolamento (schema/linha, chave de partição, prefixo, vhost, ACL)? Ver seção 7.
3. **Custo:** qual unidade de cobrança domina (RU/RCU/WCU, créditos, requisição de transição, armazenamento de versão, tráfego) e qual antipattern a faz explodir?
4. **Migração e reversibilidade:** a mudança é expand/contract? Existe caminho de volta? Mudança de chave de partição exige cópia para novo contêiner/tabela [J: Cosmos DB].
5. **Operação:** novo armazenamento só com backup testado, monitoramento e runbook [J: Azure "add another model without operational maturity"].

---

## 1. Especialista relacional (OLTP: PostgreSQL, SQL Server, MySQL)

### 1.1 Escopo, quando usar e quando não

Usar para transações multi-entidade com consistência forte, restrições de integridade e consulta flexível: pedidos, estoque, ledger, cobrança [J: Azure]. Não usar como motor de varredura analítica massiva, como armazenamento de binários grandes (vai para objeto) nem como fila de alto volume sem desenho específico; escala horizontal exige sharding/particionamento e tem custo relevante [J: Azure]. Semiestruturado dentro do relacional é legítimo quando o documento é átomo que a regra de negócio não subdivide: `jsonb` com estrutura razoavelmente fixa e tamanho controlado, porque update trava a linha inteira [1F: PostgreSQL JSON types].

### 1.2 Boas práticas

**Modelagem e tipos.** Normalizar até 3FN no OLTP e desnormalizar só como decisão consciente [2F]. Toda tabela com PK; PK e UNIQUE criam B-tree automaticamente no PostgreSQL [1F]. Indexar colunas de FK: o PostgreSQL não indexa a coluna referenciadora e `DELETE`/`UPDATE` no pai varre o filho [2F: doc + squawk/strong_migrations]. `bigint`/identity em vez de `int`/`serial` [2F]. UUID como PK: preferir v7 (ordenado por tempo); `uuidv7()` é nativo no PostgreSQL 18 [J]. Tipos no PostgreSQL: `timestamptz`, `text` (com CHECK), `numeric`, `jsonb` em vez de `timestamp`, `char(n)`, `money`, `json` [2F: wiki "Don't Do This" + squawk]. `NOT EXISTS` em vez de `NOT IN (subquery)`; intervalos `>= a AND < b` em vez de `BETWEEN` com timestamp [1F].

**Índices.** Criar a partir das consultas reais (`WHERE`, `JOIN`, `ORDER BY`) [Heurística: Use The Index, Luke]. Em produção, `CREATE INDEX CONCURRENTLY` (fora de bloco de transação; se falhar deixa índice inválido a remover) [2F]; no MySQL 8.4, índice secundário é `INPLACE` com leitura e escrita liberadas [1F]. Índice parcial para unicidade condicional, sem substituir particionamento por muitos índices parciais disjuntos [1F]. Remover índice com `idx_scan = 0` após janela representativa [1F].

**Migrações (expand → migrate → contract).** Mudança incompatível segue Parallel Change [2F: Sato/Fowler; strong_migrations]. Rename nunca in-place com aplicação no ar: nova coluna, dual-write, backfill em lotes, migrar leitura, remover a antiga [2F]. Mudança de tipo reescreve tabela no PostgreSQL e exige `ALGORITHM=COPY` no MySQL: usar coluna nova + backfill [2F]. FK/CHECK com `NOT VALID` e depois `VALIDATE CONSTRAINT` [2F]. `SET NOT NULL` em tabela grande: CHECK `NOT VALID`, validar, então `SET NOT NULL` [2F]. `ADD COLUMN` com default não volátil é só metadado desde o PostgreSQL 11; no MySQL 8.4 é `INSTANT` por padrão [2F/1F]. `lock_timeout` e `statement_timeout` na sessão da migração, não no `postgresql.conf` [2F]. Backfill fora da transação de DDL, em lotes e com throttling [1F]. Fase contract (drop) em deploy separado [Interp. consolidada].

**Transações, isolamento e locks.** Defaults: PostgreSQL Read Committed; InnoDB REPEATABLE READ; SQL Server READ COMMITTED com RCSI desligado on-prem e ligado no Azure SQL Database [1F cada]. Mesmo nome de nível, semânticas diferentes entre motores (phantom, gap locks) [1F cada]. Em Repeatable Read/Serializable no PostgreSQL a aplicação deve reexecutar a transação em SQLSTATE `40001`; deadlock é `40P01` [J: apêndice de códigos de erro]. Prevenção de deadlock: ordem consistente de locks, transações curtas e sem interação de usuário, retry no aborto [2F]. SQL Server: a Microsoft recomenda o READ COMMITTED baseado em versionamento de linha para todas as aplicações que não dependem do comportamento bloqueante; a vítima recebe erro 1205 e a sessão `system_health` já captura `xml_deadlock_report` [J]. `idle_in_transaction_session_timeout` contra sessão ociosa com transação aberta (segura lock e trava vacuum) [1F].

**Acesso a dados.** N+1 resolvido com carga ansiosa (Django `select_related`/`prefetch_related`; Rails `includes`/`preload`/`eager_load`) e modo estrito em teste (Rails `strict_loading`) [2F]. Paginação por keyset em listas grandes; OFFSET computa e descarta linhas e gera duplicata/omissão com inserção concorrente [2F: Winand + PostgreSQL]. `LIMIT` sempre com `ORDER BY` determinístico [1F]. Pool pequeno: ponto de partida `(núcleos × 2) + spindles efetivos`, fórmula atribuída ao projeto PostgreSQL, com a ressalva do próprio texto de que não há análise para SSD e que SSD tende a pedir menos conexões [J: HikariCP; Heurística]. Atrás de PgBouncer em modo transaction não usar `SET`/`RESET`, `LISTEN`, cursores `WITH HOLD`, `PREPARE`/`DEALLOCATE` em SQL e advisory lock de sessão; prepared statements de protocolo funcionam com `max_prepared_statements > 0` [J].

### 1.3 Antipatterns com detecção

| # | Antipattern | Detecção mecânica | Evidência |
| --- | --- | --- | --- |
| R-01 | FK sem índice | `pg_constraint` (`contype='f'`) sem `pg_index` cujo prefixo cubra `conkey` (consulta na pesquisa, validar com índice de expressão e ordem de coluna) | 1F + Heurística |
| R-02 | Tabela sem PK | `information_schema.tables` LEFT JOIN `table_constraints` tipo `PRIMARY KEY` nulo | Heurística |
| R-03 | Migração bloqueante | **squawk** no CI (`squawk migrations/*.sql`) ou **strong_migrations**; grep mínimo `grep -rnP "CREATE (UNIQUE )?INDEX (?!CONCURRENTLY)"`, `grep -rniE "ALTER COLUMN .* TYPE\|RENAME (COLUMN\|TO)\|SET NOT NULL"`, ausência de `lock_timeout` | 2F |
| R-04 | Tipos problemáticos (PostgreSQL) | `information_schema.columns` com `timestamp without time zone`, `character`, `money`, `json`; squawk `prefer-timestamptz`, `ban-char-field`, `prefer-identity` | 2F |
| R-05 | N+1 | `strict_loading` em teste; em produção `pg_stat_statements` com `calls` alto e `mean_exec_time` baixo para `WHERE fk = $1` | 2F (problema) / Heurística (detector) |
| R-06 | OFFSET profundo | `grep -rniE "OFFSET\s+(\$\|:\|\?\|[0-9]{3,})\|\.offset\(\|\.skip\("`; OFFSET entre as mais caras em `pg_stat_statements` | 2F |
| R-07 | Soft delete generalizado sem índice parcial | `deleted_at`/`is_deleted` + índice `UNIQUE` sem predicado (`pg_index.indpred IS NULL`) na mesma tabela | Opinião (Brandur) + 1F (índice parcial) |
| R-08 | EAV | tabela com ≤5 colunas contendo par `attribute`/`value` | 2F (Karwin) / Heurística |
| R-09 | Transação longa / idle in transaction | `pg_stat_activity` com `state LIKE 'idle in transaction%'` ordenado por idade | 1F |
| R-10 | `NOLOCK`/READ UNCOMMITTED | `grep -rniE "WITH\s*\(\s*NOLOCK\s*\)\|READ UNCOMMITTED" --include=*.sql`; `sys.databases.is_read_committed_snapshot_on` | 1F |
| R-11 | Deadlock/serialização sem retry | ausência de tratamento de `40001\|40P01\|1205` na camada de dados | J (códigos) |
| R-12 | Pool incompatível com PgBouncer transaction | grep de `SET search_path\|LISTEN\|pg_advisory_lock\(` em código atrás de PgBouncer transaction | J |
| R-13 | `ALGORITHM=COPY`/`LOCK=EXCLUSIVE` forçado (MySQL) | `grep -rniE "ALGORITHM\s*=\s*COPY\|LOCK\s*=\s*(SHARED\|EXCLUSIVE)" migrations/` | 2F |
| R-14 | `SELECT *` em código de aplicação | SQLFluff `AM04` | 1F |
| R-15 | Analytics no primário OLTP | `pg_stat_statements` por `total_exec_time` com `GROUP BY`/`SUM(` no primário; Query Store no SQL Server | 2F (problema) |
| R-16 | Banco compartilhado entre serviços | `information_schema.role_table_grants` com INSERT/UPDATE/DELETE por schema cruzado com mapa de serviços | J (antipattern Azure) |

### 1.4 Decisões e trade-offs

Read Committed é barato e suficiente para operação de linha única ou com lock explícito; Serializable (SSI) protege invariantes entre linhas (saldo, limite) ao custo de retry obrigatório [1F]. Lock pessimista (`FOR UPDATE`) para recurso muito disputado; otimista (versão/ETag) quando conflito é raro. PK sequencial é compacta; UUID permite geração distribuída e o v7 reduz a penalidade de localidade [J para disponibilidade; benefício de localidade é Interp.]. Particionar tabela OLTP só quando ela passa da memória do servidor e com chave presente no `WHERE`; poucos milhares de partições é o limite confortável do planner [1F].

### 1.5 Fontes

[PostgreSQL docs](https://www.postgresql.org/docs/current/) (transaction-iso, explicit-locking, sql-createindex, sql-altertable, ddl-constraints, indexes-partial, ddl-partitioning, queries-limit, runtime-config-client, monitoring-stats, [functions-uuid](https://www.postgresql.org/docs/current/functions-uuid.html), [errcodes-appendix](https://www.postgresql.org/docs/current/errcodes-appendix.html)) · [PostgreSQL wiki, Don't Do This](https://wiki.postgresql.org/wiki/Don%27t_Do_This) · [MySQL 8.4 online DDL](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-operations.html) · [MySQL 8.4 isolation](https://dev.mysql.com/doc/refman/8.4/en/innodb-transaction-isolation-levels.html) · [SQL Server deadlocks guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-deadlocks-guide) · [SET TRANSACTION ISOLATION LEVEL](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql) · [Azure OLTP](https://learn.microsoft.com/en-us/azure/architecture/data-guide/relational-data/online-transaction-processing) · [Azure data models](https://learn.microsoft.com/en-us/azure/architecture/data-guide/technology-choices/understand-data-store-models) · [Parallel Change](https://martinfowler.com/bliki/ParallelChange.html) · [Use The Index, Luke — no-offset](https://use-the-index-luke.com/no-offset) · [Django QuerySet API](https://docs.djangoproject.com/en/5.2/ref/models/querysets/) · [Rails Active Record Query Interface](https://guides.rubyonrails.org/active_record_querying.html) · [HikariCP About Pool Sizing](https://github.com/brettwooldridge/HikariCP/wiki/About-Pool-Sizing) · [PgBouncer features](https://www.pgbouncer.org/features.html) · [squawk rules](https://squawkhq.com/docs/rules) · [strong_migrations](https://github.com/ankane/strong_migrations) · [Brandur, soft deletion](https://brandur.org/soft-deletion) · [Karwin, SQL Antipatterns](https://pragprog.com/titles/bksqla/sql-antipatterns/) · [SQLFluff rules](https://docs.sqlfluff.com/en/stable/reference/rules.html)

---

## 2. Especialista nosql (documento, chave-valor persistente, coluna larga, grafo)

### 2.1 Escopo, quando usar e quando não

Usar quando os padrões de acesso são conhecidos, estáveis e de alto volume, escala horizontal por partição é requisito e latência previsível vale mais que consulta ad hoc; "você não começa pelo modelo de dados, começa pelo modelo de consulta" [2F: AWS DynamoDB + Cassandra]. Não usar para consulta exploratória ou analítica, muitas relações N:N com integridade forte, ou domínio ainda em descoberta (single-table em estágio inicial é ruim para agilidade) [1F: DeBrie; AWS]. Sinal para reavaliar: joins ad hoc crescentes em document store → modelo de leitura relacional [J: Azure].

### 2.2 Boas práticas transversais

1. Inventariar padrões de acesso (quem lê, por qual chave, frequência, volume por chave, latência alvo) antes de escolher chave e índice [2F].
2. Chave de partição de alta cardinalidade, carga uniforme e alinhada ao predicado dominante; alta cardinalidade sozinha não basta — GUID aleatório que nenhuma consulta filtra torna quase toda leitura cross-partition [J: Cosmos DB].
3. Consistência como parâmetro por operação; leitura forte em sistema de quórum exige `W + R > RF` [2F].
4. Toda unidade de agregação com teto de crescimento (bucket por tempo ou contagem) [2F].
5. Índice secundário global é eventualmente consistente e custa escrita; projetar só o necessário [2F; J para Cosmos DB GSI].
6. Chave de partição é decisão de migração: no Cosmos DB não muda in place, exige mover para novo contêiner (container copy jobs) [J].

### 2.3 Documento — MongoDB e Cosmos DB

Modelar pelo que é acessado junto: embutir o que é lido junto e tem cardinalidade limitada; referenciar o que cresce sem limite [1F]. Limites: documento BSON até 16 MiB, 64 índices por coleção, aninhamento 100 [1F]. Shard key de alta cardinalidade, baixa frequência e não monotônica; chave monotônica → hashed sharding; `reshardCollection` (5.0+) e `analyzeShardKey` (7.0+) [1F]. Write concern: o default implícito é `w: "majority"` desde o 5.0, exceto quando há árbitro e os membros com dados não superam a maioria de votantes (P-S-A), caso em que cai para `w: 1`; a própria MongoDB recomenda P-S-S em vez de P-S-A [J]. Transações curtas (60 s default) com retry em `TransientTransactionError` [2F]. Cosmos DB: partição lógica até 20 GB e 10.000 RU/s; chave hierárquica até três níveis resolve o teto; transação multi-item só dentro de uma partição lógica; consulta cross-partition custa 2–3 RU por partição física extra [J]; consistência de sessão como default, strong/bounded staleness dobram o custo de leitura [1F].

### 2.4 Chave-valor persistente — DynamoDB

Cada partição física entrega no máximo 3.000 RCU e 1.000 WCU por segundo; adaptive capacity vale em on-demand e provisioned, mas não salva uma única chave acima do teto [J]. Item até 400 KB; transação até 100 itens/4 MB; `BatchWriteItem` 25, `BatchGetItem` 100; Query/Scan retornam até 1 MB; LSI limita item collection a 10 GB; leitura de GSI é só eventual [1F]. Boas práticas: `Query` e nunca `Scan` no caminho quente; sort key hierárquica (`TENANT#t1`, `ORDER#2026-09-26#123`); write sharding por sufixo calculado quando a leitura pontual precisa continuar possível; GSI com capacidade ≥ tabela; projeção `KEYS_ONLY`/`INCLUDE`; PITR e CMK para dado regulado (Checkov CKV_AWS_28, CKV_AWS_119) [1F].

### 2.5 Coluna larga — Cassandra

Uma tabela por consulta, desnormalizada; minimizar partições lidas por consulta [2F]. Partição idealmente < 100 MB e < 100.000 linhas, com bucketing (`sensor_id, dia`) [1F: DataStax]. `LOCAL_QUORUM` em leitura e escrita para leitura forte no datacenter [2F]. Defaults conferidos no `cassandra.yaml` do trunk: `tombstone_warn_threshold: 1000`, `tombstone_failure_threshold: 100000`, `batch_size_warn_threshold: 5KiB`, `batch_size_fail_threshold: 50KiB`, `unlogged_batch_across_partitions_warn_threshold: 10`, `materialized_views_enabled: false`; os guardrails `allow_filtering_enabled` e `secondary_indexes_enabled` vêm comentados com valor `true`, ou seja, **precisam ser desligados explicitamente** [J]. Índice secundário, se inevitável, SAI e restrito a consultas que já filtram a partição [1F]. LWT (Paxos) só para unicidade pontual [1F].

### 2.6 Grafo — Neo4j

Modelar a partir das consultas e testar com dados reais [1F]. Tipos de relacionamento específicos (`:TRANSFERIU_PARA`, não `:RELATED_TO`) [prática consolidada, fonte secundária]. Nó intermediário para evitar nó denso [2F]. No Neo4j 4.3+ um nó passa a ser tratado como denso a partir de 50 relacionamentos, de forma irreversível [J: blog de engenharia Neo4j].

### 2.7 Antipatterns com detecção

| # | Antipattern | Detecção | Evidência |
| --- | --- | --- | --- |
| N-01 | Array ilimitado (MongoDB) | `grep -rnE '\$push' src/ \| grep -v '\$slice'`; agregação com `$bsonSize` ordenada | 1F / Heurística |
| N-02 | Índice sem uso (MongoDB) | `$indexStats` com `accesses.ops == 0` após janela | 1F |
| N-03 | Coleção por tenant/dia | `db.getCollectionNames().length`; nome de coleção interpolado | 1F |
| N-04 | `$lookup` como join no caminho quente | `grep -rnc '\$lookup'` por arquivo | 1F |
| N-05 | Shard key monotônica/baixa cardinalidade | `analyzeShardKey` (7.0+); `sh.status()` | 1F |
| N-06 | Partition key de baixa cardinalidade (Cosmos/DynamoDB) | IaC: `grep -nE '(hash_key\|partition_key_paths?)\s*=\s*.*"/?(status\|type\|date\|country\|state\|category)"'`; runtime: Normalized RU por PartitionKeyRangeId, Contributor Insights | J (antipattern documentado pela Microsoft) |
| N-07 | Write concern `w:1` para dado crítico ou topologia P-S-A | `grep -rnE "w\s*[:=]\s*1\b\|WriteConcern\.(W1\|ACKNOWLEDGED)"`; `rs.conf()` com árbitro | J |
| N-08 | Scan no caminho da requisição (DynamoDB) | `grep -rnE '\b(ScanCommand\|\.scan\(\|Scan\()'` | 1F |
| N-09 | Item que cresce (DynamoDB) | `grep -rnE 'list_append'` | 1F |
| N-10 | GSI subprovisionado ou `ALL` por padrão | `describe-table` comparando WCU; `grep -n 'projection_type\s*=\s*"ALL"' *.tf` | 1F |
| N-11 | Leitura de GSI tratada como forte | `ConsistentRead: true` junto de `IndexName` | 2F |
| N-12 | `TransactWriteItems` como padrão | contagem de `TransactWriteItems\|transactWrite` | 1F |
| N-13 | `ALLOW FILTERING` / 2i como consulta principal (Cassandra) | `grep -rniE 'ALLOW\s+FILTERING\|CREATE\s+(CUSTOM\s+)?INDEX'`; guardrails desligados no yaml | 2F + J (defaults) |
| N-14 | Partição ilimitada / tombstones (fila sobre Cassandra) | `nodetool tablehistograms`; `grep -i tombstone system.log`; DDL sem componente de tempo na partition key | 2F |
| N-15 | Batch multi-partição como otimização | `grep -rniE 'BEGIN\s+(UNLOGGED\s+)?BATCH'` | 2F + J (thresholds) |
| N-16 | Supernó (Neo4j) | `MATCH (n) WITH n, COUNT { (n)--() } AS g WHERE g > 100000 RETURN labels(n), g ORDER BY g DESC LIMIT 20` (Neo4j 5) | 2F conceito / Heurística limiar |
| N-17 | Relacionamento genérico | `CALL db.relationshipTypes()`; grep `-\[:?(RELATED_TO\|HAS\|LINK\|CONNECTED)\]` | fonte secundária |

### 2.8 Decisões e trade-offs

Embutir × referenciar: uma ida de leitura contra custo de atualização duplicada. Hashed sharding distribui escrita e perde range query pela chave. Cosmos `/id` como chave é ótimo para leitura pontual e péssimo para qualquer outro filtro [J]. Single-table reduz round-trips e custo e encarece mudança de padrão de acesso; on-demand elimina planejamento, provisioned com auto scaling é mais barato em carga estável. `QUORUM` global × `LOCAL_QUORUM`: consistência entre DCs contra latência inter-região. Propriedade × nó no grafo: barato × travessável.

### 2.9 Fontes

[MongoDB anti-patterns](https://www.mongodb.com/docs/manual/data-modeling/design-antipatterns/) · [MongoDB limits](https://www.mongodb.com/docs/manual/reference/limits/) · [MongoDB shard key](https://www.mongodb.com/docs/manual/core/sharding-choose-a-shard-key/) · [MongoDB write concern](https://www.mongodb.com/docs/manual/reference/write-concern/) · [Cosmos DB partitioning](https://learn.microsoft.com/en-us/azure/cosmos-db/partitioning-overview) · [Cosmos DB consistency](https://learn.microsoft.com/en-us/azure/cosmos-db/consistency-levels) · [DynamoDB partition key design](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-design.html) · [DynamoDB write sharding](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-sharding.html) · [DynamoDB constraints](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Constraints.html) · [DeBrie, single-table](https://www.alexdebrie.com/posts/dynamodb-single-table/) · [Cassandra data modeling](https://cassandra.apache.org/doc/latest/cassandra/developing/data-modeling/data-modeling_rdbms.html) · [cassandra.yaml trunk](https://raw.githubusercontent.com/apache/cassandra/trunk/conf/cassandra.yaml) · [DataStax best practices](https://docs.datastax.com/en/cql/hcd/data-modeling/best-practices.html) · [AxonOps anti-patterns](https://axonops.com/docs/data-platforms/cassandra/data-modeling/anti-patterns/) · [Neo4j modeling designs](https://neo4j.com/docs/getting-started/data-modeling/modeling-designs/) · [Neo4j relationship chain locks (4.3)](https://neo4j.com/blog/developer/relationship-chain-locks-dont-block-the-rock/) · [Checkov policy index](https://www.checkov.io/5.Policy%20Index/terraform.html)

---

## 3. Especialista cache (Redis/Valkey e compatíveis, cache local)

### 3.1 Escopo, quando usar e quando não

Cache é cópia derivada de outra fonte, para dado lido muitas vezes por escrita e consumidor que tolera consistência eventual; só adicionar com necessidade justificada por custo, latência ou disponibilidade [1F: AWS Builders' Library]. Não usar quando a maioria das requisições não vai acertar; para dado sensível em cache compartilhado ("Always retrieve this type of data from the primary source"); para dataset estático que cabe em memória (carregar no startup) [2F: Microsoft Learn + AWS].

Definições: cache-aside lê do cache e, no miss, da origem e popula; na escrita grava a origem e invalida. Read-through/write-through delegam à camada de cache; write-through custa popular dado que nunca será lido e se combina com lazy loading e TTL. Write-behind confirma antes de gravar a origem [2F].

### 3.2 Boas práticas

1. Invalidação: atualizar a origem **antes** de remover a chave, e após o commit; delete em vez de set, porque delete é idempotente e tolera mensagem duplicada ou fora de ordem [2F: Microsoft + NSDI 2013].
2. Todo valor com TTL proporcional à tolerância a dado velho [2F]; jitter no TTL contra expiração sincronizada [2F, fontes secundárias; percentual é Heurística].
3. Stampede: single-flight, leases, ou expiração antecipada probabilística (XFetch) [2F: AWS, NSDI 2013, VLDB 2015]; soft TTL + hard TTL para servir velho com a origem fora [1F]; cache negativo com TTL menor [1F]; formato serializado versionado na chave (`svc:v2:...`) [1F].
4. Origem dimensionada para sobreviver a cache frio [1F].
5. Métricas: hit ratio `keyspace_hits / (keyspace_hits + keyspace_misses)`, `evicted_keys`, `expired_keys` [J].
6. Redis: `maxmemory` explícito (o default em 64 bits é 0, sem limite), com folga para buffers de replicação e AOF, que não contam para eviction [J]. Política: `allkeys-lru` é o default recomendado quando um subconjunto é muito mais acessado; `allkeys-lfu` quando frequência pesa mais; `volatile-*` se comporta como `noeviction` se nenhuma chave tem TTL; a doc recomenda instâncias separadas para cache e chaves persistentes [J]. Redis 8.6 acrescentou `allkeys-lrm`/`volatile-lrm` (menos recentemente modificado) [J].
7. Persistência: RDB aceita perder minutos; AOF `everysec` perde até ~1 s; cache puro pode desligar [1F].
8. Cluster: 16.384 slots; multi-chave só no mesmo slot (hash tags `{user:42}`); replicação assíncrona pode perder escrita confirmada em failover, `WAIT` reduz sem eliminar [1F].
9. Segurança: nunca exposto à internet; ACL (6+), TLS em cliente, replicação e barramento; bloquear `CONFIG`, `FLUSHALL`, `DEBUG`, `KEYS` por ACL; rodar sem root [2F]. `SCAN`, nunca `KEYS`, em código [1F].

### 3.3 Antipatterns com detecção

| # | Antipattern | Detecção | Evidência |
| --- | --- | --- | --- |
| C-01 | Invalidação na ordem errada (delete antes do commit) | `grep -rnB3 -A3 -E '\.(del\|delete\|evict\|invalidate)\('` e revisar ordem em relação ao commit | 2F / Heurística |
| C-02 | Set sem TTL | `grep -rnE '\.(set\|hset\|hmset)\(' \| grep -viE 'ex=\|px=\|EX\|PX\|expire\|ttl\|timeout'`; amostra `redis-cli --scan \| head -1000 \| xargs -n1 redis-cli TTL \| grep -c '^-1$'` | Heurística |
| C-03 | TTL constante sem jitter em carga em lote | TTL literal sem `random`; misses periódicos iguais ao TTL | 2F secundárias |
| C-04 | Stampede | ausência de `singleflight\|SET.*NX\|setnx\|Lock\(` no caminho de miss; traces com N consultas idênticas | 2F |
| C-05 | Chave quente | `redis-cli --hotkeys` (exige política LFU); CPU por shard | 1F |
| C-06 | Chave grande | `redis-cli --bigkeys`, `--memkeys` (SCAN, seguros com `-i`) | 1F |
| C-07 | Cache como fonte da verdade | `CONFIG GET save appendonly maxmemory-policy`; escrita em Redis sem escrita em banco no mesmo fluxo | J (eviction) |
| C-08 | Cache local em frota sem TTL | `lru_cache`, `Caffeine`, `MemoryCache`, `node-cache` sem `expireAfterWrite`/TTL | 2F |
| C-09 | `KEYS` em produção | `grep -rnE '\b(KEYS\|\.keys\()'`; `SLOWLOG GET 50` | 1F |
| C-10 | `maxmemory 0` ou `noeviction` em instância de cache | `CONFIG GET maxmemory maxmemory-policy`; `grep -nE 'maxmemory-policy.*noeviction' infra/` | J |
| C-11 | Redis exposto/sem auth/sem TLS | `grep -nE '^(protected-mode no\|bind 0\.0\.0\.0)' redis.conf`; Checkov CKV_AWS_29/30/31/191, CKV_AZURE_89/148, CKV_GCP_95/97 | 2F |
| C-12 | Multi-chave cross-slot | erro `CROSSSLOT`; testes de integração contra cluster | 1F |
| C-13 | Cache e estado durável (fila, lock, sessão) na mesma instância com eviction | `redis-cli --scan \| cut -d: -f1 \| sort \| uniq -c` + política | J |
| C-14 | Comando O(N) em estrutura grande | `SLOWLOG GET`; `--bigkeys` | 1F |
| C-15 | PAN/SAD em cache | ver seção 7 (antipattern T-01) | J (PCI) |

Write-behind para dado que não pode ser perdido fica como Interp. (risco lógico, não quantificado pelas fontes).

### 3.4 Decisões e trade-offs

Cache-aside é simples e resiliente a nó vazio, com staleness entre escrita e próxima leitura; write-through dá frescor ao custo de escrever o que nunca será lido. Cache local é rápido e barato, incoerente entre instâncias e escala a carga na origem com o tamanho da frota. Standalone + Sentinel aceita multi-chave livre; cluster escala e impõe hash tags. TTL curto reduz staleness e aumenta carga; LRU × LFU se decide medindo `INFO stats`.

### 3.5 Fontes

[Microsoft Cache-Aside](https://learn.microsoft.com/en-us/azure/architecture/patterns/cache-aside) · [AWS Builders' Library, caching](https://aws.amazon.com/builders-library/caching-challenges-and-strategies/) · [AWS caching patterns](https://docs.aws.amazon.com/whitepapers/latest/database-caching-strategies-using-redis/caching-patterns.html) · [Nishtala et al., NSDI 2013](https://www.usenix.org/system/files/conference/nsdi13/nsdi13-final170_update.pdf) · [Vattani et al., VLDB 2015](http://www.vldb.org/pvldb/vol8/p886-vattani.pdf) · [Redis eviction](https://redis.io/docs/latest/develop/reference/eviction/) · [Redis persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/) · [Redis cluster spec](https://redis.io/docs/latest/operate/oss_and_stack/reference/cluster-spec/) · [Redis security](https://redis.io/docs/latest/operate/oss_and_stack/management/security/) · [redis-cli](https://redis.io/docs/latest/develop/tools/cli/) · [Checkov](https://www.checkov.io/5.Policy%20Index/terraform.html)

---

## 4. Especialista object-storage (S3, GCS, Azure Blob, MinIO; zonas de lake no nível de objeto)

### 4.1 Escopo, quando usar e quando não

Objetos imutáveis ou raramente reescritos (arquivo, mídia, backup, export, zona bruta de lake), acesso por chave, custo por GB baixo, ciclo de vida automatizado, retenção regulatória (WORM) [J: Azure "object data stores"]. Não usar para atualização parcial frequente, metadados consultáveis como banco, ou milhões de objetos minúsculos lidos individualmente com latência de milissegundos. Concorrência entre escritores: S3 é last-writer-wins por padrão, mas desde 2024 oferece escrita condicional (`If-None-Match` em agosto; `If-Match` com ETag em novembro, com política de bucket podendo exigi-la via `s3:if-match`/`s3:if-none-match`) e, desde setembro de 2025, delete condicional [J: anúncios AWS]. Isso permite controle otimista de concorrência em objeto, não lock nem atomicidade entre chaves; estado mutável compartilhado continua pertencendo a banco.

### 4.2 Fatos de plataforma

- S3: consistência forte read-after-write para PUT, DELETE e LIST; configuração de bucket é eventualmente consistente; sem atomicidade entre chaves [1F].
- S3 escala para ≥3.500 escritas e 5.500 leituras por segundo por prefixo particionado; a orientação antiga de randomizar prefixo foi removida em 2018 [1F]. GCS parte de ~1.000 escritas/5.000 leituras por bucket, rampa de no máximo dobrar a cada 20 min, e **ainda** recomenda evitar nome sequencial no início da chave [1F]. Código portátil evita prefixo puramente sequencial [Interp.].
- Novos buckets S3 têm Block Public Access e ACL desabilitada desde abril de 2023; SSE-S3 em todo objeto novo desde janeiro de 2023 [1F]. Azure proíbe acesso anônimo por default em contas ARM; GCS tem public access prevention e uniform bucket-level access [2F].
- URL pré-assinada: máximo 7 dias no S3 (SigV4) e no GCS V4; é bearer token. Azure recomenda user delegation SAS com expiração curta e desabilitar Shared Key [2F].
- WORM: S3 Object Lock (compliance: nem o root apaga; exige versionamento), GCS Bucket Lock, Azure immutable storage; avaliados para SEC 17a-4(f)/FINRA/CFTC [2F].
- Multipart: 10.000 partes, 5 MiB–5 GiB, objeto até 48,8 TiB; partes de upload incompleto são cobradas até abort [1F].
- Eventos S3: pelo menos uma vez, normalmente em segundos; gravar no bucket que dispara o evento pode gerar loop [1F].
- Lifecycle: desde setembro de 2024 objetos < 128 KB não transitam por default (a cobrança por requisição de transição supera a economia); duração mínima 90 dias (Glacier Instant e Flexible) e 180 dias (Deep Archive); cada objeto arquivado em Flexible/Deep Archive carrega 40 KB de metadados (8 KB cobrados em Standard, 32 KB na classe de destino) [J].
- S3 Bucket Keys reduzem chamadas ao KMS em até 99% com SSE-KMS e mudam o contexto de criptografia para o ARN do bucket [1F].
- MinIO: a edição comunitária entrou em modo de manutenção em 2025 (sem binários oficiais, console removida) e o repositório `minio/minio` foi arquivado em 25/04/2026, agora somente leitura [J: página do repositório no GitHub; 2F com Blocks & Files].

### 4.3 Boas práticas

1. Bloquear acesso público em nível de conta/organização (S3 BPA com as quatro opções, GCS PAP enforced por org policy, Azure `AllowBlobPublicAccess=false` + Azure Policy deny); hospedagem pública em conta/bucket separado atrás de CDN [2F].
2. ACLs desabilitadas; acesso só por política (bucket owner enforced; uniform bucket-level access) [2F].
3. Criptografia com chave do cliente para dado regulado (SSE-KMS + Bucket Key, CMEK, CMK), com política de chave de menor privilégio e rotação [2F].
4. Lifecycle sempre: abortar multipart incompleto (ex.: 7 dias), expirar versões não correntes, transicionar por idade só objeto grande o bastante (usar `ObjectSizeGreaterThan`), expirar temporários [2F + J].
5. Versionamento em bucket de dado de negócio, com expiração de versões não correntes [2F].
6. WORM para trilha de auditoria e registro regulatório; testar em governance/unlocked antes de travar, porque compliance é irreversível [2F]. Conciliar com LGPD antes de travar (seção 7).
7. URL pré-assinada/SAS de minutos, um objeto e um método, restrita por política (`s3:signatureAge`, `aws:SourceIp`/`aws:SourceVpce`); validar o conteúdo enviado [2F]. É a forma válida de entregar objeto a terceiro sem abrir o bucket (compatível com a regra REST/fila externo).
8. Layout de chave por domínio/zona e ciclo de vida (`raw/`, `tmp/`), partição por data estilo Hive **para arquivos brutos**; no GCS, não começar a chave por timestamp [2F]. Tabelas silver/gold seguem a regra de particionamento do especialista analítico (0.3 item 4).
9. Consumidor de evento idempotente (at-least-once) e trigger restrito a prefixo de entrada, com saída em outro prefixo/bucket [1F].
10. Logging de acesso (server access logs/CloudTrail data events, Azure Storage logs) e inventário (S3 Inventory, blob inventory) [2F].
11. Zonas de lake: bronze imutável no formato original, com acesso restrito; silver/gold em formato de tabela transacional; contêineres/buckets separados por camada [2F: Databricks + Microsoft Fabric]; arquivos de 128 MB a 1 GB nas camadas de consumo [1F: Fabric]. Mascarar/tokenizar PAN e CPF ao sair do bronze [Interp. apoiada em PCI 3.5.1].

### 4.4 Antipatterns com detecção

| # | Antipattern | Detecção | Evidência |
| --- | --- | --- | --- |
| O-01 | Bucket público | Checkov CKV2_AWS_6, CKV_AWS_20/53/54/55/56/57/70, CKV_GCP_28/29/114, CKV_AZURE_34/59/190; `aws s3api get-public-access-block`; IAM Access Analyzer; `gcloud storage buckets describe ... publicAccessPrevention`; Resource Graph `allowBlobPublicAccess` | 2F |
| O-02 | URL pré-assinada/SAS longa ou ampla | `grep -rnE '(ExpiresIn\|expires_in\|expiresIn\|Expires)\s*[:=]\s*[0-9]{4,}'` (revisar > 900–3600 s); `generate_(account\|container)_sas\|AccountSasBuilder`; Checkov CKV2_AZURE_40 | 2F / Heurística limiar |
| O-03 | Multipart órfão | `aws s3api list-multipart-uploads`; Checkov CKV_AWS_300; Storage Lens | 2F |
| O-04 | Versionamento sem expiração de não correntes | lifecycle sem `NoncurrentVersionExpiration`; Checkov CKV2_AWS_61 | 1F |
| O-05 | Transição de objeto pequeno/de vida curta para classe fria | S3 Inventory + Athena `GROUP BY storage_class`; regra sem `ObjectSizeGreaterThan`; configuração pré-2024 que manteve o comportamento antigo | J |
| O-06 | Loop de evento | `aws_s3_bucket_notification` cuja função grava no mesmo bucket sem `filter_prefix` distinto | 1F |
| O-07 | Consumidor de evento não idempotente | handler sem chave de dedupe (`eTag`/`versionId`) nem upsert | 1F |
| O-08 | SSE-KMS sem Bucket Key em bucket de alto volume | `grep -nA5 'sse_algorithm\s*=\s*"aws:kms"' *.tf` sem `bucket_key_enabled` | 1F |
| O-09 | Prefixo sequencial no GCS | amostra de nomes começando por `\d{4}-\d{2}-\d{2}` | 1F |
| O-10 | Bucket como banco com read-modify-write concorrente sem escrita condicional | get→modify→put na mesma chave sem `If-Match`/`IfMatch`/`if_match` | J (recurso existe) / Heurística (detector) |
| O-11 | MinIO comunitário arquivado em produção | `grep -rnE 'image:\s*minio/minio'` + data da tag; plano de migração ou suporte comercial | J |
| O-12 | Small files no lake | S3 Inventory + Athena agrupando por prefixo com `avg(size) < 16 MiB` | Heurística limiar |
| O-13 | Bronze mutável | `grep -rnE 'overwrite\|MERGE INTO\|DELETE FROM' jobs/ \| grep -iE 'raw\|bronze'`; ausência de política negando `DeleteObject` no prefixo | 2F princípio |
| O-14 | Diretório de alta cardinalidade (`user_id=`) | `grep -rnE 'partitionBy\((.*(id\|uuid\|user\|customer))'` | Interp. |

### 4.5 Decisões e trade-offs

SSE-S3 é gratuito; SSE-KMS dá controle, trilha e revogação com custo e cota (mitigados por Bucket Key). Object Lock governance permite bypass com permissão; compliance só se desfaz apagando a conta. Proxy de upload pela aplicação dá validação síncrona; URL pré-assinada escala e barateia, mas exige validação posterior. Versionamento protege contra erro e ransomware ao custo de armazenamento. Intelligent-Tiering para acesso imprevisível; regras manuais para padrão conhecido.

### 4.6 Fontes

[S3 user guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html) · [S3 performance](https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance.html) · [S3 lifecycle transitions](https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html) · [S3 conditional writes (ago/2024)](https://aws.amazon.com/about-aws/whats-new/2024/08/amazon-s3-conditional-writes) · [S3 If-Match (nov/2024)](https://aws.amazon.com/about-aws/whats-new/2024/11/amazon-s3-functionality-conditional-writes) · [S3 enforcement de escrita condicional](https://aws.amazon.com/about-aws/whats-new/2024/11/amazon-s3-enforcement-conditional-write-operations-general-purpose-buckets) · [S3 conditional deletes (set/2025)](https://aws.amazon.com/about-aws/whats-new/2025/09/amazon-s3-conditional-deletes-s3-general-purpose-buckets) · [S3 Block Public Access](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html) · [S3 Bucket Keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html) · [S3 Object Lock](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html) · [S3 presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html) · [S3 event notifications](https://docs.aws.amazon.com/AmazonS3/latest/userguide/NotificationHowTo.html) · [GCS request rate](https://docs.cloud.google.com/storage/docs/request-rate) · [GCS public access prevention](https://docs.cloud.google.com/storage/docs/public-access-prevention) · [GCS Bucket Lock](https://docs.cloud.google.com/storage/docs/bucket-lock) · [Azure SAS](https://learn.microsoft.com/en-us/azure/storage/common/storage-sas-overview) · [Azure immutable storage](https://learn.microsoft.com/en-us/azure/storage/blobs/immutable-storage-overview) · [Microsoft Fabric medallion](https://learn.microsoft.com/en-us/fabric/onelake/onelake-medallion-lakehouse-architecture) · [MinIO repositório (arquivado)](https://github.com/minio/minio/issues/21714) · [Blocks & Files, MinIO](https://blocksandfiles.com/2025/06/19/minio-removes-management-features-from-basic-community-edition-object-storage-code/)

---

## 5. Especialista analitico (OLAP, warehouse, lakehouse, dbt)

### 5.1 Escopo, quando usar e quando não

Varredura e agregação histórica em larga escala, BI, ciência de dados, com armazenamento colunar e modelo desnormalizado [2F]. Não usar como backend transacional, para lookup de baixa latência nem como fonte da verdade operacional; não montar warehouse quando réplica de leitura ou columnstore HTAP (índice columnstore não clusterizado sobre tabela OLTP no SQL Server) resolve o volume atual [1F]. Separar OLTP de OLAP quando agregação pesada disputa recurso com transação [2F].

### 5.2 Boas práticas — modelagem dimensional

Processo de quatro passos (processo de negócio, **grão**, dimensões, fatos); grão atômico; grãos diferentes nunca na mesma fato [1F: Kimball]. Tipos de fato (transação, snapshot periódico, acumulado, factless) e de medida (aditiva, semiaditiva, não aditiva) [1F]. Chave substituta nas dimensões (exceção aceitável: data) [1F]. Dimensões conformadas e bus matrix [1F]. Dimensões achatadas (star), evitando snowflake [1F]. SCD1 sobrescreve; SCD2 adiciona linha com início, fim e indicador de corrente [2F: Kimball + dbt]. Junk, degenerate e role-playing dimensions [1F].

### 5.3 Boas práticas — plataforma, camadas e ELT

1. Lakehouse: o paper CIDR 2021 aponta os problemas da arquitetura lake + warehouse (consistência entre as duas, dado defasado, suporte limitado a ML, custo duplicado) e define lakehouse como armazenamento barato com recursos de SGBD (ACID, versionamento, auditoria, indexação) [2F: CIDR 2021 + VLDB 2020]. A tese de que o warehouse "vai definhar" é de autores da Databricks e entra como opinião de fornecedor.
2. Formato de tabela aberto (Iceberg, Delta, Hudi) quando há múltiplos motores ou exigência de evitar lock-in; warehouse gerenciado quando a prioridade é operação simples e SQL [Interp.].
3. Camadas bronze → silver → gold (recomendação, não requisito) ≡ dbt staging (`stg_`) → intermediate (`int_`) → marts (`fct_`/`dim_`) [2F no princípio].
4. ELT quando o alvo tem computação elástica; ETL quando o alvo é limitado ou compliance exige staging auditado antes da carga [1F: Azure].

### 5.4 Boas práticas — particionamento, clustering e manutenção

1. Não superparticionar. Databricks: não particionar abaixo de 1 TB, liquid clustering de 1 a 100 TB, partição com ≥ 1 GB, e liquid clustering recomendado para todas as tabelas gerenciadas [J]. BigQuery: preferir clustering quando o particionamento deixaria ~< 10 GB por partição [J]. Os limiares são de cada produto e não se transferem entre produtos.
2. Clustering/ordenação por colunas de filtro; Snowflake: clustering key só em tabela multi-TB com consulta seletiva, da menor para a maior cardinalidade, e reclustering consome créditos [1F]. Delta `ZORDER BY` perde eficácia a cada coluna adicionada [1F].
3. Particionamento oculto (Iceberg): o motor deriva a partição (`day(event_time)`), faz pruning sem o consumidor conhecer o layout e evolui o esquema de partição sem reescrever; no estilo Hive, formato errado da coluna de partição dá resultado silenciosamente incorreto e esquecer o filtro dá varredura total [1F: Iceberg].
4. Manutenção periódica: Delta `OPTIMIZE`/`VACUUM`; Iceberg expire snapshots, remove old metadata, delete orphan files, compact data files, rewrite manifests [2F]. É custo operacional real do lakehouse e entra na decisão warehouse × lakehouse.
5. Data skipping por min/max funciona melhor com dado ordenado pelas colunas de filtro [2F].

### 5.5 Boas práticas — dbt, qualidade e contratos

1. Convenções `stg_`/`int_`/`fct_`/`dim_` [1F].
2. Testes em todo modelo: `unique` + `not_null` na chave de grão, `relationships`, `accepted_values` [1F].
3. `source freshness` com `warn_after`/`error_after` e `loaded_at_field` [1F].
4. Incremental com `unique_key` e janela de lookback para fato atrasado, mais `--full-refresh` periódico; microbatch com `event_time`, `batch_size`, `lookback` [1F].
5. SCD2 com `dbt snapshot`: estratégia `timestamp` recomendada (robusta a colunas novas/removidas), `check` só sem `updated_at` confiável; `hard_deletes` (`ignore` default, `invalidate`, `new_record` que grava a exclusão como linha com `dbt_is_deleted`) a partir da v1.9, substituindo `invalidate_hard_deletes`; `dbt_valid_to_current` para marcador de linha corrente [J].
6. Contratos de modelo (`contract: enforced: true`) nos modelos públicos; remover coluna, mudar tipo ou remover constraint é breaking change e gera nova versão [1F]. Entre produtor e consumidor fora do dbt: Open Data Contract Standard (Bitol, LF AI & Data) [1F].
7. Lint: dbt-project-evaluator e SQLFluff [1F].

### 5.6 Antipatterns com detecção

| # | Antipattern | Detecção | Evidência |
| --- | --- | --- | --- |
| A-01 | Grão misto/não declarado | `SELECT <cols_grão>, count(*) FROM fct GROUP BY <cols_grão> HAVING count(*) > 1` | 1F |
| A-02 | Fato ligada por chave natural a dimensão SCD2 | `SELECT nk, count(*) FROM dim WHERE is_current GROUP BY nk HAVING count(*) > 1`; colunas de junção da fato não `*_sk` | 2F |
| A-03 | SCD2 com sobreposição/buraco | `lead(valid_from) OVER (PARTITION BY nk ORDER BY valid_from)` comparado a `valid_to` | Heurística |
| A-04 | Snowflake / OLTP replicado como warehouse | dbt-project-evaluator "Models with Too Many Joins"; contagem de `JOIN` em `models/marts` | 1F |
| A-05 | Superparticionamento / arquivos pequenos | tamanho por partição (INFORMATION_SCHEMA/`DESCRIBE DETAIL`/tabela `files` do Iceberg — sintaxe a confirmar); contagem em `pg_inherits` | 2F problema / Heurística detector |
| A-06 | Partição Hive manual em tabela | `grep -rniE "PARTITIONED BY \(\|INSERT .* PARTITION \("` + consultas sem predicado de partição | 1F |
| A-07 | Clustering em cardinalidade errada | revisão de `cluster_by` nos configs dbt | 1F |
| A-08 | Incremental sem `unique_key` ou sem lookback | `grep -rlE "materialized\s*=\s*'incremental'" models/ \| xargs grep -L "unique_key"` | 1F |
| A-09 | Modelo público sem contrato | dbt-project-evaluator "Public Models Without Contracts" | 1F |
| A-10 | Mart lendo source direto | evaluator "Direct Join to Source"; `grep -rn "source(" models/marts/` | 1F |
| A-11 | Chave de grão sem teste | evaluator "Missing Primary Key Tests" | 1F |
| A-12 | `SELECT *` em marts | SQLFluff `AM04` | 1F |
| A-13 | Data swamp | dataset sem catálogo/owner/contrato; objeto em bucket sem tabela registrada | 1F (CIDR) |
| A-14 | Snapshot com `invalidate_hard_deletes` legado | `grep -rn "invalidate_hard_deletes" snapshots/` → migrar para `hard_deletes` | J |

### 5.7 Decisões e trade-offs

Warehouse gerenciado × lakehouse aberto: simplicidade e SQL maduro contra formato aberto e armazenamento único, com o custo de manutenção de tabela. Particionar × clusterizar: pruning previsível e expiração por partição contra granularidade fina sem explosão de metadados [J: BigQuery]. SCD1 × SCD2: história contra chave substituta e join cuidadoso. Incremental × full refresh: custo contra drift. Contrato rígido × agilidade: coordenação contra quebra silenciosa.

### 5.8 Fontes

[Kimball techniques](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/) · [Lakehouse, CIDR 2021](https://www.cidrdb.org/cidr2021/papers/cidr2021_paper17.pdf) · [Delta Lake, VLDB 2020](https://people.eecs.berkeley.edu/~matei/papers/2020/vldb_delta_lake.pdf) · [Iceberg partitioning](https://iceberg.apache.org/docs/latest/partitioning/) · [Iceberg maintenance](https://iceberg.apache.org/docs/latest/maintenance/) · [Delta optimizations](https://docs.delta.io/latest/optimizations-oss.html) · [Databricks when to partition](https://docs.databricks.com/aws/en/tables/partitions) · [Databricks medallion](https://docs.databricks.com/aws/en/lakehouse/medallion) · [BigQuery partitioned tables](https://docs.cloud.google.com/bigquery/docs/partitioned-tables) · [Snowflake clustering keys](https://docs.snowflake.com/en/user-guide/tables-clustering-keys) · [Azure ETL/ELT](https://learn.microsoft.com/en-us/azure/architecture/data-guide/relational-data/etl) · [SQL Server columnstore](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview) · [dbt structure](https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview) · [dbt contracts](https://docs.getdbt.com/docs/mesh/govern/model-contracts) · [dbt snapshots](https://docs.getdbt.com/docs/build/snapshots) · [dbt data tests](https://docs.getdbt.com/docs/build/data-tests) · [dbt incremental](https://docs.getdbt.com/best-practices/materializations/4-incremental-models) · [dbt-project-evaluator](https://dbt-labs.github.io/dbt-project-evaluator/latest/rules/) · [ODCS](https://bitol-io.github.io/open-data-contract-standard/latest/) · [SQLFluff](https://docs.sqlfluff.com/en/stable/reference/rules.html)

---

## 6. Especialista streaming-eventos (RabbitMQ em profundidade; Kafka; padrões de integração)

### 6.1 Escopo e premissa

RabbitMQ é o broker da stack. Usar fila RabbitMQ para distribuir trabalho entre consumidores concorrentes, rotear por regra, desacoplar cadência e processar tarefa com retry; cada mensagem é unidade de trabalho consumida e descartada [Interp. sobre R1/R8]. RabbitMQ Streams (mesmo broker) para fan-out grande, replay por offset/timestamp, alto throughput e backlog grande com pouca memória [J]. Kafka quando o requisito é log durável reprocessável, dezenas de grupos consumidores, ecossistema Connect/CDC/Streams ou throughput acima do cluster RabbitMQ [Interp.]. Desde o Kafka 4.2 os share groups (KIP-932, "Queues for Kafka") estão declarados prontos para produção [J]; ainda assim, com RabbitMQ na stack, não há motivo para migrar fila de trabalho para Kafka [Interp.].

Premissa sistêmica: a entrega prática ponta a ponta é **at-least-once** em RabbitMQ, Kafka (commit após processamento), Debezium e relay de outbox; idempotência do consumidor é obrigatória [2F].

### 6.2 RabbitMQ — estado atual da plataforma (4.x)

- **Filas espelhadas clássicas foram removidas no 4.0**; HA de fila é quorum queue [2F; J: deprecated features/quorum docs]. Qualquer conselho de `ha-mode` é obsoleto.
- **4.3: Mnesia removido**; Khepri é o único metastore, e as estratégias de partição `pause_if_all_down`, `pause_minority` e `autoheal` foram removidas junto [J: blog 4.3].
- **Plugin `rabbitmq-delayed-message-exchange` depreciado e arquivado** por limitações arquiteturais [J: blog 4.3; 2F com o repositório].
- **Retry atrasado nativo em quorum queue (4.3):** `delayed-retry-type` (`disabled`, `all`, `returned`, `failed`), `delayed-retry-min` (ms, obrigatório se ligado), `delayed-retry-max` (ms); atraso = `min(delayed-retry-min × delivery-count, delayed-retry-max)`, backoff linear com teto e sem jitter [J].
- **Filas clássicas transientes não exclusivas** são depreciadas e não podem ser declaradas por padrão a partir do 4.3.0 [J].
- **Lazy queues:** a configuração não tem efeito desde 3.12; filas clássicas v2 já mantêm só um subconjunto em memória [J]. Artigos anteriores a 2023 que recomendam lazy estão desatualizados.
- **Quorum:** `delivery-limit` padrão 20 desde 4.0; não usar para backlog de 5M+ mensagens, fan-out grande (streams servem melhor) ou filas temporárias (transientes, exclusivas, alta rotatividade); ≥ 32 bytes de metadados por mensagem em memória; nó com pelo menos 3× o tamanho efetivo do WAL em RAM [J]. Membros nunca compartilham nó; número ímpar de nós [2F].
- **Contagem de entregas (AMQP 0.9.1) em quorum:** `basic.reject` incrementa `delivery-count`; `basic.nack` incrementa só `acquired-count`; perda de conexão incrementa ambos; "Unlimited explicit returns (via nack ...) are allowed without counting toward the delivery limit" [J]. Consequência: `nack(requeue=true)` em loop não é contido pelo delivery-limit.
- **Dead-letter at-least-once em quorum** exige `dead-letter-strategy=at-least-once`, `overflow=reject-publish` (não `drop-head`) e a feature flag `stream_queue` [J]. Dead-letter de fila clássica é at-most-once [1F].
- **Streams:** sem DLX, sem TTL por mensagem, sem prioridade, sem QoS global, sempre duráveis; Single Active Consumer e super streams desde 3.11 [J].
- **Filas e mensagens:** "A single queue is generally considered to be an anti-pattern"; FIFO é quebrado por prioridade e por múltiplos consumidores ativos com redelivery; fila durável recupera só mensagens persistentes, transientes são descartadas na recuperação mesmo em fila durável [J].

### 6.3 RabbitMQ — boas práticas

- **RMQ-BP-01** Quorum queue como padrão para dado de negócio (pagamento, transação, bilhetagem); clássica só para efêmero, exclusiva e reply-to [2F + J].
- **RMQ-BP-02** Publisher confirms sempre, assíncronos ou em lote (confirm individual síncrono limita a centenas de msg/s); não republicar no callback de confirm [1F]. Confirm de mensagem não roteável chega assim que o broker vê que ela não vai a fila nenhuma: usar `mandatory` ou alternate exchange [1F].
- **RMQ-BP-03** Ack manual depois do efeito persistido; auto-ack é inseguro [2F].
- **RMQ-BP-04** Prefetch explícito: 100–300 costuma otimizar throughput de mensagem rápida; 1–10 para processamento lento; 0 é ilimitado [1F + Interp.].
- **RMQ-BP-05** Mensagem persistente (`delivery_mode=2`) em fila durável; quorum persiste sempre [J].
- **RMQ-BP-06** Poucas conexões longas; um canal por thread; conexões separadas para publish e consume [2F].
- **RMQ-BP-07** `basic.consume`, nunca polling com `basic.get` [2F].
- **RMQ-BP-08** Toda fila com `max-length`/`max-length-bytes` e `overflow` explícito por policy [1F].
- **RMQ-BP-09** Configuração por policy, não por `x-arguments` no código (exceto `x-queue-type`) [1F].
- **RMQ-BP-10** DLX em toda fila de trabalho, at-least-once nas quorum (requisitos em 6.2) [J].
- **RMQ-BP-11** Poison message: manter `delivery-limit` e DLX para parking lot monitorado; erro permanente com `reject` ou `nack(requeue=false)` [J].
- **RMQ-BP-12** Retry fora da fila principal: em ≥ 4.3, retry atrasado nativo; antes, filas de espera por patamar (`retry.5s`, `retry.30s`, `retry.5m`) com TTL de fila e DLX de volta, contando `x-death` — uma fila por patamar porque TTL por mensagem só expira na cabeça [1F]; nunca o plugin de delayed exchange [J]. Jitter no cliente para retry de chamada remota [1F: AWS].
- **RMQ-BP-13** Ordem só onde for requisito: Single Active Consumer, stream com SAC, ou particionar por chave (consistent hash exchange ou super stream) [1F + J].
- **RMQ-BP-14** Consumidor idempotente; `redeliver=true` é pista, não prova [2F].
- **RMQ-BP-15** Cluster de 3, 5 ou 7 nós; TLS; usuário por aplicação; vhost por ambiente/tenant; `guest` removido; alarmes de memória e disco monitorados [1F].
- **RMQ-BP-16** Topologia como código (`definitions.json`, Terraform, operador) e exchanges duráveis [1F + prática].
- **RMQ-BP-17** Antes de upgrade: `rabbitmq-diagnostics check_if_any_deprecated_features_are_used` e `GET /api/deprecated-features/used` (detecta espelhamento clássico, não detecta QoS global) [1F]. Para 4.3, confirmar que o cluster já roda em Khepri antes de atualizar, porque o Mnesia deixou de existir [J para a remoção; procedimento exato de migração: ver seção 8].

**Receita de referência** (síntese sobre as fontes acima): exchange `dominio.eventos` (topic, durável) → fila `servico.trabalho` (quorum; SAC se exigir ordem) com policy `max-length`, `overflow=reject-publish`, `dead-letter-exchange=servico.dlx`, `dead-letter-strategy=at-least-once`, `delivery-limit=N` e, em 4.3+, `delayed-retry-type=failed`, `delayed-retry-min=1000`, `delayed-retry-max=60000`; `servico.dlx` → `servico.parking` (quorum, com limite e alerta de profundidade > 0). Publisher com confirms assíncronos; consumidor com ack manual, prefetch explícito, inbox transacional e `reject`/`nack(requeue=false)` para erro permanente.

### 6.4 RabbitMQ — antipatterns com detecção

Os greps de API de cliente são heurísticos por linguagem; validar em caso real antes de virar gate. Defaults conferidos pelo juiz: amqplib `nack` e `reject` têm `requeue` default `true` e `noAck` default `false` [J]; Spring AMQP `defaultRequeueRejected` default `true`, contornável com `AmqpRejectAndDontRequeueException` [J].

| # | Antipattern | Detecção | Evidência |
| --- | --- | --- | --- |
| RMQ-AP-01 | Auto-ack | `basicConsume\([^,]+,\s*true` (Java/Kotlin); `auto_ack\s*=\s*True` (pika); `noAck:\s*true` (amqplib); `BasicConsume\([^)]*autoAck:\s*true` (.NET); `acknowledge-mode:\s*none\|AcknowledgeMode\.NONE` (Spring); runtime `rabbitmqctl list_consumers queue_name ack_required` com `false` | 2F / J (amqplib) |
| RMQ-AP-02 | Fila sem limite | `curl .../api/queues \| jq` filtrando `effective_policy_definition` e `arguments` sem `max-length*` | 1F |
| RMQ-AP-03 | Conexão/canal por mensagem | `newConnection\(\|pika\.BlockingConnection\(\|amqp\.connect\(\|amqp\.Dial\(\|CreateConnection(Async)?\(` fora de inicialização | 2F |
| RMQ-AP-04 | Polling com `basic.get` | `basicGet\(\|basic_get\(\|\bch\.Get\(\|BasicGet(Async)?\(` | 2F |
| RMQ-AP-05 | Fila como banco (fila longa) | `rabbitmqctl list_queues name messages \| awk '$2 > 100000'` (limiar ao SLO) | J (5M+) |
| RMQ-AP-06 | Filas espelhadas clássicas | `rabbitmqctl list_policies \| grep -E 'ha-mode\|ha-params\|ha-sync-mode'`; `check_if_any_deprecated_features_are_used` | 2F |
| RMQ-AP-07 | Lazy queue esperando efeito | `grep -rnE 'x-queue-mode\|queue-mode'` | J |
| RMQ-AP-08 | Publish sem confirms | arquivos que publicam sem `confirmSelect\|confirm_delivery\|createConfirmChannel\|\.Confirm\(\|ConfirmSelect\|publisher-confirm-type` | 1F / Heurística |
| RMQ-AP-09 | Confirm síncrono por mensagem | `waitForConfirms` dentro de laço | 1F |
| RMQ-AP-10 | Requeue infinito | `basicNack\([^,]+,\s*(true\|false),\s*true\)`, `basic_nack\([^)]*requeue\s*=\s*True`, amqplib `\.nack\(\s*\w+\s*\)` (requeue default true), Go `\.Nack\(\s*(true\|false)\s*,\s*true\s*\)`, Spring `default-requeue-rejected` ausente ou `true`; runtime: taxa de redeliver | J |
| RMQ-AP-11 | Sem DLX ou DLX sem consumidor/alerta | filas de trabalho sem `dead-letter-exchange`; `*.dlq`/`*.parking` com `messages > 0` e `consumers = 0` sem alerta | 1F |
| RMQ-AP-12 | Mensagem transiente em fila durável | publishers sem `delivery_mode=2`/`PERSISTENT_*`/`persistent: true`/`amqp.Persistent` | J |
| RMQ-AP-13 | Canal compartilhado entre threads | revisão de código (sem grep confiável) | 2F |
| RMQ-AP-14 | `x-arguments` fixos no código | `grep -rnE 'x-dead-letter-exchange\|x-message-ttl\|x-max-length\|x-delivery-limit\|x-overflow'` | 1F |
| RMQ-AP-15 | Fila transiente não exclusiva / temporária com nome fixo | `queueDeclare\([^,]+,\s*false,\s*false` e `durable\s*[:=]\s*(false\|False)` | J (4.3 nega por padrão) |
| RMQ-AP-16 | Fila única para tudo | inventário de filas × tipos de mensagem/SLO | J |
| RMQ-AP-17 | Plugin delayed exchange | `grep -rnE 'x-delayed-message\|x-delayed-type\|rabbitmq_delayed_message_exchange'`; `rabbitmq-plugins list -e \| grep delayed` | J |
| RMQ-AP-18 | QoS global | `basicQos\([^)]*,\s*true\)\|basic_qos\([^)]*global_qos\s*=\s*True` | J (streams não suportam; depreciado) |
| RMQ-AP-19 | Upgrade para 4.3 ainda em Mnesia / config de partition handling | presença de `cluster_partition_handling` com `pause_minority`/`autoheal` no `rabbitmq.conf` | J (remoção) / Heurística detector |

### 6.5 Kafka — boas práticas e antipatterns

- **KFK-BP-01** Chave de partição = identidade do agregado; ordem só dentro da partição [2F].
- **KFK-BP-02** Sobreparticionar para 1–2 anos: aumentar partições de tópico com chave quebra o mapeamento chave→partição [1F: artigo de 2015; custos por partição da era ZooKeeper a revalidar em KRaft].
- **KFK-BP-03** Desde o 3.0 (KIP-679) os defaults são `enable.idempotence=true` e `acks=all` [J]. Validação no código atual do produtor: com idempotência implícita, `acks` ≠ `all` ou `retries=0` a desligam **silenciosamente** (log em nível info); com idempotência pedida explicitamente, lançam `ConfigException`; `max.in.flight.requests.per.connection > 5` com idempotência ligada lança `ConfigException` [J: ProducerConfig.java trunk].
- **KFK-BP-04** RF=3, `min.insync.replicas=2`, `unclean.leader.election.enable=false`; com só uma réplica no ISR, `acks=all` ainda aceita, e `min.insync.replicas` é o que faz recusar [1F; valores 3/2 são prática consagrada].
- **KFK-BP-05** `enable.auto.commit` é `true` por padrão no consumidor [J: ConsumerConfig.java]; desligar e commitar depois de persistir [1F].
- **KFK-BP-06** Exactly-once transacional vale dentro do Kafka (read-process-write com `isolation.level=read_committed`; o default `read_uncommitted` enxerga transação abortada) [2F]; efeito externo exige consumidor idempotente ou offset gravado na transação do banco. Ver seção 8 sobre KIP-939.
- **KFK-BP-07** `retention.ms` é SLA de leitura; `retention.bytes` é por partição [1F].
- **KFK-BP-08** Compaction para tópico de estado; tombstone retido por `delete.retention.ms` (24 h default) [1F].
- **KFK-BP-09** `max.poll.interval.ms` detecta livelock [1F].

| # | Antipattern | Detecção | Evidência |
| --- | --- | --- | --- |
| KFK-AP-01 | Auto-commit com efeito colateral | `grep -rnE 'enable\.auto\.commit\s*[=:]\s*"?true'` **e ausência da chave** (default `true`) | J |
| KFK-AP-02 | `acks=0\|1` ou idempotência desligada | `grep -rnE 'acks\s*[=:]\s*"?(0\|1)"?\b\|enable\.idempotence\s*[=:]\s*"?false'`; `retries\s*[=:]\s*0` também desliga silenciosamente | J |
| KFK-AP-03 | Produtor sem chave com ordem por entidade | `new ProducerRecord<...>(topic, value)` de dois argumentos | 1F |
| KFK-AP-04 | Aumentar partições de tópico com chave | auditoria de `kafka-topics.sh --alter --partitions` | 1F |
| KFK-AP-05 | Consumidor `read_uncommitted` em tópico transacional | `transactional.id` no produtor sem `isolation.level=read_committed` no consumidor | 2F |
| KFK-AP-06 | Durabilidade fraca | `replication_factor\s*=\s*1\|min.insync.replicas.*1\|unclean.leader.election.enable.*true` em IaC | 1F |
| KFK-AP-07 | Compaction em tópico sem chave ou de eventos | `cleanup.policy=compact` com produtor sem chave | 1F |
| KFK-AP-08 | EOS tratado como fim a fim | `processing.guarantee=exactly_once_v2` com chamada HTTP/DB no processador | 1F |

### 6.6 Padrões de integração

**Inbox / consumidor idempotente.** `event_id` único e estável definido na origem [2F]; registrar `(subscriber_id, message_id)` com PK composta na mesma transação do efeito [1F: microservices.io]; ack só depois do commit; alternativa sem tabela: operação idempotente por semântica (upsert, "set status = X") [1F: EIP]; retenção da inbox ≥ janela máxima de redelivery [Interp.]. Antipatterns: dedupe em memória (perde no restart, não funciona com réplicas) e `redelivered` como dedupe [Interp.; detector heurístico `processedIds|seenMessages` e `isRedeliver|redelivered` como condição de skip].

**Outbox transacional.** Dual write sem transação distribuída deixa estado inconsistente [2F]; gravar a mensagem na tabela outbox na mesma transação e publicar por relay, de modo que a mensagem saia se e somente se a transação commitar [1F]. Relay por polling ou por log tailing (CDC); CDC tem overhead menor [1F]. Debezium Outbox Event Router: colunas `id`, `aggregatetype`, `aggregateid` (vira a chave → ordem por agregado), `type`, `payload`; a tabela só recebe INSERT e pode-se inserir e apagar na mesma transação porque o conector lê o log [2F]. Relay com publisher confirms quando o destino é RabbitMQ. Antipatterns: dual write no mesmo handler (commit + publish sem outbox; detector por regra Semgrep a escrever), publicar antes do commit, outbox sem expurgo.

**CDC (Debezium).** At-least-once, retomada pelo LSN; slot de replicação retém WAL com conector parado; usar heartbeat em banco de baixo tráfego [1F]. Detector de WAL retido: `SELECT slot_name, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) FROM pg_replication_slots;` [Heurística, consulta padrão]. Não expor tabela interna via CDC como contrato público; publicar eventos de domínio via outbox [Interp. alinhada à motivação do outbox no blog Debezium].

**Saga.** Sequência de transações locais com compensação; coreografia ou orquestração; sem isolamento, exige outbox em cada passo [1F: microservices.io]. Compensação idempotente, estado persistido, timeout explícito por passo [Interp.].

**Schema de evento.** Modos do Schema Registry: BACKWARD (default), FORWARD, FULL, variantes TRANSITIVE e NONE; BACKWARD atualiza consumidores antes, FORWARD produtores antes; para Protobuf recomenda-se BACKWARD_TRANSITIVE [1F: Confluent]. Protobuf: nunca reutilizar tag, reservar números e nomes removidos, não mudar tipo, sem `required`, primeiro valor de enum = 0 [1F: protobuf.dev]. O produtor é dono do schema do evento, com o mesmo rigor do `.proto` do gRPC interno. Detecção: grep de regressão Protobuf (`git diff main -- '*.proto' | grep -E '^-\s+\w.*=\s*[0-9]+;'`, `grep -rnE '^\s*required\s' --include=*.proto`), modo `NONE` em subject de produção (`curl $SR/config/<subject>`).

**Event sourcing.** Estado como sequência de eventos; replay com sistemas externos e evolução de schema são os problemas [1F: Fowler]. Usar em domínio com auditoria e reconstrução temporal forte (ledger, conciliação); fila RabbitMQ nunca é event store [Interp.].

### 6.7 Escolha de transporte (conforme a regra do dono)

| Necessidade | Interno | Externo (parceiro, adquirente, integrador) |
| --- | --- | --- |
| Consulta/comando síncrono | gRPC | REST (idempotency key em POST com efeito) |
| Comando assíncrono, trabalho único | Fila RabbitMQ (quorum) | Fila em vhost/usuário dedicado ao parceiro, ou REST + webhook |
| Evento de domínio, poucos assinantes | Exchange topic | Fila por parceiro atrás de exchange; nunca acesso à topologia interna |
| Muitos leitores, replay, retenção | RabbitMQ Stream ou Kafka | Adaptador que publica em fila/tópico dedicado do parceiro |
| Streaming bidirecional contínuo | gRPC streaming | Não expor; REST paginado, webhook ou fila |

Antipatterns: **D-AP-01** gRPC exposto a terceiro (Ingress/Gateway/LoadBalancer apontando porta gRPC: `grep -rnE 'grpc' ingress*.yaml gateway*.yaml`); **D-AP-02** fila interna compartilhada com parceiro (`rabbitmqctl list_permissions -p <vhost_interna>` com usuário externo); **D-AP-03** cadeia REST síncrona para fluxo que tolera assincronia (revisão de arquitetura) [Interp.].

### 6.8 Fontes

[RabbitMQ quorum queues](https://www.rabbitmq.com/docs/quorum-queues) · [confirms](https://www.rabbitmq.com/docs/confirms) · [production checklist](https://www.rabbitmq.com/docs/production-checklist) · [streams](https://www.rabbitmq.com/docs/streams) · [lazy queues](https://www.rabbitmq.com/docs/lazy-queues) · [DLX](https://www.rabbitmq.com/docs/dlx) · [exchanges](https://www.rabbitmq.com/docs/exchanges) · [queues](https://www.rabbitmq.com/docs/queues) · [channels](https://www.rabbitmq.com/docs/channels) · [consumers](https://www.rabbitmq.com/docs/consumers) · [TTL](https://www.rabbitmq.com/docs/ttl) · [deprecated features](https://www.rabbitmq.com/docs/deprecated-features) · [Quorum queues in 4.0](https://www.rabbitmq.com/blog/2024/08/28/quorum-queues-in-4.0) · [RabbitMQ 4.3 highlights](https://www.rabbitmq.com/blog/2026/04/23/rabbitmq-4.3-release) · [delayed-message-exchange (arquivado)](https://github.com/rabbitmq/rabbitmq-delayed-message-exchange) · [amqplib channel API](https://amqp-node.github.io/amqplib/channel_api.html) · [Spring AMQP exception handling](https://docs.spring.io/spring-amqp/reference/amqp/exception-handling.html) · [CloudAMQP best practice](https://www.cloudamqp.com/blog/part1-rabbitmq-best-practice.html) · [Kafka design.md](https://github.com/apache/kafka/blob/trunk/docs/design/design.md) · [ProducerConfig.java](https://github.com/apache/kafka/blob/trunk/clients/src/main/java/org/apache/kafka/clients/producer/ProducerConfig.java) · [ConsumerConfig.java](https://github.com/apache/kafka/blob/trunk/clients/src/main/java/org/apache/kafka/clients/consumer/ConsumerConfig.java) · [KIP-679](https://cwiki.apache.org/confluence/display/KAFKA/KIP-679%3A+Producer+will+enable+the+strongest+delivery+guarantee+by+default) · [Kafka 4.2.0](https://kafka.apache.org/blog/2026/02/17/apache-kafka-4.2.0-release-announcement/) · [Confluent EOS](https://www.confluent.io/blog/exactly-once-semantics-are-possible-heres-how-apache-kafka-does-it/) · [Confluent partitions (2015)](https://www.confluent.io/blog/how-choose-number-topics-partitions-kafka-cluster/) · [Transactional Outbox](https://microservices.io/patterns/data/transactional-outbox.html) · [Idempotent Consumer](https://microservices.io/patterns/communication-style/idempotent-consumer.html) · [Saga](https://microservices.io/patterns/data/saga.html) · [Debezium Outbox Event Router](https://debezium.io/documentation/reference/stable/transformations/outbox-event-router.html) · [Debezium outbox blog](https://debezium.io/blog/2019/02/19/reliable-microservices-data-exchange-with-the-outbox-pattern/) · [Debezium PostgreSQL](https://debezium.io/documentation/reference/stable/connectors/postgresql.html) · [Fowler, Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html) · [EIP Idempotent Receiver](https://www.enterpriseintegrationpatterns.com/patterns/messaging/IdempotentReceiver.html) · [Confluent schema evolution](https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html) · [Protobuf dos and don'ts](https://protobuf.dev/programming-guides/dos-donts/) · [gRPC-Web](https://grpc.io/blog/state-of-grpc-web/) · [AWS backoff e jitter](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)

---

## 7. Pontos cegos das pesquisas, preenchidos pelo juiz (transversais)

Esta seção cobre o que nenhuma frente tratou de forma completa. Onde não há fonte primária conferida, a marca é [Interp.] e a regra deve ser validada com o QSA/DPO antes de virar gate.

### 7.1 PCI DSS: dado sensível em cache, bucket, fila, tópico e log

Fatos normativos (PCI DSS v4.0.1): SAD não é armazenado após a autorização, nem cifrado (3.3.1), e a autorização se completa quando o comerciante recebe a resposta; a guidance permite SAD em memória **não persistente** por curto tempo com controles, e "It is not permissible to store SAD in persistent memory"; se o armazenamento de dado de conta se torna persistente, todos os requisitos se aplicam, inclusive cifrar o armazenado; PAN ilegível onde quer que esteja armazenado (3.5.1) [J: texto via fontes secundárias concordantes; 1F da pesquisa no PDF normativo]. Emissores têm tratamento próprio (3.3.3).

Extensão do juiz (a pesquisa só cobriu cache e bronze): fila quorum e stream RabbitMQ gravam em disco; tópico Kafka retém por `retention.ms`; DLQ/parking lot guarda a mensagem que falhou justamente por mais tempo; o `SLOWLOG` do Redis e o APM registram argumentos. Todos são armazenamento persistente [Interp.]. Regras:

- **T-01 PAN/SAD em cache.** Nunca PAN em claro nem SAD em cache distribuído; cachear o token e metadados não sensíveis (BIN, últimos 4, marca). Detecção: `grep -rniE '(set|setex|hset|put|cache)\w*\(.*(pan|card_?num|cardnumber|cvv|cvc|cvv2|track[12]?|pin_?block|expiry)'`; varredura DLP de dump RDB offline com regex de PAN + Luhn [Heurística].
- **T-02 PAN/SAD em payload de fila, tópico, DLQ ou evento de outbox.** Evento carrega token, nunca PAN/SAD; se o fluxo exige PAN (ex.: roteamento ao adquirente), a mensagem é cifrada no nível de aplicação e o broker, seus discos, backups e DLQs entram no inventário de CHD. Detecção: grep dos mesmos nomes de campo em classes/schemas de evento (`.proto`, `.avsc`, JSON Schema) e em DTOs publicados; amostragem DLP de mensagens da DLQ/parking lot [Interp.].
- **T-03 Bucket bronze com CHD.** Bronze que recebe CHD está no CDE e precisa de 3.5.1; tokenizar/mascarar na saída do bronze [Interp.].
- **T-04 Log/métrica com chave ou payload sensível.** Chave de cache com PAN contamina slowlog, `MONITOR`, APM; payload logado no consumidor contamina o SIEM [Interp.].
- **T-05 Infra do CDE sem TLS/auth/criptografia em repouso** (Redis, broker, bucket): Checkov para cache e bucket; para RabbitMQ, listeners sem TLS e usuário `guest` presente (`rabbitmqctl list_users`) [1F + Heurística].

### 7.2 LGPD e o conflito com imutabilidade

Nenhuma das três pesquisas tratou LGPD além de uma menção a expurgo no soft delete. O ponto crítico é o conflito entre práticas que a própria base recomenda (bronze imutável, Object Lock compliance, versionamento, event sourcing, tópico compactado ou com retenção longa, backups) e o direito do titular à eliminação de dados tratados com consentimento, ressalvadas as hipóteses legais de conservação, como cumprimento de obrigação legal ou regulatória [Lei 13.709/2018, arts. 16 e 18 — conhecimento do juiz, não reaberto nesta rodada: https://www.planalto.gov.br/ccivil_03/_ato2007-2010/2008/lei/l13709.htm]. Recomendações [Interp.]:

1. Classificar dado pessoal por base legal e prazo de retenção antes de escolher armazenamento imutável; WORM compliance só para o que tem obrigação legal de retenção, nunca para dado pessoal genérico.
2. Separar identificador pessoal do fato (pseudonimização): bronze, eventos e fatos guardam chave substituta ou token; o mapa chave→pessoa fica num armazenamento mutável e eliminável.
3. Crypto-shredding: cifrar dado pessoal com chave por titular e destruir a chave para eliminar, quando o meio é imutável (log de eventos, backup, bucket travado).
4. Kafka: tombstone em tópico compactado apaga a chave, mas só depois da compactação e de `delete.retention.ms`; em tópico por tempo, o dado vive até a retenção expirar — o prazo precisa caber na política de eliminação.
5. Soft delete generalizado (R-07) não atende eliminação; expurgo físico ou anonimização.
6. Detecção mínima: inventário de colunas/campos com nomes pessoais (`cpf|rg|email|telefone|nome|endereco|data_nasc`) em DDL, schemas de evento e modelos dbt, cruzado com a existência de política de retenção/expurgo por dataset [Heurística].

### 7.3 Multi-tenant

Só a frente de streaming mencionou isolamento (vhost por tenant); faltou o resto [Interp. salvo indicação]:

- **relacional:** escolher entre banco por tenant, schema por tenant ou linha com `tenant_id`; com linha compartilhada, Row-Level Security do PostgreSQL e `tenant_id` como primeira coluna das PKs/índices compostos; atenção à interação de RLS/`SET` com PgBouncer transaction (R-12). Detecção: tabelas de negócio sem coluna `tenant_id` ou sem política RLS (`pg_policies`).
- **nosql:** tenant como prefixo da partition key (`TENANT#t1`) [1F: exemplo AWS] ou primeiro nível da chave hierárquica no Cosmos DB [J]; coleção por tenant é antipattern (N-03); tenant grande vira partição quente — medir por tenant.
- **cache:** namespace por tenant na chave e ACL por padrão de chave; nunca chave sem tenant em cache compartilhado.
- **object-storage:** prefixo por tenant com política IAM condicionada ao prefixo, ou bucket por tenant quando a regulação exige chave de criptografia por cliente.
- **streaming:** vhost por tenant/parceiro com usuário próprio [1F]; no Kafka, ACL por prefixo de tópico e quota por cliente.
- **analitico:** coluna de tenant em toda fato e dimensão conformada; RLS no warehouse para consumo compartilhado.

### 7.4 Custo

Unidades que dominam a fatura e o antipattern que as explode: RU/s no Cosmos DB (consulta cross-partition, consistência forte dobra leitura) [J]; RCU/WCU no DynamoDB (Scan, GSI `ALL`, transação que consome 2 unidades) [1F]; créditos no Snowflake (reclustering) [1F]; requisições de transição e duração mínima no S3 (objeto pequeno, transição precoce) [J]; versões não correntes e multipart órfão [2F]; chamadas KMS sem Bucket Key [1F]; RAM por mensagem e WAL em quorum queue [J]. A skill deve pedir a estimativa de custo da unidade dominante quando recomendar mudança de modelo.

### 7.5 Migração entre tecnologias

Migrações que a base implica e que precisam de caminho explícito: filas espelhadas → quorum (blue-green com `rabbitmqadmin` v2 a partir de 3.13) [1F]; Mnesia → Khepri antes do 4.3 [J remoção]; delayed exchange → retry nativo ou filas de espera [J]; troca de partition key no Cosmos DB (container copy) [J]; aumento de partições no Kafka (tópico novo + replay) [1F]; MinIO comunitário arquivado → alternativa mantida [J]; `invalidate_hard_deletes` → `hard_deletes` no dbt [J]; OFFSET → keyset; `serial` → identity. Toda migração segue expand/contract e mantém leitura dupla até o corte.

---

## 8. Refutado ou incerto

### 8.1 Refutado (não entra na base; corrigido acima quando havia versão correta)

1. **"`max.in.flight.requests.per.connection` > 5 desativa a idempotência"** (pesquisa streaming, KFK-AP-02, [NV]). Refutado: no código atual do produtor, com idempotência ligada (default ou explícita) o valor > 5 lança `ConfigException`; o que desliga silenciosamente é `acks` ≠ `all` ou `retries=0` com idempotência implícita [J: ProducerConfig.java trunk].
2. **"S3 é last-writer-wins e não oferece lock de objeto para escritores concorrentes" como motivo para não usar S3 com concorrência, e "gravações condicionais [NV]"** (pesquisa objetos). Refutado em parte: S3 tem escrita condicional desde 2024 (`If-None-Match`, `If-Match`) e delete condicional desde 2025, com possibilidade de exigir por política [J]. "Sem lock e sem atomicidade entre chaves" segue verdadeiro; corrigido em 4.1 e O-10.
3. **"Recomenda-se 3–4x o WAL em RAM" para quorum queues** (pesquisa streaming). A documentação diz "at least 3 times the memory of the effective WAL file size limit"; o "4x" não está na fonte. Corrigido para "≥ 3×" [J].
4. **"Particionamento Hive por coluna de filtro ... em silver/gold"** (pesquisa objetos, zona de lake item 5) como regra geral. Contradiz a frente analítica e a documentação Databricks (não particionar < 1 TB; liquid clustering recomendado para tabelas gerenciadas) e a Iceberg (particionamento oculto). Rebaixado a "layout de arquivos brutos"; em tabela prevalece 5.4 [J].
5. **"Começar com um único armazenamento" apresentado como a recomendação da Microsoft** (pesquisa taxonomia) sem a contraparte. A mesma página afirma que a maioria dos sistemas de produção adota persistência poliglota; a recomendação real é evitar fragmentação **prematura**. Reescrito em 0.1 [J].
6. **"90% dos dados corporativos são não estruturados"** — já marcado pela pesquisa como marketing sem metodologia; o juiz mantém fora da base.

### 8.2 Incerto (fica fora das regras duras até nova verificação)

1. **KIP-939 (2PC entre Kafka e banco).** `transaction.two.phase.commit.enable` já existe no código do produtor e a KIP promete exactly-once entre Kafka e banco, mas depende de `transaction.version` 3, que não é a versão de produção corrente; tratar KFK-BP-06 ("EOS só dentro do Kafka") como válido para produção hoje e reavaliar a cada release [J parcial: ProducerConfig.java + KIP-939; status de GA não confirmado].
2. **Benefício de localidade de índice do UUIDv7.** Raciocínio de B-tree sólido, mas a documentação do PostgreSQL não o afirma [J: doc silente].
3. **Percentual de jitter de TTL (±10–20%)** — só fontes secundárias.
4. **Valores RF=3 / `min.insync.replicas=2`** — prática consagrada sem segunda fonte aberta.
5. **Semântica do exchange `headers` (`x-match`) e da flag `mandatory`/`basic.return`** — não detalhadas nas páginas lidas.
6. **Nomes de métricas Prometheus do RabbitMQ** (`rabbitmq_connections_opened_total` etc.) — não conferidos.
7. **Comando `buf breaking --against '.git#branch=main'`** e endpoint de compatibilidade do Schema Registry — sintaxe não conferida.
8. **Assinaturas de API de cliente nos greps** (Java, pika, Go, .NET) — conhecimento prévio; amqplib e Spring foram confirmados pelo juiz, os demais não.
9. **LSI do DynamoDB só criável junto com a tabela; duração mínima de 30 dias em Standard-IA/One Zone-IA; campo `sequencer` de eventos S3** — não reabertos.
10. **`MERGE` sem constraint duplicando nós no Neo4j e limite de profundidade de travessia como regra oficial** — sem doc de referência.
11. **Custo quantitativo de LWT/Paxos no Cassandra** — não documentado nas fontes.
12. **Heurística "IN com 2 a 5 partições" no Cassandra** — fonte secundária (Medium).
13. **Sintaxe de detectores analíticos** (`INFORMATION_SCHEMA.PARTITIONS` do BigQuery, `DESCRIBE DETAIL`, tabela `files` do Iceberg, `SYSTEM$CLUSTERING_INFORMATION`, `dbt_utils.unique_combination_of_columns`, comportamento de `state:modified` com contratos) — de conhecimento geral, não conferidos.
14. **`sys.dm_tran_active_transactions`, `innodb_print_all_deadlocks`, efeito de `NOLOCK` via `sys.databases`** — não conferidos.
15. **"Renomear comando está deprecado" no Redis** — a pesquisa afirma; o juiz não reconferiu.
16. **Tese "lakehouse substitui warehouse"** — opinião de fornecedor (autores Databricks).
17. **Procedimento exato de migração Mnesia → Khepri antes do 4.3** — a remoção é fato [J]; o passo a passo (feature flag, janela, rollback) não foi lido.
18. **Artigos de apoio datados:** CloudAMQP sobre quorum queues (antigo, com afirmações desatualizadas) e Confluent sobre partições (2015) — usados só para motivação histórica.
19. **Interpretação PCI sobre Redis persistente, fila, DLQ e tópico como armazenamento de CHD** — tecnicamente consistente com o texto normativo, mas é interpretação; validar com o QSA.
20. **Artigos da LGPD citados em 7.2** — conhecimento do juiz, não reabertos nesta rodada; validar com o DPO/jurídico.

### 8.3 Contradições entre frentes e como foram resolvidas

1. Particionamento Hive (objetos) × particionamento oculto/liquid clustering (analítico): resolvida por camada — arquivo bruto × tabela (0.3 item 4; 8.1 item 4).
2. Medallion descrito nas duas frentes: dono duplo por preocupação (0.3 item 3).
3. Taxonomia com dez especialistas × skill com seis: busca e vetorial sem especialista (lacuna declarada), séries temporais divididas por padrão de acesso, grafo dentro de nosql (0.3 itens 6 e 7).
4. Redis como fila (implícito em "sessões, locks, filas" no cache) × RabbitMQ como broker da stack: fila é de streaming-eventos; Redis com eviction não guarda estado durável (0.3 item 2).
5. Nenhuma recomendação das três frentes expõe gRPC a terceiro; a única superfície de objeto para terceiro é URL pré-assinada de curta duração, compatível com a regra REST/fila externo.

---

## 9. Registro da amostragem do juiz

Fontes efetivamente abertas ou consultadas pelo juiz nesta rodada (32): RabbitMQ blog 4.3; RabbitMQ quorum queues; RabbitMQ queues; RabbitMQ lazy queues; RabbitMQ streams; amqplib channel API; Spring AMQP (busca, doc de exception handling); Kafka 4.2.0 release announcement; KIP-679; Kafka ProducerConfig.java (trunk); Kafka ConsumerConfig.java (trunk); KIP-939 (busca); PostgreSQL UUID functions; PostgreSQL errcodes appendix; Kleppmann, anúncio DDIA 2e; SQL Server deadlocks guide; PgBouncer features; HikariCP pool sizing; Azure "Understand data models"; S3 lifecycle transitions; anúncios S3 de escrita/delete condicional (busca); MinIO repositório no GitHub; Neo4j blog relationship chain locks; Databricks when to partition; BigQuery partitioned tables; Redis key eviction; MongoDB write concern; Cosmos DB partitioning; DynamoDB partition key design; cassandra.yaml (trunk); dbt snapshots; PCI DSS 3.3.1 (busca em fontes secundárias concordantes).
