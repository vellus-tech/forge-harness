# Recarga: perda de evento e saldo desatualizado — diagnóstico e redesenho

## Diagnóstico do fluxo atual

`confirmarRecarga` faz três operações em sequência, com garantias diferentes:

1. Escreve `status=CONFIRMADA` e incrementa `saldoCentavos` no MongoDB dentro de uma transação (`withTransaction`) — atômico e durável.
2. Publica `recarga.confirmada` no RabbitMQ **depois** do commit — se o pod morrer entre o commit e o `canal.publish`, o evento nunca é publicado. Não há outbox, não há retry, não há registro de que a publicação falhou.
3. Invalida a chave `saldo:<sha256(cpf)>` no Redis — só executa se o passo 2 não lançou exceção antes; e mesmo que a invalidação rode, ela depende do consumidor do evento eventualmente repovoar o cache lido por outros serviços. Enquanto isso, qualquer leitor que cacheava o saldo antigo com TTL longo continua servindo valor desatualizado até o TTL expirar.

Dois defeitos adicionais, independentes da perda de evento:

- **Chave de cache sem tenant.** `numeroCartao` e `cpf` não são únicos por operadora — o mesmo CPF pode ter cartões em operadoras (tenants) diferentes. A chave `saldo:<hash(cpf)>` colide entre tenants: confirmar recarga no tenant A pode invalidar (ou, pior, ser lida como) o saldo cacheado do tenant B para a mesma pessoa.
- **PAN em texto claro cruzando fronteira de confiança.** `data-classification.json` marca `numeroCartao` como `classification: pan`, `tokenization_boundary: true`, com máscara obrigatória (`primeiros 6 e últimos 4`). O evento publicado no RabbitMQ carrega `numeroCartao` completo — RabbitMQ é uma fronteira (múltiplos consumidores, retenção em disco, possível replicação) e a política de classificação exige mascaramento/tokenização antes de atravessar essa fronteira. Isso é uma violação PCI DSS (armazenamento/transmissão de PAN em claro fora do boundary de tokenização), não só um detalhe de design.

## Redesenho proposto

### 1. Outbox transacional (elimina a perda de evento)

Em vez de publicar no RabbitMQ fora da transação, grava-se um documento de evento na mesma transação Mongo, na coleção `outbox`:

```ts
await db.collection("outbox").insertOne(
  {
    _id: eventoId,               // idempotency key
    tenant: cmd.tenant,
    tipo: "recarga.confirmada",
    payload: { recargaId: cmd.recargaId, numeroCartaoMascarado: mascarar(cmd.numeroCartao), cpf: cmd.cpf, valorCentavos: cmd.valorCentavos },
    criadoEm: new Date(),
    publicadoEm: null,
  },
  { session: sessao },
);
```

Como o `outbox.insertOne` está na mesma transação que a atualização de `recargas`/`saldos`, ou tudo comita ou nada comita — não existe mais janela em que o saldo é atualizado sem o evento ser registrado.

Um **relay separado** (processo próprio, não o handler HTTP/comando) lê `outbox` com `publicadoEm: null` — via polling com índice em `(tenant, publicadoEm, criadoEm)` ou via Change Streams do Mongo — publica no RabbitMQ e marca `publicadoEm`. Esse relay é o único ponto que fala com o RabbitMQ para esse fluxo; se ele cair no meio, retoma de onde parou porque o estado "publicado ou não" vive no Mongo, não na memória do processo. Entrega passa a ser *at-least-once*: o consumidor do evento precisa ser idempotente (ver item 3).

### 2. Invalidação de cache: TTL curto como rede de segurança, não só invalidação event-driven

Mesmo com outbox, a invalidação de cache não deve depender só do evento chegar a tempo (o consumidor pode estar atrasado, RabbitMQ pode estar particionado do lado do consumidor). Duas mudanças:

- Definir TTL curto (ex.: 30–60s) em toda escrita de `saldo:*` no Redis, para que mesmo se a invalidação por evento se perder ou atrasar, o valor errado nunca fica servido por "alguns minutos" — o pior caso vira o TTL configurado.
- A invalidação (ou melhor, a repopulação) do cache deve ser feita pelo **consumidor do evento** `recarga.confirmada` (fora do `confirmarRecarga`), não inline no comando. Isso desacopla a consistência do cache da disponibilidade do Redis no momento da confirmação — hoje, se o `redis.del` falhar, a recarga já foi confirmada e publicada (ou pior, nem publicada, no bug atual) e a falha do Redis não tem retry.

### 3. Idempotência do consumidor (outbox é at-least-once)

O relay pode publicar o mesmo evento mais de uma vez (crash entre `channel.publish` confirmado e `updateOne(publicadoEm)`). O consumidor que invalida/repopula o cache deve deduplicar por `eventoId` (ex.: `SET NX` de `processed:<eventoId>` com TTL, ou tabela de eventos processados) antes de agir, e deve tratar entrega fora de ordem: se guardar um "último saldo conhecido", comparar por `recargaId`/timestamp/versão antes de sobrescrever, para que um evento atrasado não sobreponha um estado mais novo.

### 4. Chave de cache com tenant

Trocar `saldo:<sha256(cpf)>` por `saldo:<tenant>:<sha256(cpf)>:<numeroCartaoMascarado ou id do cartão>` (ou, melhor, usar `numeroCartaoId`/id interno do cartão em vez do CPF, já que um CPF pode ter mais de um cartão dentro do mesmo tenant). No mínimo, tenant precisa entrar na chave para eliminar a colisão entre operadoras.

### 5. PAN mascarado antes de cruzar a fronteira

Nunca publicar `numeroCartao` completo no RabbitMQ (nem gravar em claro no outbox, já que o outbox tende a ter retenção/leitura por operação). Aplicar a máscara definida em `data-classification.json` (`primeiros 6 e últimos 4`) no momento de montar o payload do evento, antes de persistir no outbox:

```ts
function mascararPan(pan: string): string {
  return pan.slice(0, 6) + "*".repeat(Math.max(0, pan.length - 10)) + pan.slice(-4);
}
```

Se algum consumidor downstream precisar do PAN completo para uma operação legítima (ex.: emissor), ele deve resolvê-lo por token/id de cartão contra o serviço dono do dado (boundary de tokenização), nunca recebê-lo propagado por evento.

## Resumo do desenho final

```
confirmarRecarga (uma transação Mongo):
  1. update recargas.status = CONFIRMADA
  2. update saldos.saldoCentavos += valor
  3. insert outbox { tenant, tipo, payload (PAN mascarado), publicadoEm: null }
  → commit atômico: os três ou nenhum

relay-outbox (processo separado, poll/change-stream):
  4. lê outbox pendente por tenant
  5. publica no RabbitMQ (routing key inclui tenant)
  6. marca publicadoEm — idempotente por reprocessamento (upsert com filtro publicadoEm: null)

consumidor-saldo-cache (subscriber do RabbitMQ):
  7. dedup por eventoId
  8. invalida/repopula saldo:<tenant>:<chave-do-cartão> no Redis
  9. TTL curto em toda escrita de saldo:* como rede de segurança independente do evento
```

Isso resolve: (a) evento nunca mais se perde por crash do pod, porque a durabilidade do evento está na mesma transação do estado de negócio; (b) saldo errado servido por "alguns minutos" vira, no pior caso, o TTL curto configurado, não uma dependência indefinida de um evento que pode ter se perdido; (c) isolamento entre tenants no cache; (d) PAN nunca atravessa o RabbitMQ em claro, alinhado com `data-classification.json` e com PCI DSS.
