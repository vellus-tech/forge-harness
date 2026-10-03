# Revisão da camada de dados NoSQL — services/cobranca

Escopo: `services/cobranca/src/repositorios/faturaRepositorio.ts`, `src/transferencia/transferirCredito.ts`,
`src/relatorios/fechamentoNoturno.ts`, `src/api/extratoHandler.ts`, `infra/mongod.conf` e `test/seed.ts`. Banco
MongoDB 7.0, replica set P-S-S, multi-tenant por operadora. Padrões de acesso (de `docs/contexto-cobranca.md`):
extrato de carteira no caminho quente do app (~1.800 req/s), listagem de faturas abertas no backoffice,
fechamento noturno às 02:00 em réplica secundária, transferência de crédito entre carteiras (centenas/hora, com
picos concorrentes no início do mês) e faturas que acumulam até milhares de eventos de cobrança.

Rules aplicadas: `.forge/rules/data/data-transactional-nosql.md` (tenant obrigatório, `majority`, índice
composto por tenant) e `.forge/rules/domain/money-as-cents.md` (dinheiro como inteiro). Detecção estática via
`.forge/scripts/check-data-governance.sh` (sem divergência de doc) e
`.forge/skills/data-nosql-practices/scripts/scan.sh` (achados abaixo). Cada item cita o id do catálogo
(`references/antipatterns.md`) quando aplicável.

## Achados que bloqueiam o PR

### 1. Saldo consolidado nunca é escrito na transferência — quebra o invariante de dinheiro (N-22, alto)
`src/transferencia/transferirCredito.ts:17-28`. A função lê o saldo em `saldos` para decidir
(`saldoOrigem.saldoCentavos < valorCentavos`) e a transação só grava em `lancamentos` — nenhum documento em
`saldos` (ou em `carteiras`, que é o que `extratoHandler` expõe como `saldoCentavos`) é atualizado. Duas
transferências concorrentes da mesma carteira leem o mesmo snapshot de saldo, as duas passam no teste de saldo
suficiente e as duas commitam, porque a transação MongoDB só detecta conflito de escrita no *mesmo* documento
(snapshot isolation) — exatamente o padrão de write skew descrito em N-22. Isso é agravado pelo pico de
concorrência relatado no contexto ("início do mês"). Correção: o saldo precisa morar num documento que toda
transferência escreve de forma condicional — `updateOne({ _id: origem, tenant, saldoCentavos: { $gte: valor } },
{ $inc: { saldoCentavos: -valor } })` seguido do incremento no destino, com `matchedCount === 0` abortando a
transação — em vez de ler um documento e escrever só em `lancamentos`. `lancamentos` continua existindo como
extrato/auditoria, mas deixa de ser a única fonte do saldo.

### 2. Filtro de tenant ausente em `buscarPorCliente` — conflito com a regra da casa
`src/repositorios/faturaRepositorio.ts:23-25`. A query `{ clienteId, status: "aberta" }` não inclui `tenant`.
`data-transactional-nosql.md` classifica acesso a coleção multi-tenant sem filtro de tenant como "conflito
bloqueante" (o MongoDB não tem RLS nativo; a defesa é o filtro no repositório). Como `clienteId` não é
necessariamente único entre tenants, um `clienteId` colidente de outra operadora vazaria faturas entre tenants.
Correção: `{ tenant, clienteId, status: "aberta" }`, e — se possível — um interceptor/wrapper de coleção que
recuse qualquer `find`/`update` sem `tenant` no filtro, para não depender de disciplina manual em cada método
novo.

### 3. Read concern `local` na transação de dinheiro (N-20, aviso — tratar como alto neste caso)
`src/transferencia/transferirCredito.ts:15`. `startTransaction({ readConcern: { level: "local" }, writeConcern:
{ w: "majority" } })`: `local` lê dado que a maioria ainda não confirmou; combinado com o achado 1, uma leitura
de saldo pode enxergar um valor que some num failover. A própria referência da skill trata isso como o mínimo
para transacional de negócio: `readConcern: "snapshot"` (não só `majority` no commit) e `readPreference:
"primary"` dentro da transação.

### 4. `Decimal128` em valor monetário (N-21) — viola `money-as-cents.md`
`src/repositorios/faturaRepositorio.ts:1,7,17`. O campo `valor` da fatura é `Decimal128`. A regra da casa exige
inteiro na menor unidade (`Int64`/`NumberLong` em centavos); `Decimal128` não tem tipo nativo em várias
linguagens e soma divergente é o sintoma típico entre serviços. Note que `transferirCredito.ts` e `extratoHandler.ts`
já usam `valorCentavos`/`saldoCentavos` como inteiro — a fatura é a única peça fora do padrão do próprio
serviço. Correção: `valorCentavos: Int64`, com moeda em campo próprio se necessário, e um validator
`$jsonSchema` (`bsonType: "long"`) na coleção para blindar contra regressão.

## Achados a corrigir antes do PR, mas não bloqueantes por si só

