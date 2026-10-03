# Revisão de cache — recarga-java (pré-pentest PCI)

Data: 2026-09-28. Escopo: `services/recarga-java/` (Spring, Redis via `StringRedisTemplate` + cache local Caffeine) e `deploy/k8s/` (StatefulSet Redis). Só diagnóstico — nenhum arquivo de código ou manifesto foi alterado.

## 1. Escopo examinado

- `services/recarga-java/src/main/java/br/com/bilhetagem/recarga/RecargaCacheService.java` — único ponto de leitura/escrita de cache no serviço: um cache local Caffeine (`saldoLocal`, saldo do cartão de transporte) e um uso do Redis via `StringRedisTemplate` (`guardarParaRetentativa`, dado de cartão de pagamento para retentativa de recarga).
- `services/recarga-java/src/main/java/br/com/bilhetagem/recarga/SaldoView.java` — DTO do cache local, sem dado de cartão.
- `deploy/k8s/redis-recarga-configmap.yaml` — `redis.conf` da instância.
- `deploy/k8s/redis-recarga-statefulset.yaml` — StatefulSet do Redis (imagem, secret de auth, volume do config).

Fonte da verdade de cada chave: `saldoLocal` deriva do saldo do cartão de transporte (fonte não vista neste corte, presumivelmente o serviço de saldo); a chave de retentativa em Redis **não tem fonte** — ela é o único lugar onde o dado de cartão de pagamento existe durante a janela de retentativa, o que já é um sinal de que não se trata de cache no sentido da rule (cópia derivada, descartável).

Não há `Service`, `NetworkPolicy`, `SecurityGroup` nem configuração de cliente TLS no diretório `deploy/k8s/` — o universo de manifestos do fixture é só ConfigMap + StatefulSet.

## 2. Rules do projeto aplicadas

- `.forge/rules/data/data-cache.md`: namespace por tenant obrigatório, TTL explícito, classes proibidas (segredo, PAN/CVV/track, PII sem máscara), invalidação explícita, serialização versionada, degradação graciosa.
- `.forge/rules/data/data-governance.md`: Redis nunca é fonte de verdade; isolamento multi-tenant por namespace de chave é a defesa em profundidade do store de cache.

## 3. Detecção executada

- `bash .forge/scripts/check-data-governance.sh --path services` e `--path deploy`: **`FAIL data-governance/universo-vazio`** nos dois casos — 0 arquivos examinados. Não há `data-classification.json` no projeto (só o schema em `.forge/schemas/`), então o verificador de governança não tem base para classificar campos. Por instrução da skill, isso é **"não verificado"**, não "limpo": os achados de PAN/CVV abaixo vêm só do complemento heurístico C-15 do `scan.sh`, sem confirmação pela fonte de classificação de dados do projeto.
- `bash .forge/skills/data-cache-practices/scripts/scan.sh --root .` (6 arquivos varridos, motor `rg`):

| Regra | Severidade | Resultado | Local |
|---|---|---|---|
| C-02 (escrita sem TTL) | aviso | OK — nenhuma ocorrência | — |
| C-08 (cache local sem TTL) | aviso | FOUND (1) — **ver julgamento, falso positivo** | `RecargaCacheService.java:14` |
| C-09 (KEYS em produção) | aviso | OK — nenhuma ocorrência | — |
| C-10 (maxmemory 0/noeviction) | alto | OK — nenhuma ocorrência | — |
| C-11 (Redis exposto sem auth) | alto | OK — nenhuma ocorrência | — |
| C-15 (campo de cartão em cache) | aviso | **FOUND (1) — achado real, ver §4** | `RecargaCacheService.java:30` |
| C-16 (rede aberta 0.0.0.0/0 na porta Redis) | aviso | OK — nenhuma ocorrência (não há IaC de rede no fixture) | — |
| C-17 (bind em todas as interfaces com auth) | aviso | FOUND (1) — ver julgamento | `redis-recarga-configmap.yaml:9` |

O scanner não mede runtime (hit ratio, `--hotkeys`, `--bigkeys`, `CONFIG GET` efetivo, `SLOWLOG`): essa parte não foi executada porque não há acesso ao cluster real a partir desta revisão.

## 4. Julgamento — achado por achado

### CRÍTICO — CVV gravado em Redis para retentativa (T-01 + C-15, fora do catálogo por ser SAD, não só PAN)

`guardarParaRetentativa` (linha 29-31) grava `cardNumber + "|" + cvv` como string plana em `redisTemplate.opsForValue().set(...)`, com TTL de 5 minutos, sob a justificativa de retentativa automática quando o adquirente devolve timeout.

Isso viola dois pontos, um deles inegociável para o pentest PCI:

