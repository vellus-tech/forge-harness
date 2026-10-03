# Saldo da carteira digital — avaliação da proposta "só Redis"

## Resposta direta ao pedido

Antes do desenho técnico: **não recomendo saldo de carteira digital vivendo só no Redis**, mesmo
com cluster + réplica + AOF `appendfsync always`. Latência é importante, mas saldo monetário é um
dado que precisa de durabilidade e auditabilidade fortes — e Redis, mesmo endurecido, não entrega
as mesmas garantias que um banco transacional. Abaixo explico o porquê, e desenho as duas opções:
a arquitetura que você pediu (Redis puro) com os riscos explícitos, e a alternativa que eu
recomendaria (Redis como camada de baixa latência na frente de um ledger durável), para você
decidir com os trade-offs completos.

## Por que Redis-only é arriscado para saldo financeiro

1. **AOF `always` não é o mesmo que commit ACID em disco transacional.** `appendfsync always`
   grava a cada comando no arquivo AOF antes de responder ao cliente, o que já custa a latência
   que o Redis existe para evitar (na prática, single-digit ms por escrita vira o padrão, não a
   exceção) — e mesmo assim é durabilidade de *um* nó. Não há WAL com checksum por transação,
   nem isolamento de transação real (Redis não tem rollback de transação — `MULTI/EXEC` não
   desfaz comandos que já rodaram se um falhar no meio).
2. **Failover perde escrita, mesmo com réplica.** Redis usa replicação assíncrona por padrão.
   Se o primário morre antes de propagar a última escrita (que já foi confirmada ao cliente por
   causa do AOF local), a promoção da réplica materializa um saldo desatualizado — a réplica
   "esqueceu" um débito ou crédito que o cliente já viu confirmado. `WAIT` mitiga mas não elimina
   (ainda há janela entre ACK do WAIT e a falha do primário), e usar `WAIT` em todo débito
   reintroduz a latência que motivou a escolha do Redis.
3. **Sem ponto de recuperação point-in-time nem trilha de auditoria nativa.** Regulação de meios
   de pagamento (Bacen, PCI DSS) e a própria conciliação contábil esperam um livro-razão
   imutável, com histórico de lançamentos, não só o número final. Redis guarda o valor atual;
   não é um livro-razão por natureza — sem uma stream de eventos ao lado, reconstruir "como
   chegamos a esse saldo" depois de um incidente é praticamente impossível.
4. **Resharding de cluster é operacionalmente perigoso para dinheiro.** Rebalancear slots com
   carteiras sob escrita concorrente tem histórico de janelas de inconsistência (`ASK`/`MOVED`
   mal tratado no client, migração de chave a meio de uma transação Lua). Um bug de client aqui
   é dinheiro perdido ou duplicado, não uma página lenta.
5. **Superfície de erro humano maior sem um segundo sistema de verificação.** Com Postgres como
   fonte da verdade, um saldo errado no cache é detectável (cache diverge do banco). Sem banco,
   Redis errado *é* o saldo errado — não existe onde comparar.

Nenhum desses pontos é hipotético: são os motivos pelos quais arquiteturas de pagamento que já vi
(Axis/Vellus incluídos, no meu conhecimento geral do domínio) usam Redis como acelerador de
leitura/lock distribuído na frente de um ledger em RDBMS, não como armazenamento único da verdade
monetária.

## Recomendação

Modelo de duas camadas, que ainda entrega a latência que o produto precisa:

- **Fonte da verdade:** Postgres com tabela de lançamentos (`ledger_entries`, append-only,
  double-entry: toda alteração de saldo é uma linha `debito`/`credito` com `conta_id`,
  `valor_centavos`, `idempotency_key`, `criado_em`), e uma view materializada ou coluna
  `saldo_atual` mantida por trigger/transação — não recalculada em cada leitura.
