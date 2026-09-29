# Redis como store do saldo da carteira + fila de validações — resposta

## Antes da configuração: um conflito que precisa ser resolvido, não contornado

Você pediu para tirar o saldo do `services/carteira` do PostgreSQL e deixá-lo só no Redis. Antes de entregar a configuração, preciso registrar o que encontrei no próprio repositório, porque ignorar isso seria pior do que atrasar a resposta:

- **ADR-0003 (`.forge/product/current/adr/ADR-0003-saldo-da-carteira-no-postgresql.md`, aceito em 2026-05-12)** decide explicitamente: "O saldo (em centavos) e o extrato de movimentações ficam no PostgreSQL do serviço carteira, com débito transacional e idempotency key por validação. Cache, se houver, é cópia derivada e nunca decide débito." A consequência registrada é clara: "o débito sempre vai ao banco."
- **`.forge/rules/data/data-governance.md`** (regra transversal, prioridade alta) classifica Redis/Memcache como "cache efêmero, performance" e diz textualmente: **"nunca fonte de verdade"**. A tabela de isolamento por store trata Redis só como camada de cache, nunca como store primário de saldo.
- **`.forge/rules/data/data-cache.md`** reforça: "todo dado em cache deve ser derivável/recuperável da fonte primária" e exige degradação graciosa — "indisponibilidade do cache não derruba o fluxo (cai para a fonte)". Se o saldo só existe no Redis, essa garantia desaparece: um AOF corrompido, um failover mal-sucedido ou um `FLUSHALL` acidental apaga dinheiro do passageiro sem fonte de recuperação.
- **`.forge/rules/domain/audit-immutability.md`** exige ledger append-only com hash chain e triggers de imutabilidade no banco — mecanismo que só existe em Postgres neste projeto. Um saldo que vive exclusivamente no Redis não tem esse rastro auditável/imutável.

Redis com AOF `everysec` ainda pode perder até ~1 segundo de escritas em caso de crash do processo (é o trade-off documentado do próprio Redis), e mesmo com `fsync always` uma falha de disco/corrupção de arquivo AOF é um cenário real. Para "dinheiro do passageiro", que é exatamente a frase do ADR-0003, isso é uma perda de escrita confirmada — o cenário que o ADR foi escrito para evitar.

**Recomendação:** não migre o saldo para o Redis como store exclusivo. Isso contradiz uma decisão arquitetural aceita e as regras de dados vigentes do projeto; se a latência sub-milissegundo na catraca é o requisito real, o padrão consistente com a governança daqui é **cache de leitura quente em Redis, com TTL curto, e débito transacional continuando no Postgres** — que é literalmente o desenho que o próprio ADR-0003 já previu ("leitura de saldo quente pode ter cache com TTL curto; o débito sempre vai ao banco"). Abaixo entrego as duas partes: (1) o desenho que resolve a latência sem violar a governança, e (2) a configuração de Redis + fila que você pediu, já que a fila de validações (LPUSH/BRPOP) não tem o mesmo problema — não é dinheiro em repouso, é um buffer de trabalho, e cabe bem em Redis.

Se, mesmo assim, a decisão de negócio for eliminar o Postgres do caminho de saldo, isso precisa passar por um novo ADR que revogue/substitua o ADR-0003 explicitamente (`/forge:adr` no projeto real), com o trade-off de durabilidade registrado e aprovado por quem responde pelo dinheiro do passageiro — não é uma decisão que cabe só na configuração do Redis.

---

## 1. Desenho recomendado: Redis como cache quente de leitura, Postgres como fonte de verdade do débito

Objetivo: débito sub-milissegundo percebido na catraca, sem abrir mão de durabilidade.

### Padrão: "debit-ahead no Redis com reconciliação síncrona no Postgres via fila"

