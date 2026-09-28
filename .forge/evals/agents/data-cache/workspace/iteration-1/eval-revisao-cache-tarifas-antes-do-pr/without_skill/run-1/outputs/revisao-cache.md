# Revisão de uso de cache — services/tarifas (pré-PR)

Escopo revisado: `services/tarifas/src/tarifa/servico.ts`, `services/tarifas/src/linha/servico.ts`, `infra/redis/redis.conf`, `services/tarifas/README.md`. Revisão só de leitura — nenhum arquivo foi alterado; as correções abaixo são para o task-coder aplicar.

## 1. [BLOQUEADOR] Chave de cache de `linha` não isola por tenant — colisão de dado entre operadoras

**Onde:** `services/tarifas/src/linha/servico.ts`, linhas 6 e 9.

```ts
const hit = await redis.get(`linha:${id}`);
...
await redis.set(`linha:${id}`, JSON.stringify(linha), { EX: 3600 });
```

O README do serviço declara explicitamente que o produto é multi-tenant por operadora e que "duas operadoras podem ter uma linha com o mesmo id". A chave de cache usada aqui é só `linha:${id}`, sem o tenant/operadora — ao contrário de `tarifa/servico.ts`, que usa `tenant:${t}:tarifa:${id}` corretamente. Isso significa que a operadora A pode ler do cache uma linha que pertence à operadora B (mesmo `id`, dado de outro tenant), porque as duas escrevem e leem a mesma chave Redis.

**Impacto:** vazamento de dado entre tenants — a operadora A pode ver nome/trajeto/cadastro da linha da operadora B. Em um produto multi-tenant isso é falha de isolamento de dado, não só bug funcional.

**Correção:** incluir o tenant na chave, no mesmo padrão já usado em `tarifa/servico.ts`:

```ts
const chave = `tenant:${t}:linha:${id}`;
const hit = await redis.get(chave);
if (hit) return JSON.parse(hit) as Linha;
const linha = await db.linha.findOne({ operadora: t, id });
await redis.set(chave, JSON.stringify(linha), { EX: 3600 });
return linha;
```

## 2. [ALTO] `chavesDoTenant` usa `KEYS`, comando bloqueante, em serviço de alto throughput

**Onde:** `services/tarifas/src/tarifa/servico.ts`, linha 12 (`redis.keys(...)`).

`KEYS` varre o keyspace inteiro do Redis de forma síncrona (O(N) no total de chaves, não só nas que casam o padrão) e bloqueia o event loop do Redis enquanto roda. O README diz que tarifas são lidas ~10 mil vezes por segundo; qualquer chamada a `chavesDoTenant` nesse volume de tráfego pode travar todas as leituras de todos os tenants por alguns milissegundos a segundos, dependendo do tamanho do keyspace — e esse Redis também guarda as chaves de `linha`, então o impacto não fica isolado a tarifas.

**Correção:** trocar por `SCAN` com `MATCH tenant:${t}:tarifa:*` e cursor, iterando em lotes (ex.: `redis.scanIterator({ MATCH: ... })` se o cliente suportar, ou loop manual de `SCAN` até cursor `0`). Nunca `KEYS` em produção fora de scripts administrativos pontuais.

## 3. [MÉDIO] Janela de corrida na invalidação de escrita + ausência de TTL em `atualizarTarifa`

**Onde:** `services/tarifas/src/tarifa/servico.ts`, linhas 5–9.

```ts
await redis.del(`tenant:${t}:tarifa:${id}`);
await db.tarifa.update(id, nova);
await redis.set(`tenant:${t}:tarifa:${id}`, JSON.stringify(nova));
```

Duas observações:

- **Ordem del → update → set** abre uma janela entre o `del` e o `update` no Postgres em que qualquer leitor concorrente que faça cache-aside (miss → lê Postgres → grava cache) ainda vai ler o valor antigo do banco (a escrita não terminou) e pode repopular o cache com esse valor antigo. Dependendo do timing de I/O, essa gravação concorrente pode terminar depois do `set` final desta função, deixando o cache com o valor velho mesmo após a atualização "ter sucesso". Padrão mais seguro: gravar no banco primeiro e só então invalidar (`del`) a chave — sem reescrever no mesmo passo — deixando o próximo leitor repovoar sob demanda; se o padrão write-through for mantido por performance, pelo menos manter um TTL curto como rede de segurança (ver próximo ponto).
- **Sem TTL:** o `redis.set` aqui não define expiração (compare com `linha/servico.ts`, que usa `{ EX: 3600 }`). Como a fonte de verdade é o Postgres e tarifas mudam poucas vezes por dia, isso é aceitável em uso normal, mas significa que qualquer bug de invalidação (este aqui, ou um caminho de escrita futuro que esqueça de invalidar) deixa a entrada errada no cache para sempre, sem nenhuma rede de segurança temporal.

**Correção sugerida:** inverter a ordem (`update` no banco, depois `del` — ou `set` com o valor novo — na chave) e adicionar um TTL de segurança ao `set` de tarifa, ex. `{ EX: 3600 }` (mesmo valor usado em linha), para limitar o blast radius de qualquer janela de corrida remanescente ou falha de invalidação.

## 4. [MÉDIO] `infra/redis/redis.conf`: sem limite de memória nem política de eviction

**Onde:** `infra/redis/redis.conf`, linhas 5–6 (`maxmemory 0`, `maxmemory-policy noeviction`).

O README confirma que esse Redis é só cache de leitura. Com `maxmemory 0` (sem teto) e `maxmemory-policy noeviction`, o Redis nunca remove chaves por pressão de memória — ele só cresce. Combinado com o achado #3 (chaves de tarifa sem TTL), o cenário de pior caso é o processo Redis crescer até o sistema operacional matar por OOM, derrubando o cache inteiro (e, se a máquina for compartilhada, afetando outros processos), em vez de simplesmente descartar as entradas menos usadas.

**Correção:** definir um `maxmemory` dimensionado pela capacidade da instância e trocar a política para `allkeys-lru` (ou `volatile-lru`, já que `linha` usa TTL e, com a correção do item 3, `tarifa` também passaria a usar) — normal para um cache puro sem persistência.

## 5. [BAIXO — fora do escopo estrito de cache, mas no arquivo citado] Redis exposto sem autenticação

**Onde:** `infra/redis/redis.conf`, linhas 3–4 (`bind 0.0.0.0`, `protected-mode no`), sem `requirepass`/ACL no arquivo.

O Redis aceita conexão em qualquer interface de rede com proteção desligada e sem senha configurada neste arquivo. Pode já estar mitigado por rede/firewall fora deste repo, mas não deveria depender só disso — vale nota para tratar (talvez em revisão separada de infra/segurança, já que o pedido aqui foi especificamente sobre uso de cache).

---

## Resumo por prioridade

| # | Severidade | Arquivo | Resumo |
|---|---|---|---|
| 1 | Bloqueador | `linha/servico.ts` | Chave de cache sem tenant → vazamento de dado entre operadoras |
| 2 | Alto | `tarifa/servico.ts` | `KEYS` bloqueante em serviço de alto throughput → trocar por `SCAN` |
| 3 | Médio | `tarifa/servico.ts` | Ordem de invalidação com janela de corrida + falta de TTL de segurança |
| 4 | Médio | `infra/redis/redis.conf` | Sem `maxmemory`/eviction → risco de OOM |
| 5 | Baixo | `infra/redis/redis.conf` | Redis sem autenticação/bind restrito (nota, fora do escopo estrito) |

Recomendação: itens 1 e 2 bloqueiam o PR; 3 e 4 devem ser corrigidos antes ou logo depois; 5 fica como acompanhamento separado.
