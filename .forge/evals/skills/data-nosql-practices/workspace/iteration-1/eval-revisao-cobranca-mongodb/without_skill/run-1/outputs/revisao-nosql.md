# Revisão da camada de dados NoSQL — services/cobranca

## Sumário executivo

A camada de dados em MongoDB do serviço de cobrança tem dois problemas que classifico como **bloqueadores** antes do PR: uma consulta sem filtro de tenant que pode vazar faturas entre operadoras, e uma transação de transferência de crédito que nunca atualiza o saldo consolidado (o saldo em `saldos` fica desatualizado, além de haver uma janela de corrida em que duas transferências concorrentes podem ambas passar no cheque de "saldo insuficiente"). Há também um filtro de data incompleto no fechamento noturno que provavelmente arrasta faturas de dias futuros para o relatório de conciliação, um possível mismatch de tipo (`string` vs `ObjectId`) no handler de extrato — rota mais quente do serviço, ~1.800 req/s — e nenhum índice foi encontrado no repositório para nenhuma das consultas revisadas. Não há também `net.tls` configurado no `mongod.conf`, relevante dado o contexto de pagamentos. Recomendo tratar os itens 1, 2 e 3 abaixo antes de abrir o PR; os demais podem ir como follow-up, mas registrados explicitamente.

## Achados

### 1. Vazamento potencial entre tenants em `buscarPorCliente` (bloqueador)

Arquivo: `src/repositorios/faturaRepositorio.ts`

```ts
async buscarPorCliente(clienteId: string): Promise<Fatura[]> {
  return this.faturas.find({ clienteId, status: "aberta" }).toArray();
}
```

O serviço é multi-tenant (cada operadora de transporte é um tenant) e todo o resto do repositório — `criar`, `registrarEvento` — escopa por `tenant`. Esta consulta não recebe nem filtra por `tenant`. Se `clienteId` não for garantidamente único entre tenants (nada no schema garante isso — não há índice único composto), o backoffice de uma operadora pode ver faturas abertas de clientes de outra operadora. Mesmo que `clienteId` seja hoje sempre único globalmente, a consulta fica dependente de uma invariante não imposta pelo banco.

Recomendação: adicionar `tenant` como parâmetro obrigatório e ao filtro, e criar um índice composto `{ tenant: 1, clienteId: 1, status: 1 }` — hoje a consulta provavelmente faz COLLSCAN.

### 2. Transferência de crédito não atualiza o saldo consolidado e tem janela de corrida (bloqueador)

Arquivo: `src/transferencia/transferirCredito.ts`

A função lê `saldos.saldoCentavos` para checar se há saldo suficiente, mas só escreve em `lancamentos` (o razão/ledger) — nunca escreve de volta em `saldos`. Duas consequências:

- O documento consolidado em `saldos` fica permanentemente desatualizado após a primeira transferência: o `extratoHandler` (`GET /v1/carteiras/:id/extrato`) projeta justamente `saldoCentavos` desse documento, então o extrato mostrado ao usuário fica errado.
- Sem escrita em `saldos` dentro da transação, não há nenhum mecanismo de detecção de conflito do MongoDB sobre esse documento. O contexto do domínio diz que há "picos concorrentes no início do mês" no gestor de frota transferindo crédito. Duas transações concorrentes que debitam a mesma carteira de origem podem ambas ler o mesmo `saldoOrigem` (leitura feita com `readConcern: "local"`, antes de qualquer escrita conflitante), ambas passarem no `if (saldo < valor)` e ambas inserirem lançamentos negativos — resultando em saldo negativo não detectado (overdraft), sem que o MongoDB acuse write conflict.

Recomendação: mover a validação e a atualização do saldo para uma escrita atômica sobre o próprio documento de saldo, por exemplo `findOneAndUpdate({ tenant, carteira: origem, saldoCentavos: { $gte: valorCentavos } }, { $inc: { saldoCentavos: -valorCentavos } }, { session })` — se não encontrar documento, é saldo insuficiente — seguido do `$inc` equivalente no destino, mantendo os `lancamentos` como registro auditável. Isso também dá ao MongoDB algo para detectar como conflito de escrita entre transações concorrentes na mesma carteira.

