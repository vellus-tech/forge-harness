# Revisão de cache — services/cobranca / CobrancaCache.java

**Especialista:** `data-cache` (consultivo — recomendação abaixo, não altera código).
**Escopo revisado:** `services/cobranca/src/main/java/br/com/exemplo/cobranca/CobrancaCache.java` (único arquivo do domínio de cache no path), com contexto de `docs/servicos/cobranca.md` (Java 21/Spring Boot 3, multi-tenant por operadora, fonte da verdade PostgreSQL, Redis + Caffeine como cache de leitura, 12 réplicas em Kubernetes).

## Veredito resumido

Não suba como está. Há um problema de LGPD real (CPF em claro na chave) e um problema de consistência real (cache local sem TTL em frota de 12 réplicas, sem invalidação cross-instância) — ambos bloqueantes pela `rules/data/data-cache.md`. Há ainda um ponto que preciso que você confirme antes de eu fechar o veredito sobre desenho (ver "Confirmar antes de subir").

## Achados (ordem de severidade)

### 1. [Alto — LGPD] CPF em texto claro na chave do cache — T-04
`CobrancaCache.java:21` — `String chave = "tenant:" + tenant + ":titular:" + cpf;`

O CPF (dado pessoal) compõe a chave literal, usada tanto no Redis (`redis.opsForValue()`) quanto no Caffeine local. Chave é visível em `SLOWLOG`, `MONITOR`, e em qualquer APM/tracing que capture argumentos de comando Redis — ela vaza para observabilidade e potencialmente para o SIEM, fora do controle de mascaramento que a aplicação faz no valor. Isso é o antipattern **T-04** do catálogo (`.forge/skills/data-cache-practices/references/antipatterns.md`): "PAN, CPF ou e-mail em chave de cache, visíveis no SLOWLOG, no MONITOR, no APM ou no SIEM."

Correção recomendada: trocar CPF por um identificador substituto na chave — o id interno do titular (se existir e não for reversível trivialmente) ou HMAC com chave gerida em KMS (fora do código e do cache). Hash simples sem chave **não resolve**: o espaço de CPF (~10⁹ combinações válidas de dígito verificador) é revertido por força bruta em segundos, então não serve como pseudonimização para LGPD.

Detecção: revisão manual (o `scan.sh` não tem detector estático para isso — chave é montada em runtime, conforme a skill documenta). Evidência: [Interp.] base do catálogo; [1F] PCI DSS 4.0.1 3.5.1.1 aplica o mesmo raciocínio a PAN — aqui é CPF, mas o mecanismo de vazamento por observabilidade é idêntico.

### 2. [Alto — Consistência] Cache local (Caffeine) sem TTL em frota de 12 réplicas — C-08
`CobrancaCache.java:11-14`:
```java
private final Cache<String, Titular> titulares = Caffeine.newBuilder()
        .maximumSize(50_000)
        .recordStats()
        .build();
```
Só há `maximumSize` (eviction por tamanho/LRU) — nenhum `expireAfterWrite`/`expireAfterAccess`. Isso é o antipattern **C-08** ("cache local em frota sem TTL"), confirmado pelo `scan.sh` (achado estático, ver seção de comandos executados).

Isso é diretamente o cenário de consistência que o catálogo descreve: "instâncias respondendo valores diferentes para a mesma chave; origem sobrecarregada quando a frota escala." Com 12 réplicas e `guardarTitular` escrevendo no Redis + **apenas na própria instância local** do Caffeine, uma atualização feita numa réplica não invalida o Caffeine das outras 11. Enquanto a chave não sofrer eviction por tamanho (até 50.000 entradas por réplica), ela permanece servindo o valor antigo indefinidamente nessas réplicas — não há mecanismo de expiração nem de invalidação por evento entre instâncias. Para um serviço de cobrança, isso é um risco concreto de servir cadastro ou fatura desatualizados (ex.: titular que teve dado corrigido, ou cache que não reflete correção recente) para requisições atendidas por réplicas diferentes.

Correção recomendada: `expireAfterWrite` com TTL curto (o Caffeine é L1 de curtíssimo prazo à frente do Redis, que já é L2) — algo como 30–120s conforme a tolerância a dado velho definida pelo time; se a coerência entre réplicas for crítica para cobrança, considerar invalidação por evento (pub/sub Redis ou mensageria — desenho de invalidação por evento é do `data-streaming`, fora do meu escopo) em vez de depender só de TTL curto.