- **Camada de latência:** Redis (cluster + réplica, AOF `everysec` é suficiente aqui porque
  Redis deixa de ser a fonte da verdade) guardando `saldo:{conta_id}` como *read cache* e como
  mecanismo de **lock/débito atômico otimista** — o Lua script abaixo debita no Redis primeiro
  (latência baixa, resposta imediata ao usuário) e enfileira a escrita no Postgres de forma
  assíncrona e idempotente (fila interna, não REST — dentro do próprio domínio de pagamentos)
  para reconciliar. Se a escrita no Postgres falhar, o job de reconciliação corrige o Redis a
  partir do ledger, que é sempre a verdade.
- Isso preserva a resposta rápida ao usuário (decisão de aprovar/negar o débito acontece no
  Redis, em memória) sem tornar o Redis o único lugar onde o dinheiro "existe".

Se, mesmo assim, a decisão de produto for seguir com Redis como única persistência (aceitando os
riscos acima formalmente, com sign-off de quem responde por risco regulatório), o desenho técnico
abaixo é o que eu passaria ao task-coder — com os avisos embutidos como comentários, para que a
decisão fique registrada no código.

## Desenho das chaves (Redis)

```
saldo:{conta_id}                 -> string, inteiro, saldo em centavos (fonte única se Redis-only)
saldo:{conta_id}:lock            -> (não necessário; Lua já é atômico single-thread no Redis)
saldo:{conta_id}:versao          -> inteiro, incrementado a cada escrita (auditoria mínima/otimista)
idemp:{conta_id}:{idempotency_key} -> "1" com TTL curto (24h), para deduplicar retries de débito
audit:{conta_id}                 -> Redis Stream (XADD), um evento por débito/crédito:
                                     {op, valor_centavos, idempotency_key, timestamp, saldo_resultante}
                                     — mitiga parcialmente a falta de livro-razão (ponto 3 acima),
                                     mas ainda vive só no Redis, sujeita aos mesmos riscos de perda.
```

Uso de `Redis.Cluster`: `conta_id` deve ser a chave de hash (`{conta_id}` com hash tag, ex.:
`saldo:{"abc123"}` e `audit:{"abc123"}`) para garantir que saldo + stream de auditoria da mesma
conta caem no mesmo slot — sem isso, o Lua script de débito atômico abaixo falha em cluster
porque toca chaves em slots diferentes.

## Débito atômico com verificação de saldo (Lua)

```lua
-- debitar.lua
-- KEYS[1] = saldo:{conta_id}
-- KEYS[2] = audit:{conta_id}   (stream de auditoria, mesmo slot via hash tag)
-- KEYS[3] = idemp:{conta_id}:{idempotency_key}
-- ARGV[1] = valor_centavos (positivo)
-- ARGV[2] = idempotency_key
-- ARGV[3] = ttl_idempotencia_segundos (ex.: 86400)

if redis.call('EXISTS', KEYS[3]) == 1 then
  -- retry do mesmo request: devolve o saldo atual sem debitar de novo
  local saldo_atual = tonumber(redis.call('GET', KEYS[1]) or '0')
  return {1, saldo_atual, 'idempotent_replay'}
end

local saldo = tonumber(redis.call('GET', KEYS[1]) or '0')
local valor = tonumber(ARGV[1])

if valor <= 0 then
  return {0, saldo, 'valor_invalido'}
end

if saldo < valor then
  return {0, saldo, 'saldo_insuficiente'}
end

local novo_saldo = redis.call('DECRBY', KEYS[1], valor)

redis.call('SETEX', KEYS[3], tonumber(ARGV[3]), '1')

redis.call('XADD', KEYS[2], '*',
  'op', 'debito',
  'valor_centavos', valor,
  'idempotency_key', ARGV[2],
  'saldo_resultante', novo_saldo)

return {1, novo_saldo, 'ok'}
```

Chamada (ioredis, `defineCommand`):

```ts
redis.defineCommand('debitar', {
  numberOfKeys: 3,
  lua: fs.readFileSync('debitar.lua', 'utf8'),
});

// contaId precisa gerar as 3 chaves com a MESMA hash tag {contaId}
const [ok, novoSaldo, motivo] = await redis.debitar(
  `saldo:{${contaId}}`,
  `audit:{${contaId}}`,
  `idemp:{${contaId}}:${idempotencyKey}`,
  valorCentavos,
  idempotencyKey,
  86400,
);

if (ok !== 1) {
  throw new SaldoInsuficienteError(contaId, motivo);
}
```

