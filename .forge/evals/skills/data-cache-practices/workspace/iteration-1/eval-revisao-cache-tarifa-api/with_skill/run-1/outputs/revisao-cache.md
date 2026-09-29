# Revisão de cache — tarifa-api (pré-produção)

Escopo revisado: `services/tarifa-api/src/cache/tarifaCache.ts` (código de cache), `services/tarifa-api/infra/redis/redis.conf` (config da instância) e `services/tarifa-api/infra/terraform/redis.tf` (ElastiCache + security group). Revisão de leitura — nenhum código foi alterado; o time aplica as correções.

Fonte de verdade de cada chave: `tenant:{id}:tarifa:{linhaId}` e `tenant:{id}:parametros` vêm de `db.tarifas`/`db.parametros` (PostgreSQL, via `@bilhetagem/persistencia`); `linhas:grupo:{grupoId}` vem de `db.linhas.find({ grupoId })`. As três são cópias derivadas e legítimas para cache-aside.

Regras aplicadas: `.forge/rules/data/data-cache.md` (namespace por tenant obrigatório, TTL explícito em toda entrada, classes proibidas, invalidação explícita, degradação graciosa) e `.forge/rules/data/data-governance.md` (isolamento multi-tenant é decisão única — para Redis/Memcache o mecanismo é namespacing de chave por tenant). Nenhum ADR de governança de dados foi encontrado no baseline do projeto (`based_on: []` nas duas rules); a recomendação de ADR ao final não é bloqueante para esta revisão.

## Achados

### 1. Vazamento cross-tenant em `linhas:grupo:{grupoId}` — bloqueante

`getLinhasDoGrupo` (tarifaCache.ts:19-25) grava a chave `linhas:grupo:${grupoId}` sem prefixo `tenant:{id}:`. `data-cache.md` é taxativo: "cache sem namespace de tenant é vetor de vazamento cross-tenant = conflito bloqueante", e `data-governance.md` trata o isolamento multi-tenant como decisão única — para Redis o mecanismo é namespacing de chave, sem exceção por endpoint. Esta chave não tem detector estático confiável (a regra do scanner cobre escrita sem TTL, não ausência de tenant no namespace); é item de revisão manual, conforme o protocolo da skill.

Risco concreto: se `grupoId` não for globalmente único entre operadoras (cenário plausível — cada tenant provavelmente numera seus próprios grupos de linhas), a operadora B lê as linhas da operadora A a partir do mesmo `grupoId`, e a escrita de uma sobrescreve o cache da outra. Mesmo que `grupoId` seja hoje um UUID globalmente único, o cache não impõe isso — é uma invariante implícita e frágil, e diverge do mecanismo único de isolamento que `data-governance.md` exige para todo o domínio.

Correção esperada: `tenant:${tenantId}:linhas:grupo:${grupoId}` — o que exige receber `tenantId` como parâmetro da função (hoje ela só recebe `grupoId`); os chamadores precisam ser ajustados.

### 2. Duas escritas sem TTL — bloqueante (deriva de #1 e do TTL ausente)

Scanner (`scan.sh` C-02, aviso; elevado a bloqueante aqui por cruzar com a regra do projeto): `tarifaCache.ts:23` (`getLinhasDoGrupo`) e `tarifaCache.ts:32` (`getParametros`) chamam `redis.set(...)` sem `EX`/`PX` na mesma linha.

