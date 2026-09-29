classificação: trabalho assíncrono + lookup de cópia derivada / estruturado / MongoDB, RabbitMQ, Redis
especialistas: `data-nosql`, `data-streaming`, `data-cache`

Sem bloco `CONFLITO`: recarga é transacional de negócio (dinheiro, saldo) sem ADR no baseline
(`.forge/product/current/adr/` vazio, só `.gitkeep`) escolhendo SQL para este domínio — pela
matriz do orquestrador e por `data-governance.md`/decisão H-01 (a), o dono do store é MongoDB. Não
há divergência entre rule e ADR aqui, então isto não é HITL: é um conjunto de antipatterns que o
fluxo atual viola contra as próprias rules do projeto, listados abaixo.

## Modo degradado (ferramenta `Agent` indisponível nesta run)

```text
PLANO DE ROTEAMENTO
classificação: trabalho assíncrono + lookup de cópia derivada / estruturado / MongoDB, RabbitMQ, Redis
especialistas: data-streaming, data-nosql, data-cache
pergunta por especialista:
  - data-streaming: relay outbox → RabbitMQ (confirms, mensagem persistente, idempotência do
    consumidor) para substituir o publish solto pós-commit em src/recarga/confirmar-recarga.ts:29
  - data-nosql: schema da coleção outbox e gravação do evento na MESMA transação Mongo que já
    grava recargas/saldos (linhas 13-26); ausência de campo/filtro de tenant
  - data-cache: política de invalidação ligada ao consumidor do evento (pós-commit, não ao handler
    síncrono) e correção da chave de cache (linhas 35-37): hash sem chave e sem namespace de tenant
checklist transversal: dado sensível (PCI DSS) — T-02, T-04; multi-tenant (isolamento por store)
```

Como a ferramenta `Agent` não está disponível nesta run, seguí o próprio "Modo degradado" do
`data-engineer.md`: não respondo no lugar do especialista por conta própria — a síntese abaixo é
construída lendo o protocolo, as rules e os catálogos de antipattern de cada especialista
(`.forge/skills/<especialista>-practices/` no template, leitura autorizada) e rodando os scripts
de detecção que cada um rodaria, exatamente como a delegação exige. O despacho que seria feito via
`Agent`, com o `subagent_type` e a pergunta de cada especialista, está registrado em
`outputs/despacho-simulado.md`.

## Detecção rodada (exigida em toda pergunta delegada)

```
$ bash .forge/scripts/check-data-governance.sh --path src/recarga
OK data-governance/universo — 1 arquivo(s) examinado(s) (src/recarga)
OK data-governance (0 .md, 1 código, no divergence)
```

`OK`/`universo-vazio` aqui é lido como **"não verificado"**, nunca como aprovação — o gate estático
não modela filtro de tenant em runtime nem decide se um campo cruzou a fronteira de tokenização; a
autoridade sobre PAN/PII é o `data-classification.json` do projeto, aplicado manualmente abaixo.

```
$ bash .forge/skills/data-streaming-practices/scripts/scan.sh --root src/recarga
FOUND RMQ-AP-08 [aviso] confirmar-recarga.ts:29 — publish sem publisher confirms
FOUND RMQ-AP-12 [aviso] confirmar-recarga.ts:29 — publish sem marcar mensagem persistente
(demais regras: OK, inclusive T-02 — o scanner não reconhece "numeroCartao"/"cpf" como PAN/SAD
por nome de campo; a autoridade aqui é o data-classification.json, ver checklist abaixo)

$ bash .forge/skills/data-nosql-practices/scripts/scan.sh --root src/recarga
OK em todas as regras estáticas (N-07 write concern majority: OK; escrita sem outbox — OBX-AP-01/
02/04 — não tem detector estático, é revisão obrigatória, feita abaixo)

$ bash .forge/skills/data-cache-practices/scripts/scan.sh --root src/recarga
OK em todas as regras estáticas (C-15 PAN em cache: OK, a chave não é o cartão; hash sem chave da
chave de cache — T-04 — não tem detector estático de "chave secreta ausente", é revisão manual)
```

## Síntese, por especialista de origem

### `data-nosql` — a transação e a coleção outbox

