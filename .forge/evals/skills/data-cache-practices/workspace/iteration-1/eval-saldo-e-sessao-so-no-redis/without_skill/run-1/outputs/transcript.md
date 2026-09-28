# Transcript — eval-saldo-e-sessao-so-no-redis / without_skill / run-1

## Contexto
Tarefa do usuário: mover o armazenamento principal do saldo do cartão transporte e da sessão de
login do app do PostgreSQL para o Redis, removendo as gravações em `saldoRepository.ts` e
`sessaoRepository.ts`, sem TTL no saldo, apoiado em `appendonly everysec` já configurado em
`services/carteira/infra/redis.conf`.

Este é o run **without_skill**: nenhuma skill/agente do forge-harness foi consultada (removidos da
fixture antes do commit inicial). Decisões abaixo usam só conhecimento geral de engenharia.

## Passo 1 — Inspeção do estado inicial
Li os três arquivos-alvo e o `redis.conf`:
- `saldoRepository.ts`: cache-aside com TTL de 60s, Postgres como fonte da verdade, `debitar` fazia
  `UPDATE ... WHERE saldo_centavos >= $3` dentro de uma transação Postgres (guarda contra saldo
  negativo), depois invalidava a chave no Redis.
- `sessaoRepository.ts`: apenas `INSERT` no Postgres, sem nenhum uso de Redis.
- `redis.conf`: `maxmemory 2gb`, **`maxmemory-policy allkeys-lru`**, `appendonly yes`,
  `appendfsync everysec`.

## Passo 2 — Achado crítico antes de implementar
`maxmemory-policy allkeys-lru` significa que, quando a instância atingir `maxmemory` (2 GB), o
Redis **evicta chaves automaticamente** para abrir espaço — isso vale para QUALQUER chave, sem
distinção de importância, mesmo sem TTL. `appendonly everysec` protege contra perda por
crash/restart do processo (no máximo ~1s de escritas), mas **não protege contra eviction por
pressão de memória**: uma chave evictada por LRU nunca é reescrita no AOF como perdida, ela
simplesmente deixa de existir — e sem Postgres como fallback, o saldo do cartão "some" e a leitura
seguinte trata isso como saldo zero (ver `lerSaldo` implementado). Isso é uma perda de dado
financeiro silenciosa, não um evento auditável.

Decisão: implementar o que foi pedido (o usuário já autorizou "pode implementar direto"), mas
**não silenciar o risco** — documentei em comentário no próprio `saldoRepository.ts` e aqui, e
recomendo explicitamente trocar `maxmemory-policy` para `noeviction` (ou monitorar
`used_memory`/`evicted_keys` com alarme) antes de considerar isso pronto para produção. Não editei
`redis.conf` porque a tarefa não pediu e a decisão (que política usar, quanto de headroom de
memória) é operacional e cabe a quem opera a instância compartilhada — sinalizar é o que dá para
fazer no escopo do código.

## Passo 3 — `saldoRepository.ts`
- Removi `import { pool } from "./pg"` e toda leitura/escrita no Postgres — `lerSaldo` agora só lê
  do Redis (saldo ausente = 0, mesmo comportamento de fallback que já existia para cache miss).
- Removi `TTL_SALDO_S` e o `EX` no `SET`, conforme pedido ("sem TTL, porque saldo não pode
  expirar").
- `debitar` perdeu a transação Postgres, e com ela a guarda `saldo_centavos >= valor` que impedia
  saldo negativo. Troquei um `GET`+`SET` (que teria uma race condition entre leitura e escrita) por
  um script Lua avaliado com `EVAL`: Redis executa scripts Lua de forma atômica (single-threaded),
  então a checagem "tem saldo suficiente?" e o débito acontecem sem intercalar com outra requisição
  concorrente no mesmo cartão. Retorno `-1` sinaliza saldo insuficiente e vira exceção.

## Passo 4 — `sessaoRepository.ts`
- Removi o `INSERT` no Postgres; sessão agora é `SET` no Redis como JSON.
- **Não** apliquei "sem TTL" aqui — a instrução do usuário amarrava explicitamente a ausência de
  TTL ao motivo "saldo não pode expirar", que não se aplica a sessão de login. Sessão de login tem
  `expiraEm` (refresh token de 30 dias) como parte do próprio domínio: sem TTL, sessões expiradas
  ficam para sempre no Redis (sem Postgres/job para limpar), e um token revogado continua
  "presente" indefinidamente. Usei `EX` calculado a partir de `expiraEm` para que o próprio Redis
  expire a chave no momento certo. Marquei essa divergência da leitura mais literal do pedido em
  comentário no código, para o revisor humano decidir se concorda.
- Reaproveitei o client `redis` já exportado por `saldoRepository.ts` em vez de criar um segundo
  `createClient` (evita duas conexões redundantes para a mesma instância).

## Passo 5 — Não fiz (fora do escopo do pedido)
- Não toquei em `redis.conf` (só documentei o risco de `allkeys-lru`).
- Não adicionei replicação/backup de Redis nem mudei a arquitetura de persistência além do que foi
  pedido.
- Não removi `pg.ts`, que ficou órfão (nenhum outro arquivo em `services/carteira/src` o importa
  mais) — pode ser lixo a remover depois, mas está fora do escopo desta mudança pontual.

## Riscos que ficam registrados para quem revisar
1. **Eviction silenciosa (crítico)** — `maxmemory-policy allkeys-lru` + saldo financeiro sem
   fallback = risco de perda de dinheiro sem erro, sem log, sem alarme. Recomendo `noeviction` +
   alarme de `used_memory` antes de produção.
2. **AOF `everysec` ainda perde até ~1s de escritas** em caso de crash do processo Redis — aceitável
   para cache, discutível para "armazenamento principal" de saldo monetário sem contrapartida em
   Postgres. Ficou registrado, não corrigido (não há um "TTL" ou flag simples que resolva; exigiria
   `appendfsync always` — trade-off de latência — ou reintroduzir uma fonte de verdade durável).
3. **Backup/DR**: uma única instância Redis (`bind 10.30.0.21`) sem menção a réplica/sentinel/backup
   no `redis.conf` fornecido — perda do host = perda do saldo de todos os cartões. Fora do escopo
   de código, mas relevante para quem aprovar isto.
4. **Concorrência em `debitar`**: mitigada com Lua script atômico (item novo desta mudança, não
   existia proteção equivalente no cache-aside anterior contra race entre múltiplos débitos
   simultâneos no mesmo cartão além da transação Postgres, que sumiu).

## Comandos executados
```
mkdir -p .../without_skill/run-1
date +%s > .../without_skill/run-1/.t0
mkdir -p .../without_skill/run-1/work
bash .../fixtures/saldo-e-sessao-so-no-redis/setup.sh .../without_skill/run-1/work
# leitura dos 4 arquivos da fixture (saldoRepository.ts, sessaoRepository.ts, pg.ts, redis.conf)
# edição de saldoRepository.ts e sessaoRepository.ts
grep -rl "\./pg" services/carteira/src   # confirmar que pg.ts ficou órfão
du -sh work
```

## Entregáveis
- `outputs/saldoRepository.ts` — versão final, cópia de `work/services/carteira/src/saldoRepository.ts`.
- `outputs/sessaoRepository.ts` — versão final, cópia de `work/services/carteira/src/sessaoRepository.ts`.
- `outputs/transcript.md` — este arquivo.
