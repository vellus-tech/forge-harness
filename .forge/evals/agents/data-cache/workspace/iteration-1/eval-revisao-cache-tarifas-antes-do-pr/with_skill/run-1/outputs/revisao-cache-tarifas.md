# Revisão de cache — services/tarifas (pré-PR)

Escopo: `services/tarifas/src` e `infra/redis/redis.conf`. Fonte da verdade confirmada pelo README do serviço: PostgreSQL; o Redis é só cache de leitura — sem conflito de fonte de verdade a reportar (C-07 não se aplica). Produto multi-tenant por operadora, com o agravante explícito no README de que duas operadoras podem ter uma linha com o mesmo id.

Nenhum bloco `CONFLITO` necessário: a regra do projeto (`data-cache.md`) e a skill concordam entre si; os achados abaixo são violação de código contra as duas, não divergência de autoridade.

## Achado 1 — bloqueante: chave de `linha` sem namespace de tenant (vazamento cross-tenant)

- **Onde:** `services/tarifas/src/linha/servico.ts:6` e `:9` — `buscarLinha` lê e grava em `linha:${id}`, sem o tenant.
- **Por quê é grave:** o README do serviço declara que duas operadoras podem cadastrar uma linha com o mesmo `id`. Sem `tenant:{id}:` na chave, a operadora B lê no cache a linha que a operadora A gravou por último para o mesmo `id` — vazamento de dado cross-tenant, exatamente o vetor que a `data-cache.md` chama de "conflito bloqueante" (regra: "toda chave inclui o tenant — `tenant:{id}:<recurso>:<id>`"). O parâmetro `t` (tenant) já está disponível na função e é usado na consulta ao banco (`db.linha.findOne({ operadora: t, id })`), só não é usado na chave do Redis.
- **Correção:**
  ```ts
  export async function buscarLinha(t: string, id: string): Promise<Linha> {
    const chave = `tenant:${t}:linha:${id}`;
    const hit = await redis.get(chave);
    if (hit) return JSON.parse(hit) as Linha;
    const linha = await db.linha.findOne({ operadora: t, id });
    await redis.set(chave, JSON.stringify(linha), { EX: 3600 });
    return linha;
  }
  ```
  (o TTL de 3600s já existe nessa função — mantenha.)

## Achado 2 — invalidação na ordem errada + set em vez de delete (C-01)

- **Onde:** `services/tarifas/src/tarifa/servico.ts:5-8`, função `atualizarTarifa`.
- **Código atual:**
  ```ts
  await redis.del(`tenant:${t}:tarifa:${id}`);
  await db.tarifa.update(id, nova);
  await redis.set(`tenant:${t}:tarifa:${id}`, JSON.stringify(nova));
  ```
- **Por quê é grave:** o `del` acontece antes do commit no Postgres — abre uma janela em que um leitor concorrente (num caminho de leitura que faz cache-aside, hoje ausente neste arquivo mas plausível em outro ponto do serviço) recarrega a origem ainda com o valor antigo e repopula a chave, que só é atualizada depois pelo `set` final. Some com o catálogo (C-01: "delete antes do commit, ou set em vez de delete, abre janela em que leitor concorrente relê a origem ainda antiga e repopula a chave") e com o checklist do próprio agente ("Invalidação: origem primeiro, delete depois do commit, delete em vez de set"). Tarifas são lidas ~10 mil vezes por segundo segundo o README — a janela de corrida é pequena, mas o volume de leitura a torna praticável.
- **Correção (gravar origem, confirmar commit, só então invalidar; delete em vez de set):**
  ```ts
  export async function atualizarTarifa(t: string, id: string, nova: Tarifa): Promise<void> {
    await db.tarifa.update(id, nova);
    await redis.del(`tenant:${t}:tarifa:${id}`);
  }
  ```
  O `set` final deixa de existir: a próxima leitura repopula a chave (cache-aside), e delete-em-vez-de-set evita gravar payload potencialmente obsoleto se houver duas atualizações concorrentes da mesma tarifa.

## Achado 3 — escrita em cache sem TTL (C-02)

- **Onde:** `services/tarifas/src/tarifa/servico.ts:8` — `redis.set(\`tenant:${t}:tarifa:${id}\`, JSON.stringify(nova))` sem `EX`/`PX`.
- **Confirmado por `scan.sh C-02`.**
- **Por quê é grave:** a `data-cache.md` exige TTL explícito em toda entrada; sem expiração a chave só sai por eviction, e com `maxmemory 0`/`noeviction` no `redis.conf` atual (achado 5) ela nunca sai — memória cresce sem limite e dado potencialmente obsoleto fica servido para sempre caso algum caminho volte a gravar direto no cache.
- **Correção:** se a correção do achado 2 for aplicada (delete-only na invalidação), este achado é resolvido junto — o `set` sem TTL deixa de existir. Se por algum motivo de produto o `set` direto for mantido, ele precisa de `{ EX: <ttl> }` proporcional à tolerância a dado velho, com jitter se for gravado em lote.