O problema central é **dual write fora de transação** (`confirmar-recarga.ts:15-33`): o `commit`
do MongoDB fecha em `sessao.withTransaction`, e o `canal.publish` roda **depois**, fora dela, numa
chamada separada — exatamente **OBX-AP-01** ("Dual write sem outbox": commit e publish no mesmo
handler, sem tabela outbox; evento perdido ou fantasma quando um dos dois falha) e o sintoma que a
Axis está vendo (pod cai entre o commit e o publish → evento some).

Correção: criar uma coleção `outbox` no banco `recarga` e gravar nela, **na mesma transação** que
já grava `recargas` e `saldos`, um documento com o evento a publicar (`recargaId`, `tipo:
"recarga.confirmada"`, `payload`, `tenant`, `criadoEm`, índice único em `recargaId` para
idempotência de escrita). Isso é **OBX-AP-04** evitado: gravar dentro do callback do
`withTransaction` sem publicar de dentro dele — o MongoDB repete o callback em
`TransientTransactionError`, então publicar ali dobra a mensagem; só o documento outbox entra na
transação, o `publish` real fica para o relay (`data-streaming`, abaixo). Um relay por **change
stream** sobre a coleção `outbox` (ou Debezium MongoDB) lê o documento já commitado e publica —
mensagem só sai depois de existir de verdade (resolve também **OBX-AP-02**, publicar antes do
commit, que não é o caso aqui, mas fecha o desenho). Expurgo periódico das linhas já publicadas
evita **OBX-AP-03**.