Por que Lua e não `WATCH/MULTI/EXEC` client-side: o script roda atômico no servidor (bloqueia o
event loop do Redis durante a execução, que é curtíssima), então não há corrida entre
"ler saldo" e "decidir se debita" mesmo sob alta concorrência na mesma conta — o que
`WATCH/MULTI/EXEC` exigiria retry manual para resolver, e retry manual em código de saldo é
fonte comum de bug de double-spend em condição de corrida.

## Configuração de persistência do Redis (a configuração pedida, com ressalva)

```conf
# redis.conf — cluster com réplica, se a decisão for seguir com Redis como storage único

appendonly yes
appendfsync always          # ⚠ maior garantia possível no Redis, mas ainda não é ACID
                             #   de banco transacional (ver riscos 1-2 na análise acima);
                             #   também é o modo de MAIOR custo de latência do Redis — mede o
                             #   impacto real (p99 de escrita) antes de assumir "latência é tudo"
                             #   como premissa não verificada.
aof-use-rdb-preamble yes    # AOF compacto (RDB + comandos incrementais) para recovery mais rápido
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

save ""                     # desliga snapshot RDB periódico (redundante com AOF always;
                             # evita fork() custoso concorrendo com o AOF always)

# Réplica síncrona o quanto der (WAIT no client após escrita crítica, com timeout curto):
#   redis.call('WAIT', 1, 200)  -- espera 1 réplica confirmar, até 200ms
#   Ainda assim: WAIT não é 2PC, não impede perda em cenário de split-brain sem fencing.

repl-diskless-sync no       # replicação via disco (mais lento, mais seguro que diskless
                             # para não perder o RDB inicial de sync em caso de falha do link)
repl-backlog-size 256mb     # backlog maior para resistir a desconexões curtas de réplica
                             # sem exigir full resync (que interrompe a réplica por mais tempo)

maxmemory-policy noeviction # CRÍTICO: qualquer policy de eviction (allkeys-lru etc.) pode
                             # apagar saldo:* sob pressão de memória. Em dado financeiro,
                             # eviction habilitada é bug de perda de dinheiro, não trade-off de
                             # performance. Monitore memória e faça scale-out antes do limite,
                             # nunca dependa de eviction.

cluster-enabled yes
cluster-node-timeout 5000
cluster-require-full-coverage yes   # cluster recusa escrita se um slot estiver sem cobertura,
                                     # em vez de aceitar escrita parcial silenciosa — para saldo,
                                     # prefira indisponibilidade explícita a inconsistência muda

# Sentinel/orquestração de failover (fora deste arquivo): configure fencing para que o primário
# antigo, se voltar após split-brain, nunca aceite escrita antes de sincronizar com o novo
# primário — sem isso, um "saldo fantasma" reaparece.
```

## O que eu passaria ao task-coder

1. Desenho das chaves e Lua acima, com o hash-tag de cluster (`{conta_id}`) — sem isso o Lua
   script quebra em cluster real (erro `CROSSSLOT`).
2. A `redis.conf` acima, com o comentário sobre `maxmemory-policy noeviction` marcado como
   bloqueante de review — é o erro mais comum e mais caro nesse tipo de setup.
3. Um `docs/decisions/saldo-redis-only.md` (ou ADR) registrando explicitamente que a decisão foi
   Redis como fonte única de verdade para saldo, com os riscos 1-5 listados acima e quem
   aprovou — para que isso não vire "descoberta" em auditoria PCI ou em incidente de produção.
4. Recomendação separada (não bloqueante, mas registrada): revisitar a arquitetura de duas
   camadas (Postgres ledger + Redis cache) antes de ir para produção com volume real, mesmo que
   o protótipo atual siga Redis-only para validar o produto rapidamente.