### 5. Write concern `w: 1` na criação de fatura (N-07, alto)
`src/repositorios/faturaRepositorio.ts:18`. Fatura é dado crítico; `w: 1` confirma com um único membro e a
escrita pode sumir num failover antes de replicar. Trocar para `writeConcern: { w: "majority" }` (ou herdar o
default do client, que já é `majority` desde o driver 5.0 — mas está sendo sobrescrito explicitamente aqui para
`1`, o que é pior que não setar nada).

### 6. `$lookup` no caminho quente do extrato, sem paginação no banco (N-04)
`src/api/extratoHandler.ts:8-15`. Endpoint chamado a ~1.800 req/s no pico faz `$lookup` de `lancamentos` por
carteira e só corta para os últimos 50 depois de trazer o array inteiro do join (`$slice` no `$project`, sem
`$sort` nem `$limit` no pipeline do `$lookup`). Duas consequências: (a) carteiras antigas com muitos
lançamentos pagam o custo de montar e transportar o array inteiro para cortar depois — o `$slice: -50` supõe
ordem de inserção, que o MongoDB não garante sem `$sort` explícito; (b) é exatamente o padrão que N-04 descreve
como "join em document store no caminho quente". Nesse volume, o desenho mais barato é manter os últimos N
lançamentos embutidos no próprio documento da carteira (bucket/cap, como em N-01) ou usar `$lookup` com
pipeline `[{ $match: ... }, { $sort: { em: -1 } }, { $limit: 50 }]` e índice `{ carteira: 1, em: -1 }` em
`lancamentos` — hoje não há nenhum índice declarado no código para essa consulta.

### 7. Commit da transação sem retry de `UnknownTransactionCommitResult` (N-23)
`src/transferencia/transferirCredito.ts:13-36`. A API usada é `startTransaction`/`commitTransaction` manual, e
só há `try/catch` ao redor — não há laço de retry para `TransientTransactionError` nem para
`UnknownTransactionCommitResult`. Um erro de rede ou eleição durante o commit deixa o resultado indeterminado:
o chamador vê exceção e pode reapresentar a transferência, mas o commit pode já ter sido aplicado no servidor
(duplicidade de crédito/débito). A própria referência da skill recomenda `session.withTransaction(fn, opções)`,
que o driver já cobre com os dois retries; adotar isso remove esta classe de bug sem código de retry manual.

## Achados de infraestrutura

### 8. `bindIp: 0.0.0.0` no `mongod.conf` (N-18)
`infra/mongod.conf:5`. Nenhum terceiro deveria ter rota de rede para o banco interno (regra de integração da
casa: gRPC/DB interno, REST ou fila para fora). `authorization: enabled` está presente, mas autenticação não
substitui restringir a interface — em rede mal segmentada, `0.0.0.0` expõe a porta a qualquer host que alcance
a máquina. Restringir a `bindIp` às interfaces privadas do replica set; se este `mongod.conf` for só um
exemplo de desenvolvimento local, mover para um arquivo separado e deixar claro que produção não usa este
valor (a revisão não teve acesso a manifesto de produção/Kubernetes para confirmar).

## Itens verificados sem achado (constam para auditoria)

- N-06 (chave de partição de baixa cardinalidade), N-08, N-09, N-10 (DynamoDB), N-11, N-13 (Cassandra),
  N-15, N-17 (Neo4j), N-19 (regra de rede aberta): sem ocorrência — não se aplicam a este serviço ou não têm
  artefato correspondente no escopo revisado.
- `$lookup` em `fechamentoNoturno.ts:11` (N-04) — aceitável: é o job noturno em réplica secundária, fora do
  caminho de requisição, exatamente a exceção que a própria skill documenta para `$lookup`.
- `writeConcern: { w: 1 }` em `test/seed.ts:12` (N-07) — aceitável: seed de teste de integração, dado
  descartável.

## Não coberto por esta revisão (precisa de acesso a runtime/produção)

- Cardinalidade real da shard key e presença de chunks/hot shard (`analyzeShardKey`, `sh.status()`) — não há
  shard key declarada no código revisado; se a coleção não é shardada isso não se aplica.
- Índices efetivamente criados no cluster (`$indexStats`) — o código não declara nenhuma criação de índice, nem
  para `{ tenant: 1, ... }` (exigido pela regra) nem para a consulta `lancamentos` por `carteira` do achado 6;
  isso é uma lacuna de evidência, não uma prova de ausência, mas nenhum script de setup encontrado no repositório
  cria índices.
- Confirmação de `mongod.conf` de produção (`rs.conf()` para conferir topologia P-S-S real e árbitro).

## Resumo para o PR

Dois achados são de correção obrigatória antes de abrir o PR por risco direto de dinheiro: o saldo nunca é
atualizado na transferência (write skew, item 1) e a falta de filtro de tenant em `buscarPorCliente` (item 2,
vazamento entre operadoras). `Decimal128` (item 4) e `w: 1` na fatura (item 5) violam regras da casa já
adotadas no resto do serviço. Os itens 3, 6, 7 e 8 valem corrigir na mesma leva por serem baratos e reduzirem
risco (read concern, índice + paginação do extrato, retry de commit, bind de rede) mas não bloqueiam sozinhos.