1. **PCI DSS 3.3.1 — SAD (CVV/CVC/track) nunca é armazenado após a autorização, nem por curto prazo, nem cifrado.** O comentário do código ("guarda para a retentativa automática") descreve exatamente o padrão que a norma proíbe: "reter para tentar de novo depois" é a justificativa mais comum para a violação, e a norma não abre exceção de tempo. TTL de 5 minutos mitiga a janela de exposição, mas não torna a gravação permitida.
2. **Persistência do Redis agrava o problema.** O `redis.conf` (linha 14) tem `appendonly yes` com `appendfsync everysec` — o CVV vai para o AOF em disco, não fica só em memória volátil. Isso desloca a leitura de "Redis como cache efêmero" para "Redis como armazenamento persistente de SAD", que traz consigo os requisitos completos de armazenamento de dado de conta (PCI DSS 3.x) sobre uma instância que não foi desenhada, nem operada, para isso — a leitura de Redis persistente como armazenamento de CHD é interpretação técnica; validar com o QSA, mas o ponto de partida do pentest deve assumir o cenário mais restritivo.
3. `.forge/rules/data/data-cache.md` já proíbe classe "PAN/CVV/track" em cache; este é exatamente o caso.
4. Efeito colateral: `SLOWLOG`, `MONITOR` e ferramentas de APM registram argumentos de comando — se algum desses estiver ativo no cluster, o CVV em claro passa a vazar para observabilidade (T-04). Não verificado neste corte (não há configuração de APM/monitoring no fixture).

**Isto não é ajuste de TTL ou de namespace — é o desenho que precisa mudar antes do pentest**, porque um scanner de PCI típico varre `MONITOR`/dump de memória/AOF atrás de padrão de PAN e CVV, e este código os entrega de bandeja. Correção (não aplicada, é diagnóstico): a retentativa deve reapresentar o fluxo de coleta do cartão ao usuário, ou usar um token efêmero de single-use do adquirente/gateway (ex.: token de sessão da própria adquirente, que ela mesma expira), nunca PAN+CVV em claro sob controle do serviço de recarga. Se a adquirente aceitar apenas retentativa com PAN completo, o padrão correto é reapresentar a coleta ao portador — não persistir o SAD.

### C-15 marcado pelo scanner (aviso) — mesma linha do achado acima

O `scan.sh` classifica C-15 como severidade `aviso`, porque é heurístico e complementar ao verificador de governança (que aqui não pôde confirmar, por falta de `data-classification.json`). Neste caso a leitura manual da linha confirma: é `cardNumber` (PAN) e `cvv` (SAD) nomeados explicitamente como parâmetros gravados em `opsForValue().set(...)`, sem qualquer mascaramento. Não há ambiguidade de nome (a lista de exclusões do detector — `span`, `company`, `expand` — não se aplica aqui). Elevo o achado de "aviso" para **crítico** no julgamento desta revisão, por ser T-01 (PAN/SAD em cache) e não apenas o detector estático isolado.

### C-08 (cache local sem TTL) — falso positivo confirmado

O `scan.sh` aponta a linha 14 (`Cache<String, SaldoView> saldoLocal = Caffeine.newBuilder()`) porque a chamada `expireAfterWrite(Duration.ofSeconds(30))` está na linha 16, fora da linha do builder — o próprio catálogo (`antipatterns.md`, C-08) documenta essa limitação: "builder em várias linhas escapa" o detector heurístico. Leitura manual confirma que o builder **tem** TTL (30s) e tamanho máximo (`maximumSize(10_000)`), atendendo à rule da casa. **Sem ação** — achado descartado na revisão, mas registrado aqui para não ficar sem explicação.

### C-17 (bind em todas as interfaces com autenticação) — revisão obrigatória, não confirmável só com o que existe no repo

`redis.conf` (configmap, linha 9) tem `bind 0.0.0.0` junto com `requirepass ${REDIS_PASSWORD}` (linha 11) e `protected-mode yes` — isso tira o achado de C-11 (que seria bloqueante) e o classifica como C-17: a exposição passa a depender inteiramente de controles **fora deste arquivo** (NetworkPolicy do namespace `recarga`, Service `ClusterIP` vs. `LoadBalancer`, security group do nó). O fixture examinado não contém `NetworkPolicy` nem `Service` para este StatefulSet — não dá para confirmar, só com o que está em `deploy/k8s/`, que o Redis fica restrito à rede interna do cluster. **Item de revisão obrigatória antes do pentest**: confirmar (a) existência de `NetworkPolicy` que só permite tráfego de entrada dos pods do `recarga-java` na porta 6379 do namespace `recarga`, (b) que não há `Service` do tipo `LoadBalancer`/`NodePort` associado a este StatefulSet em outro manifesto fora do escopo revisado, (c) TLS entre cliente e Redis — não há `tls-port` no `redis.conf` nem configuração de TLS no cliente Spring (`RecargaCacheService` usa `StringRedisTemplate` sem indicação de `RedisStandaloneConfiguration` com SSL neste corte de código); tráfego em claro dentro do cluster ainda expõe o CVV do achado crítico acima a qualquer sniffing interno.