Adicionalmente: a função não tem laço de retry para `TransientTransactionError` / `UnknownTransactionCommitResult`, que o driver do MongoDB recomenda explicitamente para transações multi-documento em replica set — sem isso, uma falha transitória de rede ou eleição de novo primary durante o commit derruba a transferência sem tentar de novo, exigindo o cliente retentar manualmente.

### 3. Filtro de data incompleto no fechamento noturno (bloqueador para o objetivo do job, não para o PR em si)

Arquivo: `src/relatorios/fechamentoNoturno.ts`

```ts
{ $match: { tenant, criadaEm: { $gte: dia } } }
```

Só há limite inferior. Isso não filtra "as faturas do dia" — filtra "todas as faturas a partir do dia informado, sem limite superior", incluindo dias posteriores já existentes na coleção no momento da consolidação. Como o objetivo declarado é gerar o arquivo de conciliação diário, isso deve estar puxando faturas de mais dias do que deveria.

Recomendação: `criadaEm: { $gte: dia, $lt: diaSeguinte }`, com `diaSeguinte` calculado a partir de `dia`.

### 4. Possível mismatch de tipo `_id` no handler de extrato (rota mais quente do serviço)

Arquivo: `src/api/extratoHandler.ts`

```ts
{ $match: { tenant, _id: req.params.id } }
```

`req.params.id` é sempre `string` (parâmetro de rota Express). Se `carteiras._id` for `ObjectId` (padrão do driver quando não especificado explicitamente, como é o caso em `Fatura._id?: ObjectId` no outro arquivo do mesmo serviço), essa comparação nunca casa e o endpoint sempre devolve `null` para qualquer carteira existente — silenciosamente, sem erro. Se `carteiras._id` for de fato uma string de propósito (ex.: um código de carteira), o código está correto e este item cai fora. Como não há o schema/definição da coleção `carteiras` disponível para confirmar, sinalizo como algo a confirmar antes do PR, dado que esta é a rota de maior volume do serviço (~1.800 req/s) — qualquer regressão aqui é visível imediatamente.

### 5. Ausência de índices para as consultas revisadas (alto risco de performance)

Não há, em nenhum arquivo do repositório revisado, definição de índices (nem migração, nem `createIndexes`, nem comentário apontando para onde isso é gerenciado). As consultas que precisam de índice, dado o padrão de acesso descrito em `docs/contexto-cobranca.md`:

- `carteiras`: índice em `{ tenant: 1, _id: 1 }` (ou o que for a chave real, ver item 4) para o `$match` do extrato — rota de pico 1.800 req/s.
- `lancamentos`: índice em `{ carteira: 1 }` (campo usado como `foreignField` no `$lookup` do extrato) — sem ele, cada chamada do extrato faz um COLLSCAN em `lancamentos` na rota mais quente do serviço.
- `faturas`: índice em `{ tenant: 1, clienteId: 1, status: 1 }` (busca do backoffice) e `{ tenant: 1, criadaEm: 1 }` (fechamento noturno).
- `saldos`: índice único em `{ tenant: 1, carteira: 1 }`, que também serve como base para a escrita atômica recomendada no item 2.

Recomendação: como não há uma camada de migração/bootstrap de índices visível no repositório, verificar onde isso é gerenciado (pode ser fora deste diretório, ex. infra do time de plataforma) e, se não existir, criar uma migração explícita antes do PR — índice criado em produção sob demanda, sem `background`/rolling apropriado, pode travar escritas em uma coleção com faturas de milhares de eventos.

### 6. Array `eventos` embutido sem limite, em faturas que podem chegar a milhares de eventos

Arquivo: `src/repositorios/faturaRepositorio.ts`, método `registrarEvento`

`docs/contexto-cobranca.md` afirma que "faturas contestadas chegam a milhares de eventos" e cada evento é feito com `$push` no array `eventos` embutido no documento da fatura. Um documento de fatura contestada pode crescer significativamente ao longo do tempo; cada `$push` além disso causa realocação de página no WiredTiger quando o documento ultrapassa o espaço alocado, e o documento inteiro é lido/transmitido em qualquer `find` sobre a fatura, incluindo o `buscarPorCliente` do backoffice, mesmo quando a UI não precisa do histórico completo. Ainda está longe do limite de 16MB por documento do MongoDB, mas é um padrão que vale revisitar antes de crescer mais.

