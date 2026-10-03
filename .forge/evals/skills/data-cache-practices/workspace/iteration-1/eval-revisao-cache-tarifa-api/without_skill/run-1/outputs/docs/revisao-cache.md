# Revisão do cache Redis — tarifa-api (pré-produção)

Revisão de `services/tarifa-api/src/cache/tarifaCache.ts` e da infraestrutura em `services/tarifa-api/infra/` (redis.conf e Terraform do ElastiCache), feita antes da subida para produção. O serviço é multi-tenant (cada operadora de transporte é um tenant) e usa Redis como cache-aside na frente do PostgreSQL. Este documento é só diagnóstico — nenhum código foi alterado; o time aplica as correções.

## Resumo executivo

Há dois problemas que classifico como bloqueantes para produção: o Redis está acessível sem autenticação e com o security group aberto para a internet inteira, e há uma chave de cache (`linhas:grupo:{grupoId}`) sem prefixo de tenant, o que é um risco de vazamento de dado entre operadoras num sistema que se declara multi-tenant. Os demais achados são de robustez e consistência — política de eviction incompatível com um cache puro, TTL ausente ou não atômico em duas rotas, uso de `KEYS` num comando de limpeza, e uma provável desconexão entre o `redis.conf` do repositório e o parameter group real do ElastiCache, que faz o Terraform não aplicar nada do que o `redis.conf` documenta.

## Achados críticos

**Redis sem autenticação e exposto a 0.0.0.0/0.** `redis.conf` tem `protected-mode no` e nenhuma diretiva `requirepass`; o Terraform (`redis.tf`) habilita `transit_encryption_enabled` mas não define `auth_token`, e o security group `tarifa_cache` libera a porta 6379 para `cidr_blocks = ["0.0.0.0/0"]`. TLS em trânsito sem token de autenticação não impede comando algum — qualquer cliente que alcance a porta lê e escreve no cache de todos os tenants. Isso precisa ser fechado antes de produção: `auth_token` no `aws_elasticache_replication_group` (com `transit_encryption_enabled = true`, que já está setado, o AUTH token é suportado) e o ingress do security group restrito à SG da aplicação ou ao CIDR da VPC, nunca `0.0.0.0/0`.

**Chave de cache sem isolamento de tenant.** `getLinhasDoGrupo` usa a chave `linhas:grupo:${grupoId}`, sem o prefixo `tenant:{tenantId}:` que as demais funções (`getTarifa`, `atualizarTarifa`, `limparTarifasDoTenant`) usam. Se `grupoId` não for garantidamente único entre operadoras diferentes — e não há nada no código que garanta isso, já que o parâmetro não carrega o tenant — uma operadora pode ler no cache as linhas de outra. Isso precisa ser confirmado com quem modela `grupoId` no domínio; se não houver unicidade global garantida, a chave tem que virar `tenant:${tenantId}:linhas:grupo:${grupoId}` e a função precisa passar a receber `tenantId`.

## Achados de robustez e consistência

**`maxmemory-policy noeviction` num Redis que é só cache.** O próprio comentário do `redis.conf` diz "só cache, sem estado durável", mas a política de eviction é `noeviction` com `maxmemory 0` (sem limite). Sem limite de memória, a instância `cache.t4g.medium` pode ficar sem memória do host; e mesmo com um limite configurado, `noeviction` faz todo comando de escrita falhar com erro de OOM quando o limite é atingido, em vez de descartar chaves antigas — o oposto do que se quer num cache-aside. Para esse padrão de uso, o esperado é `maxmemory` com um valor abaixo da memória do nó e `maxmemory-policy allkeys-lru` (ou `volatile-lru`, já que a maioria das chaves tem TTL).

**Chave sem TTL em `getLinhasDoGrupo`.** `redis.set(chave, JSON.stringify(linhas))` é chamado sem `EX`; a chave nunca expira. Combinado com `noeviction`, essa chave (e qualquer outra sem TTL) fica presa no cache indefinidamente, envelhecendo sem forma de invalidação automática. Precisa de um TTL, análogo ao `TTL_TARIFA_S`/`TTL_PARAMETROS_S` já usados nas outras rotas.

**`getParametros` seta valor e TTL em dois comandos separados.** `redis.set(chave, ...)` seguido de `redis.expire(chave, TTL_PARAMETROS_S)` não é atômico — se o processo cair, a conexão cair, ou houver qualquer erro entre as duas chamadas, a chave fica gravada sem expiração, e some do controle do `noeviction`/TTL o `redis.get` sempre retorna o para sempre. O padrão já usado em `getTarifa` (`redis.set(chave, valor, { EX: ttl })`) resolve isso num único comando atômico e deveria ser replicado aqui.