- `getLinhasDoGrupo`: não há **nenhum** `expire`/`EX` no fluxo inteiro — a chave (já sem namespace de tenant, achado #1) fica em cache indefinidamente, violando "TTL explícito em toda entrada" de `data-cache.md` sem ressalva.
- `getParametros`: o TTL é aplicado por uma segunda chamada, `redis.expire(chave, TTL_PARAMETROS_S)`, na linha seguinte (tarifaCache.ts:33) — não é ausência de TTL, mas as duas chamadas não são atômicas. Entre o `SET` e o `EXPIRE` há uma janela em que a chave existe sem expiração; se o processo cair nesse intervalo (exceção, kill, OOM), a chave fica sem TTL permanentemente. Corrigir para `{ EX: TTL_PARAMETROS_S }` no próprio `SET`, como já é feito em `getTarifa` (tarifaCache.ts:15).

### 3. `KEYS` em `limparTarifasDoTenant` — bloqueante

`tarifaCache.ts:46`: `await redis.keys(\`tenant:${tenantId}:tarifa:*\`)`. `KEYS` é O(N) sobre o keyspace inteiro e roda na thread principal do Redis — numa instância multi-tenant compartilhada (este projeto: uma operadora por tenant, todas no mesmo Redis), a varredura de limpeza de um tenant bloqueia a latência de leitura de todos os outros tenants simultaneamente. Trocar por `SCAN` com `MATCH tenant:${tenantId}:tarifa:* COUNT <n>` em lote, sem bloquear o servidor.

### 4. `maxmemory 0` + `maxmemory-policy noeviction` — bloqueante

`redis.conf:5-6`. Sem limite de memória e sem política de eviction: a instância cresce até o limite do host (o comentário do próprio arquivo diz "só cache, sem estado durável", mas a config não reflete isso) e, se atingir o limite do node (`cache.t4g.medium`, ver `redis.tf`), passa a recusar toda escrita nova (`OOM command not allowed`) em vez de despejar chaves antigas — o oposto do comportamento esperado de um cache. Definir `maxmemory` explícito (com folga para o buffer de replicação, já que `num_cache_clusters = 2`) e `maxmemory-policy allkeys-lru` ou `allkeys-lfu`, coerente com "cache efêmero" do README.

### 5. `protected-mode no` sem `requirepass`/ACL — bloqueante

`redis.conf:4` desliga o `protected-mode`, e não há `requirepass` nem `aclfile`/`user ... on` em nenhum ponto do arquivo — a instância aceita comandos de qualquer cliente que alcance a porta 6379, sem autenticação. `data-governance.md` não permite exceção por store: a regra de integração do dono é "Redis nunca exposto"; aqui ele nem está isolado por autenticação dentro da própria rede interna. Reativar `protected-mode yes` e configurar `requirepass` (ou, no ElastiCache gerenciado, `auth_token` no `redis.tf` — hoje ausente — e AUTH/ACL do provedor) antes de subir para produção.

### 6. Security group do ElastiCache aberto a `0.0.0.0/0` — bloqueante

`redis.tf:20-21`: a regra de ingress da porta 6379 tem `cidr_blocks = ["0.0.0.0/0"]` — qualquer origem na internet (o `security_group_ids` não impede tráfego externo à VPC; `0.0.0.0/0` inclui fora da VPC caso o SG esteja associado a um recurso com IP público, e mesmo dentro da VPC é liberação total sem necessidade). Junta-se ao achado #5: hoje não há nem rede fechada nem autenticação — as duas camadas de defesa em profundidade que `data-governance.md` pede para Redis (TTL + classes proibidas não cobre rede; a defesa de rede vem do C-11/C-16 do catálogo da skill) estão ausentes ao mesmo tempo. Restringir `cidr_blocks` ao CIDR da VPC ou a um security group de origem (os serviços do tarifa-api), nunca `0.0.0.0/0`.

## Verificados e limpos (sem achado)

- **Classes de dado proibidas em cache** (segredo, PAN/CVV/track, PII sem máscara): nenhuma chave ou valor cacheado neste arquivo contém dado de cartão, segredo ou PII identificável — tarifas (valor em centavos) e parâmetros de linha/operadora são dado de negócio, não dado sensível de titular. `check-data-governance.sh --path services/tarifa-api` rodou limpo (3 arquivos examinados, sem divergência; o projeto não tem `data-classification.json`, então a checagem cobriu o universo disponível, não PAN/PII especificamente).
- **Invalidação em `atualizarTarifa`** (tarifaCache.ts:37-43): faz `DEL` da chave **antes** da transação no banco, não depois. Isso é o inverso do padrão cache-aside recomendado (invalidar após confirmar o commit, para não deixar uma janela em que outro leitor recalcula e regrava o valor antigo no cache antes do commit terminar) — não é um dos IDs C-01 a C-17 do catálogo (o scanner não cobre ordem de invalidação por ser um padrão multi-linha), mas é o antipattern C-01 do catálogo por definição textual. Se `db.transaction` puder falhar após o `DEL`, o cache fica vazio até o próximo `getTarifa` recalcular do banco (correto, é cache-aside), mas se uma leitura concorrente ocorrer entre o `DEL` e o commit, ela pode repovoar o cache com o valor antigo antes da transação terminar. Como é uma janela estreita (um único `UPDATE` dentro da transação) e o dado errado seria sobrescrito no próximo `DEL` de uma nova tentativa de escrita, registro como observação, não como bloqueante — mas o time deve considerar mover o `DEL` para depois do `await db.transaction(...)` concluir.
- **`getTarifa`** (tarifaCache.ts:9-16): TTL explícito (`EX: TTL_TARIFA_S`) na mesma chamada, chave namespaced por tenant. Sem achado.
- **Serialização**: todas as chaves usam `JSON.stringify`/`JSON.parse` sem versionamento de schema explícito (campo `v` ou similar). `data-cache.md` recomenda "serialização versionada (evitar quebrar leitura de cache em deploy)" — não é um dos IDs do catálogo, é convenção sem detector; sinalizo como observação de baixo risco dado o TTL curto (300-600s) de todas as entradas, que já limita a janela de incompatibilidade num deploy.
- **Degradação graciosa**: não verificável estaticamente neste arquivo — não há tratamento de exceção do cliente Redis em nenhuma das funções (se `redis.get`/`redis.set` lançar, a função inteira lança, sem cair para a fonte). `data-cache.md` pede que "indisponibilidade do cache não derrube o fluxo". Como o scanner não cobre esse padrão e não há evidência de captura de erro no arquivo, registro como item de revisão manual (não confirmado como achado, porque a ausência de `try/catch` no trecho lido não prova que não há tratamento em camada superior — ex.: middleware de erro do framework).

## Resumo por regra (protocolo da skill)

| Regra | Resultado |
|---|---|
| C-02 — escrita sem TTL | FOUND (aviso do scanner, tratado como bloqueante aqui) — tarifaCache.ts:23, tarifaCache.ts:32 |
| C-08 — cache local sem expiração | OK, nenhuma ocorrência |
| C-09 — KEYS em produção | FOUND (aviso do scanner, tratado como bloqueante aqui) — tarifaCache.ts:46 |
| C-10 — maxmemory 0 / noeviction | FOUND (alto) — redis.conf:5, redis.conf:6 |
| C-11 — Redis exposto sem autenticação | FOUND (alto) — redis.conf:4 |
| C-15 — PAN/SAD em cache | OK, nenhuma ocorrência |
| C-16 — rede aberta na porta do Redis | FOUND (aviso do scanner, tratado como bloqueante aqui) — redis.tf:21 |
| C-17 — bind em todas as interfaces com autenticação | OK, nenhuma ocorrência (não se aplica: `bind` está restrito a uma interface, `10.20.0.15`) |
| Namespace de tenant (revisão manual, sem detector) | FOUND — `linhas:grupo:{grupoId}` sem prefixo `tenant:{id}:` |

## O que precisa mudar antes de produção (bloqueante)

1. Prefixar `linhas:grupo:{grupoId}` com `tenant:{id}:` em `getLinhasDoGrupo` — inclui mudar a assinatura da função para receber `tenantId` e ajustar os chamadores.
2. Adicionar TTL explícito no `SET` de `getLinhasDoGrupo` (hoje sem nenhum) e mover o TTL de `getParametros` para dentro do próprio `SET` (`{ EX: TTL_PARAMETROS_S }`), eliminando a janela sem expiração entre `SET` e `EXPIRE`.
3. Trocar `redis.keys(...)` por `SCAN`/`MATCH` em `limparTarifasDoTenant`.
4. Definir `maxmemory` explícito e `maxmemory-policy allkeys-lru` (ou `allkeys-lfu`) em `redis.conf`.
5. Reativar `protected-mode yes` e configurar autenticação (`requirepass` ou `auth_token`/ACL do ElastiCache — hoje ausente em `redis.tf`).
6. Restringir `cidr_blocks` do security group do ElastiCache à VPC/serviços do tarifa-api, removendo `0.0.0.0/0`.

## Observações não bloqueantes (para o time avaliar)

- Mover o `DEL` de `atualizarTarifa` para depois do `await db.transaction(...)` concluir, fechando a janela de repovoamento com valor antigo.
- Adicionar tratamento de erro do cliente Redis (try/catch com fallback para a fonte) nas quatro funções de leitura, se não existir em camada superior.
- Considerar versionar a serialização JSON, dado o TTL curto isso é baixo risco hoje, mas vale registrar caso o TTL de algum recurso cresça no futuro.
- Não há ADR de governança de dados no baseline (`based_on: []` em `data-governance.md`/`data-cache.md`); fora do escopo desta revisão, mas vale abrir via `/forge:adr` se o projeto quiser ancorar formalmente a decisão de isolamento multi-tenant por store.