### Namespace por tenant e TTL — conformes

- `saldoLocal.getIfPresent("tenant:" + tenantId + ":saldo:" + cartaoTransporteId)` e `chaveRetentativa` (`"tenant:" + tenantId + ":recarga:retentativa:" + pedidoId"`) seguem o padrão `tenant:{id}:...` exigido pela `data-cache.md` e pela `data-governance.md`. Nenhum achado aqui.
- TTL explícito presente nos dois usos de cache (Caffeine 30s; Redis 5 minutos). Nenhum achado de C-02/C-08 real.

### maxmemory e eviction — conformes

`maxmemory 512mb` e `maxmemory-policy allkeys-lru` estão explícitos no `redis.conf` (linhas 12-13); não há `maxmemory 0` nem `noeviction`. Nenhum achado C-10.

### Fora do alcance desta revisão (não verificado, listar para o time antes do pentest)

- **Invalidação (C-01) e degradação graciosa**: o código examinado só mostra leitura (`saldoEmCache`) e a escrita de retentativa; não há, neste corte, o caminho de escrita/invalidação do `saldoLocal` (quem popula e quem invalida em recarga bem-sucedida) nem o comportamento do serviço se o Redis cair. Pedir ao time o método que popula `saldoLocal` e o tratamento de exceção de conexão com o Redis.
- **Runtime** (`redis-cli --hotkeys`, `--bigkeys`, `CONFIG GET` efetivo, `SLOWLOG`, hit ratio via `INFO stats`): não executado — exige acesso ao cluster real, fora do escopo desta revisão estática.
- **Serialização versionada**: não há indício de versão na chave (`tenant:{id}:saldo:{id}` sem sufixo de versão); baixo risco dado que `SaldoView` é um record simples, mas vale registrar para deploys futuros que mudem o formato.

## 5. Relatório resumido (uma linha por regra)

- C-01 invalidação: não verificado (caminho de escrita não visto).
- C-02 escrita sem TTL: limpo.
- C-03 TTL sem jitter: não verificado (só duas chaves, baixo risco de carga em lote síncrona).
- C-04 stampede: não verificado (sem visão do caminho de miss/populate).
- C-05/C-06 chave quente/grande: não verificado (runtime).
- C-07 cache como fonte de verdade: risco no `guardarParaRetentativa` — ver achado crítico (o Redis passa a ser, de fato, o único lugar onde o dado de retentativa existe).
- C-08 cache local sem TTL: **falso positivo do scanner** — código conforme.
- C-09 KEYS: limpo.
- C-10 maxmemory/eviction: limpo.
- C-11 exposição sem auth: limpo (há `requirepass` e `protected-mode yes`).
- C-12 cross-slot: não aplicável (instância standalone, não cluster).
- C-13 cache e estado durável na mesma instância: risco — a chave de retentativa é, na prática, estado que não pode ser perdido sem quebrar o fluxo de recarga, convivendo na mesma instância de cache com eviction `allkeys-lru` habilitada; se a instância pressionar memória, essa chave pode ser despejada antes do TTL de 5 minutos.
- C-14 comando O(N): não verificado (runtime).
- **C-15 campo de cartão em cache: ACHADO CRÍTICO — ver §4.**
- C-16 rede aberta 0.0.0.0/0 na porta Redis: limpo no IaC revisado (sem manifesto de rede no fixture).
- **C-17 bind em todas as interfaces com auth: revisão obrigatória — depende de NetworkPolicy/Service fora do escopo revisado; ver §4.**
- T-01 PAN/SAD em cache: **ACHADO CRÍTICO, mesmo item de C-15.**
- T-04 log/métrica com dado sensível: não verificado (config de APM/SLOWLOG fora do fixture); risco herdado do achado crítico se `MONITOR`/APM estiver ativo no cluster real.

## 6. Prioridade para a semana do pentest

1. **Bloqueante — remover CVV (e idealmente PAN) do Redis** (`guardarParaRetentativa`). É o achado que um scanner PCI/DLP contra dump ou `MONITOR` do cluster provavelmente vai pegar primeiro.
2. **Confirmar isolamento de rede do Redis** (`NetworkPolicy`, ausência de exposição externa, TLS cliente-servidor) antes de assumir que `bind 0.0.0.0` + `requirepass` é suficiente.
3. Levantar com o time o caminho de escrita/invalidação do `saldoLocal` e o comportamento de fallback quando o Redis está indisponível, para fechar a lacuna de C-01/degradação graciosa antes do pentest.

Nenhum arquivo de código ou de infraestrutura foi alterado nesta revisão — apenas leitura e este relatório.