**`limparTarifasDoTenant` usa `KEYS`.** `redis.keys(...)` percorre o keyspace inteiro de forma bloqueante — problemático numa instância compartilhada por múltiplos tenants, onde uma operação de limpeza de um tenant pode travar o event loop single-threaded do Redis e degradar a latência de todos os outros. O padrão recomendado é iterar com `SCAN` (cursor a cursor, com `MATCH` no padrão da chave) em vez de `KEYS`.

**Ausência de invalidação para o cache de parâmetros.** `getParametros` grava `tenant:{tenantId}:parametros` no cache, mas não há, no arquivo revisado, nenhuma função equivalente a `atualizarTarifa` para invalidar essa chave quando os parâmetros do tenant mudam. Se existir uma rota de atualização de parâmetros em outro lugar do serviço, ela precisa invalidar essa chave; se não existir, os parâmetros ficam presos ao TTL de 600s como único mecanismo de atualização, o que pode ser aceitável ou não dependendo de quão sensível a mudança é — vale confirmar com o time antes de assumir que está certo.

**Sem tratamento de falha do Redis nas leituras.** Nenhuma das funções de leitura (`getTarifa`, `getLinhasDoGrupo`, `getParametros`) trata erro de conexão ou timeout do Redis — uma falha na chamada `redis.get` propaga como exceção não capturada e derruba a requisição inteira, mesmo que o PostgreSQL esteja saudável e a consulta pudesse seguir direto ao banco. Para um serviço de tarifas em produção, o padrão esperado de cache-aside é falhar aberto: capturar erro do Redis, logar, e cair para o banco, sem que uma instabilidade do cache vire indisponibilidade do serviço.

**Cliente Redis sem timeout de socket nem estratégia de reconexão configurados.** `createClient({ url: process.env.REDIS_URL })` usa só a URL, sem `socket.connectTimeout`, sem `socket.reconnectStrategy` e sem confirmação, neste arquivo, de que `redis.connect()` é chamado em algum bootstrap do serviço (o client da lib `redis` v4 exige conexão explícita). Isso é mais uma checagem a fazer no restante do serviço do que um defeito confirmado neste arquivo — mas se `connect()` não for chamado em algum ponto de inicialização, todas as chamadas de cache travam ou falham silenciosamente.

## Achado de infraestrutura — `redis.conf` provavelmente não tem efeito nenhum

O `redis.tf` provisiona um `aws_elasticache_replication_group` sem `parameter_group_name`, ou seja, usa o parameter group padrão da engine. O ElastiCache não lê `redis.conf` de jeito nenhum — os parâmetros de um nó gerenciado (incluindo `maxmemory-policy`, `maxmemory`, `appendonly`) só são aplicados através de um `aws_elasticache_parameter_group` referenciado no Terraform. Isso quer dizer que tudo que está documentado em `services/tarifa-api/infra/redis/redis.conf` — inclusive a política de eviction e o `maxmemory` discutidos acima — provavelmente não reflete o comportamento real da instância em produção, que está rodando com os defaults do parameter group da AWS. Isso precisa ser resolvido criando um `aws_elasticache_parameter_group` explícito com os valores corretos e removendo ou marcando `redis.conf` como documentação de referência apenas, para não induzir o time a acreditar que aquele arquivo está em vigor.

Outros pontos do `redis.tf` que valem checagem, sem confirmação de que são erro: não há `at_rest_encryption_enabled`, não há `automatic_failover_enabled` (num grupo com 2 nós, sem failover automático a promoção do replica em caso de falha do primário não é automática), e não há `multi_az_enabled`. Para um serviço que bloqueia a subida para produção, esses três valem uma decisão explícita do time, mesmo que a resposta seja "aceitável para esse serviço porque é só cache".

## O que precisa mudar antes de produção (visão consolidada)

1. Definir `auth_token` no `aws_elasticache_replication_group` e restringir o `ingress` do security group à origem real (SG da aplicação ou CIDR da VPC), nunca `0.0.0.0/0` — bloqueante.
2. Confirmar se `grupoId` é único entre tenants; se não for, prefixar a chave de `getLinhasDoGrupo` com `tenant:{tenantId}:` — bloqueante.
3. Criar um `aws_elasticache_parameter_group` com `maxmemory-policy allkeys-lru` (ou `volatile-lru`) e um `maxmemory` explícito, e referenciá-lo no `replication_group`; alinhar ou aposentar o `redis.conf` do repositório.
4. Adicionar TTL em `getLinhasDoGrupo` e trocar `set` + `expire` por um único `SET ... EX` atômico em `getParametros`.
5. Trocar `KEYS` por `SCAN` em `limparTarifasDoTenant`.
6. Adicionar tratamento de falha (fail-open para o banco) nas leituras do cache, e confirmar onde/se `redis.connect()` é chamado no bootstrap do serviço.
7. Confirmar com o time se existe invalidação de `parametros` em algum outro ponto do código; se não existir, decidir se o TTL de 600s é suficiente.
8. Decidir explicitamente sobre `at_rest_encryption_enabled`, `automatic_failover_enabled` e `multi_az_enabled` no `replication_group`.