## Achado 4 — `KEYS` em produção (C-09)

- **Onde:** `services/tarifas/src/tarifa/servico.ts:12` — `chavesDoTenant` usa `redis.keys(\`tenant:${t}:tarifa:*\`)`.
- **Confirmado por `scan.sh C-09`.**
- **Por quê é grave:** `KEYS` é O(N) sobre o keyspace inteiro e roda na thread principal do Redis — bloqueia todo o tráfego (inclusive as ~10 mil leituras/s de tarifa) pelo tempo da varredura. Cresce com o keyspace total, não só com o do tenant.
- **Correção:** substituir por `SCAN` com `MATCH` e `COUNT`, paginando o cursor:
  ```ts
  export async function chavesDoTenant(t: string): Promise<string[]> {
    const chaves: string[] = [];
    let cursor = "0";
    do {
      const res = await redis.scan(cursor, { MATCH: `tenant:${t}:tarifa:*`, COUNT: 200 });
      cursor = res.cursor;
      chaves.push(...res.keys);
    } while (cursor !== "0");
    return chaves;
  }
  ```
  (assinatura exata do client Redis usado no projeto pode variar — o `task-coder` ajusta aos tipos reais; o ponto fixo é `SCAN`+`MATCH`, nunca `KEYS`.)

## Achado 5 — Redis exposto, sem proteção e sem limite de memória (C-10 + C-11)

- **Onde:** `infra/redis/redis.conf`.
  - Linha 3: `bind 0.0.0.0`
  - Linha 4: `protected-mode no`
  - Linha 5: `maxmemory 0`
  - Linha 6: `maxmemory-policy noeviction`
- **Confirmado por `scan.sh` (C-10 alto, C-11 alto).** `check-data-governance.sh` não examina `.conf` (universo-vazio — fora do escopo de linguagem do script: `.go/.kt/.ts/.rego/.py/.md`), então PAN/PII neste arquivo não foi verificado por ele; não é relevante aqui pois é um arquivo de configuração, não dado.
- **Por quê é grave:**
  - **C-11:** bind em todas as interfaces + `protected-mode no` e sem `requirepass`/`aclfile`/`user ... on` no arquivo = instância alcançável de qualquer origem de rede sem autenticação. Viola diretamente a regra de integração do dono ("Redis nunca é exposto a terceiros"; aqui nem exige terceiro — está aberto a qualquer origem que alcance a porta).
  - **C-10:** `maxmemory 0` (sem limite) com `noeviction` — a instância cresce até esgotar a memória do host e, cheia, passa a recusar toda escrita (`OOM command not allowed`) em vez de despejar chaves de cache, que é justamente o que uma instância só-de-cache deveria fazer.
- **Correção:**
  ```conf
  bind 127.0.0.1 -<ip-privado-do-serviço>
  protected-mode yes
  requirepass <segredo via gerenciador de segredos, nunca literal no arquivo>
  maxmemory 512mb        # dimensionar pelo volume real de tarifas+linhas cacheadas, com folga
  maxmemory-policy allkeys-lru
  ```
  Valores de `bind` e `maxmemory` dependem do ambiente de deploy (K8s vs VM) e do tamanho real do dataset — o `task-coder` ajusta ao ambiente real; os pontos fixos são: nunca `0.0.0.0` sem auth, nunca `maxmemory 0`/`noeviction` numa instância que é só cache. Se o deploy for Kubernetes com NetworkPolicy restringindo origem, considerar também ACL por aplicação (`aclfile`) em vez de só `requirepass`, e neste caso a exposição vira C-17 (dependente de controle fora do arquivo) em vez de C-11 — ainda assim, a ausência de qualquer autenticação hoje já é C-11.

## Não avaliado neste escopo

- `money-as-cents.md` (Tarifa como inteiro em centavos): fora do escopo pedido ("revisão só do uso de cache"); os trechos de código mostrados não expõem o tipo de `Tarifa.valor` para julgar. Se o PR tocar a modelagem de valor monetário, vale checagem à parte pelo `data-cache` ou pelo agente de domínio.
- Stampede (C-04), chave quente/grande (C-05/C-06), cross-slot (C-12): não há evidência estática de shard/cluster nem de coleção grande nestes dois arquivos; não aplicável ao código revisado. Se o Redis rodar em cluster, vale runtime-check à parte.
- PAN/CVV em cache (C-15/T-01): scanner não encontrou ocorrência (`OK C-15`); `check-data-governance.sh` em `services/tarifas/src` não achou divergência. Nada a reportar aqui.

## Resumo para o PR (ordem de prioridade)

1. **Bloqueante — corrigir antes do PR:** achado 1 (vazamento cross-tenant em `linha`) e achado 5 (Redis exposto sem auth).
2. **Alto — corrigir antes do PR:** achado 2 (ordem de invalidação) e achado 3 (TTL) — resolvidos juntos com a mesma mudança.
3. **Médio:** achado 4 (`KEYS` → `SCAN`).