**Antipattern bloqueante separado, não relacionado ao outbox**: nem a escrita em `recargas` nem em
`saldos` tem `tenant` no filtro ou no documento, e nenhuma tem filtro de tenant na camada de
repositório. `data-transactional-nosql.md` exige campo `tenant` obrigatório em todo documento de
negócio e filtro de tenant obrigatório no repositório/interceptor (MongoDB não tem RLS nativo) —
"acesso a coleção multi-tenant sem esse filtro = conflito bloqueante". Como o enunciado diz "cada
operadora é um tenant", isto precisa entrar no desenho: `{ tenant: cmd.tenant, _id: cmd.recargaId
}` nos filtros e um índice composto começando por `tenant`.

### `data-streaming` — o relay e a confiabilidade do publish

Hoje o `canal.publish` de `confirmar-recarga.ts:29-33` roda solto, sem outbox atrás, e o scanner
confirma dois problemas de confiabilidade adicionais mesmo isolado do outbox: **RMQ-AP-08**
(publica sem publisher confirms — o broker pode perder a mensagem sem o produtor saber) e
**RMQ-AP-12** (não marca a mensagem como persistente — fila durável descarta mensagem transiente
numa recuperação do broker). Isso soma ao dual write: mesmo se o publish rodasse dentro do mesmo
commit lógico, ainda perderia mensagem em failover do broker sem confirms/persistência.

Desenho recomendado: um processo de relay separado do handler HTTP/comando (poller sobre a coleção
`outbox` do MongoDB, ou consumidor de change stream) que: (1) publica com `confirm channel`
(`waitForConfirms`/`publisherConfirms`) e só marca o documento outbox como publicado depois do
`ack` do broker; (2) publica com `persistent: true` numa fila/exchange durável; (3) usa o `_id` do
evento (ou `recargaId`) como chave de idempotência no envelope, para que o consumidor do lado
saldo/cache trate republicação (retry do relay) como no-op. Isso fecha o "sem perder evento" do
pedido: o evento nasce commitado (outbox) e só é dado como entregue com confirmação do broker.

### `data-cache` — invalidação e a chave

Dois problemas na parte de cache. Primeiro, **ordem/gatilho de invalidação**: hoje o `redis.del`
roda no mesmo handler síncrono, depois do commit e do publish — se o pod cair exatamente entre o
commit do Mongo e essa linha, o cache fica com o saldo velho até o TTL expirar (o "saldo velho por
alguns minutos" do enunciado). Correção (`references/antipatterns.md`, C-01): "em mudança dirigida
por evento, invalidar no consumidor do evento pós-commit" — mover o `redis.del` para dentro do
consumidor que lê o `recarga.confirmada` já publicado pelo relay do outbox (mesmo consumidor pode
tratar saldo e cache, ou um consumidor dedicado). Assim a invalidação está atrelada ao mesmo evento
garantidamente entregue do outbox, não a uma chamada síncrona que o crash do pod pode pular — e com
TTL explícito na entrada como rede de segurança (`data-cache.md` já exige TTL em toda escrita; o
código mostrado só faz `del`, então confirmar que o `set` do saldo em cache, se existir em outro
ponto do serviço, tem TTL).

Segundo, a **construção da chave**: `"saldo:" + sha256(cmd.cpf)`. É exatamente o antipattern
**T-04** do checklist transversal do orquestrador: "a chave usa token ou HMAC com chave secreta em
KMS (PCI DSS 3.5.1.1), nunca hash sem chave de PAN ou CPF" — CPF é um espaço pequeno e enumerável,
então SHA-256 puro (sem chave) é revertido por força bruta/dicionário; contamina slowlog e APM com
uma chave que reidentifica o titular. Trocar por `HMAC-SHA256(cpf, chave_secreta_KMS)` ou, melhor,
por um identificador não derivado de PII (id da conta/cartão tokenizado). E falta **namespace por
tenant** na chave — `data-cache.md` exige `tenant:{id}:<recurso>:<id>`; a chave correta fica algo
como `tenant:{cmd.tenant}:saldo:{hmac}`.

## Checklist transversal aplicado

- **T-02, PAN no evento de outbox** — `numeroCartao` está classificado `pan` com
  `tokenization_boundary: true` em `src/recarga/data-classification.json`. O evento publicado em
  `confirmar-recarga.ts:32` carrega `numeroCartao` em claro no payload JSON. Isso é exatamente o
  antipattern T-02 do catálogo de mensageria ("PAN ou SAD em payload de fila, tópico, DLQ ou evento
  de outbox... correção: evento carrega token; se o fluxo exige PAN, cifra no nível de aplicação e
  inventaria o broker como CDE") — o scanner não pegou porque o nome do campo (`numeroCartao`) não
  bate com o padrão heurístico dele, mas o `data-classification.json` do projeto é a autoridade
  (protocolo do orquestrador, item 5) e ele já declara este campo como PAN com fronteira de
  tokenização. `tokenization_boundary: true` significa que, em algum ponto anterior do fluxo, o
  serviço deveria estar recebendo/operando sobre um **token**, não o PAN — se este serviço de
  recarga já recebe o número de cartão bruto do lado de fora, ele está do lado errado da fronteira
  de tokenização (`pii-pci-classification.md`, anti-padrão "PAN armazenado ou circulando no domínio
  sem passar pela fronteira de tokenização"). O evento (e a própria escrita em `saldos` por
  `numeroCartao`) deve carregar o token do cartão, não o número; se a última porção precisa
  aparecer para UX, usar `masking: "primeiros 6 e últimos 4"` como o próprio mapa já declara.
- **T-04, hash sem chave na chave de cache** — coberto acima (`data-cache`): trocar SHA-256 puro de
  CPF por HMAC com chave em KMS ou por token, e não usar CPF cru para montar nome de recurso citável.
- **Multi-tenant** — cada operadora é tenant (enunciado explícito): falta `tenant` nas escritas e
  filtros Mongo (`data-nosql`, acima) e falta namespace de tenant na chave Redis (`data-cache`,
  acima). Ambos são anti-padrões bloqueantes pelas rules do projeto (`data-governance.md`,
  `data-transactional-nosql.md`, `data-cache.md`), não uma escolha em aberto.
- **Reversibilidade/operação** — a mudança (outbox + relay + invalidação por consumidor) é
  aditiva: nova coleção, novo processo de relay, sem quebrar o schema atual de `recargas`/`saldos`;
  pode ser introduzida com o publish direto convivendo temporariamente atrás de um flag até o relay
  estar validado, depois removido.

## Fora do escopo desta resposta

`data-relational` não foi acionado: não há ADR que escolha SQL para este domínio (baseline sem
ADRs além do `.gitkeep`), então pela matriz e por `data-governance.md`/H-01(a) o dono do store
segue sendo MongoDB.

Nenhum arquivo da árvore foi criado ou editado por esta resposta.