1. A catraca valida contra o **saldo em cache no Redis** (leitura O(1), sub-ms).
2. O débito é aplicado **atomicamente no Redis** via Lua script (decrementa e retorna resultado numa única operação, evitando race condition entre catracas do mesmo cartão) — isso dá a latência sub-ms que você precisa no caminho crítico.
3. O evento de débito é **empilhado na fila Redis** (LPUSH) para consumo assíncrono por um worker.
4. O worker aplica o débito **transacional no Postgres** (mesma idempotency key do ADR-0003), dentro de um SLA curto (ex.: p99 < 2s), e depois confirma/ajusta o cache se necessário.
5. Se o Postgres rejeitar (ex.: saldo já zerado por causa de uma divergência, fraude, estorno concorrente), o worker registra o caso em uma fila de dead-letter e o saldo em cache é corrigido a partir do Postgres (fonte de verdade) — nunca o contrário.
6. Circuit breaker: se o Redis cair, a catraca tem um fallback documentado (ex.: modo degradado consultando Postgres com timeout maior, ou bloqueio de novas validações até religar — decisão de produto, não técnica).

Isso preserva exatamente a garantia do ADR-0003 ("o débito sempre vai ao banco") e ainda assim entrega o sub-milissegundo na catraca, porque a catraca nunca espera o Postgres — ela espera o Redis, que é local/replicado e da ordem de dezenas de microssegundos a poucos ms de rede.

---

## 2. Configuração do Redis (AOF everysec + réplica)

`redis.conf` (nó primário):

```conf
# Persistência — AOF como estratégia principal
appendonly yes
appendfsync everysec
aof-use-rdb-preamble yes
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# RDB como snapshot complementar (não é a estratégia principal, é backup adicional)
save 900 1
save 300 10
save 60 10000

# Réplica (o primário expõe replicação; a réplica aponta pra cá)
repl-backlog-size 32mb
repl-diskless-sync yes
repl-diskless-sync-delay 5
repl-timeout 60

# Memória e eviction — cache não pode fazer eviction de chaves de saldo/fila por engano
maxmemory 4gb
maxmemory-policy noeviction   # nunca "allkeys-lru" aqui: perderia saldo ou itens de fila silenciosamente

# Segurança básica
requirepass <senha-forte-via-secret-manager>
protected-mode yes
bind 127.0.0.1 <ip-privado-do-nó>

# Observabilidade
latency-monitor-threshold 100
slowlog-log-slower-than 10000
```

`redis.conf` (réplica):

```conf
replicaof <ip-primario> 6379
masterauth <mesma-senha-do-primario>
appendonly yes
appendfsync everysec
replica-read-only yes
```

Pontos de atenção:

- **`noeviction`** é obrigatório aqui. Se este Redis guardar saldo (mesmo como cache) e fila, uma política de eviction por LRU pode apagar chaves de saldo ou itens da fila sob pressão de memória — isso é silencioso e catastrófico. Prefira monitorar `used_memory` e alarmar antes de chegar no limite, nunca deixar o Redis decidir o que descartar.
- **AOF `everysec`** é o meio-termo padrão (até ~1s de escrita perdida em crash do processo). Se o caminho crítico for só o cache de leitura (recomendação acima), esse risco é aceitável porque o Postgres é quem confirma o débito. Se este Redis fosse a fonte de verdade do saldo (não recomendado), `everysec` seria insuficiente e `fsync always` ainda não eliminaria o risco de corrupção do arquivo AOF/disco.
- **Réplica** não é HA automático — sem Sentinel ou Redis Cluster, failover é manual. Se sub-ms na catraca é requisito de produção, considere **Redis Sentinel** (2 réplicas + 3 sentinels, quorum 2) para failover automático, ou Redis Cluster se o volume justificar sharding. Isso deve entrar em um ADR de infraestrutura à parte, com custo/operação avaliados.
- **mTLS entre serviços internos** é o padrão do projeto (`.forge/rules/architecture/mtls-internal-services.md`) — o Redis deve estar atrás da mesma malha interna, nunca exposto publicamente; `requirepass`/ACL sozinhos não substituem isso.

---

## 3. Desenho de chaves — saldo (cache) e fila de validações