Recomendação (não bloqueadora, mas registrar como dívida): considerar mover `eventos` para uma coleção própria (`eventos_fatura`, referenciando `faturaId`), com paginação no backoffice, especialmente para o caso de contestação. Não é urgente para o PR atual, mas deveria estar no radar antes que o volume cresça mais.

### 7. `writeConcern: { w: 1 }` na criação de fatura (risco de durabilidade)

Arquivo: `src/repositorios/faturaRepositorio.ts`, método `criar`

A criação de fatura usa `writeConcern: { w: 1 }` (confirma só no primary), enquanto a transferência de crédito corretamente usa `{ w: "majority" }`. Dado que o cluster é um replica set P-S-S gerenciado pelo time de plataforma, um failover do primary logo após o ack de `w: 1` e antes da replicação para as secondaries pode perder a fatura recém-criada (rollback no failover). Para dado financeiro (fatura), a inconsistência de padrão entre os dois arquivos do mesmo serviço chama atenção.

Recomendação: usar `writeConcern: { w: "majority" }` também em `criar` (e revisar `registrarEvento`, que hoje usa o writeConcern default da conexão — não fica explícito no código qual é).

### 8. `mongod.conf`: sem TLS configurado e bind em todas as interfaces

Arquivo: `services/cobranca/infra/mongod.conf`

```yaml
net:
  port: 27017
  bindIp: 0.0.0.0
```

`authorization: enabled` está presente, o que é bom, mas não há bloco `net.tls` — o tráfego entre a aplicação e o MongoDB parece estar em texto plano. Para um serviço que lida com faturas e carteiras de crédito, dado o contexto de PCI DSS já em uso em outras partes do grupo, recomendo confirmar com o time de plataforma se TLS é terminado em algum outro ponto (ex. malha de serviço/sidecar) — se não for, faltando aqui. `bindIp: 0.0.0.0` combinado com `authorization: enabled` não é necessariamente um problema se a rede já é isolada (VPC/security group), mas vale confirmar explicitamente que não há exposição além do necessário; não sinalizo como bloqueador porque pode já estar coberto por infraestrutura fora deste arquivo, mas registro para confirmação antes do PR.

Não há também `operationProfiling` configurado — dado que o extrato é a rota mais quente do serviço, ter o profiler habilitado com um `slowOpThresholdMs` ajudaria a detectar regressões de índice cedo.

## O que está correto e vale manter

- Uso de `Decimal128` para valores monetários em `Fatura.valor` (evita erro de ponto flutuante) — bom padrão, deveria se estender a `saldos`/`lancamentos`, que hoje usam `number` (centavos como inteiro, o que também é uma prática aceitável e evita ponto flutuante, então este item é apenas uma observação, não uma correção).
- `transferirCredito` já usa transação multi-documento com `writeConcern: { w: "majority" }` para os dois lançamentos — a estrutura da transação está certa, falta só incluir a atualização do saldo dentro dela (item 2).
- `fechamentoNoturno` corretamente usa `readPreference: "secondaryPreferred"`, adequado para um job de relatório que roda fora do horário de operação e não deve competir com tráfego do primary.
- `registrarEvento` já escopa a atualização por `{ _id: faturaId, tenant }`, respeitando isolamento de tenant (ao contrário de `buscarPorCliente`).

## Prioridade sugerida antes do PR

1. Item 1 (tenant em `buscarPorCliente`) — bloqueador.
2. Item 2 (saldo consolidado + corrida na transferência) — bloqueador.
3. Item 3 (filtro de data no fechamento) — bloqueador para a correção do relatório.
4. Item 4 (tipo do `_id` no extrato) — confirmar antes do PR, dado o volume da rota.
5. Itens 5, 7 e 8 — resolver ou registrar explicitamente como dívida técnica antes do merge.
6. Item 6 — registrar como dívida técnica, não bloqueia o PR atual.