### 3. [Médio] Escrita no Redis sem TTL — C-02
`CobrancaCache.java:22` — `redis.opsForValue().set(chave, titular.toJson());`

Confirmado pelo `scan.sh` (C-02: `opsForValue().set(` sem `Duration`/janela de expiração na chamada). A `data-cache.md` exige TTL explícito em toda entrada — sem ele, a memória do Redis cresce até a eviction e o dado velho é servido indefinidamente até isso acontecer. Some ao achado #2: hoje **nenhuma das duas camadas** (Redis nem Caffeine) expira sozinha.

Correção: `redis.opsForValue().set(chave, titular.toJson(), Duration.ofMinutes(N))`, com jitter se o carregamento for em lote (não é o caso aparente aqui, é leitura sob demanda).

### 4. [Médio — LGPD, não verificado por ferramenta] PII sem mascaramento no valor cacheado
O valor armazenado é `titular.toJson()` — meu escopo não incluiu `Titular.java` (não está no path revisado), então não vi os campos exatos. Mas dado o nome (`titular`, cadastro de passe mensal) e o uso de CPF como parte da identidade, é razoável presumir que o JSON carrega CPF e possivelmente outros dados pessoais em claro. A `data-cache.md` proíbe "PII sem mascaramento" como classe de dado em cache.

Isso **não foi verificado** pelo gate de governança: rodei `check-data-governance.sh --path services/cobranca` e ele retornou `FAIL data-governance/universo-vazio` — o verificador só lê `.go`, `.kt`, `.ts`, `.rego`, `.py` e `.md`, e este projeto é Java, então não examinou nada. Isso é "não verificado", não "aprovado" — a linha não vira conflito nem aprovação por si.

Recomendação: antes de subir, confirmar os campos de `Titular` contra `data-classification.schema.json` do projeto (se existir) ou classificá-los agora; qualquer campo `pii`/`sensitive` armazenado em claro no cache deve ter mascaramento na borda de emissão (log/trace) e, se possível, minimizar o que entra no valor cacheado (ex.: não cachear CPF completo no payload se o consumidor só precisa de confirmação/último-4).

### 5. [Baixo — ponto limpo] Namespace multi-tenant presente
A chave inclui `tenant:{tenant}:...`, que é o isolamento obrigatório pela `data-governance.md`/`data-cache.md` para cache. Isso está correto e não precisa de mudança.

## Confirmar antes de subir (não é achado fechado — depende de contexto que não tenho)

`guardarTitular` escreve em Redis e no Caffeine local, mas **não escreve em PostgreSQL** neste arquivo. `docs/servicos/cobranca.md` diz que PostgreSQL é a fonte da verdade e Redis/Caffeine são cache de leitura — então presumo que a escrita em Postgres acontece em outra camada, chamada antes ou depois deste método (fora do escopo que revisei). Preciso que confirmem isso: **se `guardarTitular` for o único lugar onde o titular é persistido** (sem escrita correspondente em Postgres no mesmo fluxo), o desenho vira **C-07 — cache como fonte da verdade**, que é `CONFLITO` bloqueante com a `data-governance.md` (Redis nunca é fonte de verdade), e a escolha do store durável não é deste especialista — volta ao orquestrador/matriz (`data-nosql` ou `data-relational`). Se a escrita em Postgres já existe em outro lugar e este método só popula o cache logo depois (write-through), então não há C-07, mas nesse caso a ordem importa: o cache deve ser escrito **depois** da confirmação do commit em Postgres (C-01), e não vi como isso é garantido a partir deste arquivo isoladamente.

## Comandos executados (protocolo do agente `data-cache`)

```
bash .forge/scripts/check-data-governance.sh --path services/cobranca
→ FAIL data-governance/universo-vazio (0 arquivos examinados — extensão .java fora do universo do verificador; "não verificado", não "aprovado")

bash .forge/skills/data-cache-practices/scripts/scan.sh --root services/cobranca
→ FOUND C-02 [aviso] — CobrancaCache.java:22 (set sem TTL)
→ FOUND C-08 [aviso] — CobrancaCache.java:11 (Caffeine sem expiração)
→ OK C-09, C-10, C-11, C-15, C-16, C-17 — nenhuma ocorrência
```

## Fora do meu escopo (para o especialista certo, se aplicável)

- Desenho de invalidação por evento entre as 12 réplicas, se a decisão for ir por esse caminho em vez de TTL curto: `data-streaming`.
- Escolha do store durável, caso o achado "confirmar antes de subir" (C-07) se confirme: `data-nosql` ou `data-relational` pela matriz do `data-engineer`.