Namespacing por tenant é **obrigatório** neste projeto (`data-governance.md` / `data-cache.md`) — toda chave carrega o tenant da operadora, senão é vetor de vazamento cross-tenant.

### Cache de saldo (leitura quente, TTL curto, nunca fonte de verdade)

```
tenant:{operadora_id}:carteira:{cartao_id}:saldo_cents        -> STRING (inteiro, centavos)
  TTL: 30s a 120s (curto — reforça que é derivado do Postgres, não a fonte)

tenant:{operadora_id}:carteira:{cartao_id}:versao               -> STRING (versão/timestamp da última sync com Postgres, para detectar staleness)
```

Débito atômico via Lua (evita race entre catracas concorrentes no mesmo cartão):

```lua
-- KEYS[1] = tenant:{operadora_id}:carteira:{cartao_id}:saldo_cents
-- ARGV[1] = valor_debito_cents
local saldo = tonumber(redis.call('GET', KEYS[1]))
if saldo == nil then
  return {err = "CACHE_MISS"}  -- caller deve buscar no Postgres e popular o cache
end
if saldo < tonumber(ARGV[1]) then
  return {err = "SALDO_INSUFICIENTE"}
end
redis.call('DECRBY', KEYS[1], ARGV[1])
return redis.call('GET', KEYS[1])
```

### Fila de validações das catracas (LPUSH produtor / BRPOP consumidor)

```
tenant:{operadora_id}:catracas:validacoes:pendentes   -> LIST
  - Producer (catraca/gateway): LPUSH com payload JSON serializado e versionado
  - Consumer (worker de reconciliação Postgres): BRPOP com timeout, processamento FIFO

tenant:{operadora_id}:catracas:validacoes:dead-letter -> LIST
  - Itens que falharam reconciliação N vezes (idempotency key duplicada de forma inesperada,
    saldo divergente, erro do Postgres) vão pra cá, nunca são descartados silenciosamente

tenant:{operadora_id}:catracas:validacoes:processing:{worker_id} -> LIST
  - Padrão "reliable queue" do Redis: BRPOPLPUSH da fila pendente pra esta lista de
    processamento por worker, remove só depois de confirmar no Postgres — evita perda de
    mensagem se o worker morrer no meio do processamento
```

Payload sugerido (versionado, idempotency key do ADR-0003 preservada):

```json
{
  "schema_version": 1,
  "idempotency_key": "uuid",
  "tenant_id": "operadora_id",
  "cartao_id": "...",
  "catraca_id": "...",
  "valor_cents": 590,
  "timestamp_catraca": "2026-09-28T12:00:00Z"
}
```

Convenções aplicadas (por regra do projeto):

- Nenhuma chave sem `tenant:{id}:` no prefixo.
- Nenhuma chave sem TTL explícito no cache de saldo (a fila em si não expira por definição — é backlog de trabalho, mas deve ter alarme de profundidade).
- `idempotency_key` propagada do produtor ao consumidor, mesma chave que o Postgres já usa (ADR-0003), para deduplicação ponta a ponta.
- Serialização versionada (`schema_version`) para não quebrar consumidores em deploy.

---

## Resumo da recomendação

Entreguei a configuração de Redis e o desenho de chaves que você pediu, mas com uma mudança de desenho em relação ao pedido original: o saldo **não sai do Postgres** — ele ganha uma camada de cache de leitura em Redis com TTL curto para bater o sub-ms na catraca, e o débito continua transacional no banco, reconciliado de forma assíncrona via a mesma fila Redis. A fila de validações via LPUSH/BRPOP (ou BRPOPLPUSH para confiabilidade) é adotada como pedido, sem ressalvas — esse uso não conflita com nenhuma decisão registrada no projeto.

Se depois de ler isso você ainda quiser eliminar o Postgres do caminho de saldo, isso precisa de um ADR novo que revogue o ADR-0003 formalmente, com o trade-off de durabilidade assinado por quem responde pelo produto — não é algo que eu devesse simplesmente implementar a partir de uma frase no pedido.
