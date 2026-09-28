# Validações de catraca — desenho de chaves, índices e consistência

> Escopo: `services/validacoes` (tabela DynamoDB `validacoes-catraca`, tabela `cartoes-transporte`).
> Domínio: chave-valor persistente (especialista `data-nosql`, referência `data-nosql-practices`).
> Não é o transacional de negócio da casa (`data-governance.md`: pedido/pagamento/ledger/cobrança
> em MongoDB) — é log operacional de passagem, roteamento correto para DynamoDB permanece.

## Padrões de acesso (inventário, `docs/padroes-de-acesso-validacoes.md`)

| # | Padrão | Volume | Latência |
|---|---|---|---|
| 1 | Escrita da validação | pico ~12.000/s (rush 6h–9h, 17h–19h), todas com a data do dia corrente | escrita confirmada ao validador |
| 2 | Histórico do cartão, últimos 30 dias, ordenado por data | ~3.000 req/s (maior parte da leitura) | leitura pontual, app do passageiro |
| 3 | Pendentes (`status = RECEBIDA`), por tenant | painel do operador | tolera alguns segundos de atraso |
| 4 | Cartão frequente | > 2.000 validações/ano no mesmo cartão | — |
| 5 | Multi-tenant | cada operadora é um tenant | — |

## Chave de partição da tabela base: `cartao_id` (não mais `data_validacao`)

O desenho em homologação particionava por `data_validacao` — um único valor de partição por dia.
Com o pico de ~12.000 escritas/s todas carimbadas com a data corrente, toda a escrita do rush caía
numa partição física só, muito acima do teto de 1.000 WCU/s por partição (catálogo
`data-nosql-practices`, **N-06 — chave de partição de baixa cardinalidade**; o `scan.sh` não pegou
essa ocorrência porque o nome do atributo não bate com a lista literal do detector estático —
achado de revisão manual, não do scanner).

`cartao_id` resolve as duas pontas ao mesmo tempo: é a mesma chave do padrão de leitura dominante
(padrão 2, histórico do cartão) — permite `Query` direto na tabela base, sem GSI — e tem
cardinalidade muito mais alta que a data (um cartão por passageiro), o que distribui o pico de
escrita entre partições. Um cartão super frequente (padrão 4, > 2.000/ano) fica bem abaixo do teto
de RCU/WCU de uma partição; não é o caso de partição quente.

Chave de ordenação: `validacao_sk = "<ISO-8601 do instante>#<validacao_id>"`. Mantém as validações
de um cartão ordenadas por data (padrão 2) e permite `Query` com `validacao_sk >= <corte de 30
dias>` — sem `Scan` (N-08). `validacao_id` no sufixo garante unicidade quando duas validações do
mesmo cartão caem no mesmo milissegundo (ex.: baldeação).

## Índice: GSI `por-tenant-status`, com write sharding

Padrão 3 (painel do operador, por tenant, status `RECEBIDA`) não é servido pela chave da tabela
base. Duas opções descartadas antes de chegar no desenho final:

- **GSI com `hash_key = status`** (desenho original em homologação): baixíssima cardinalidade —
  poucos valores de status possíveis — concentra a leitura/escrita do índice em pouquíssimas
  partições (N-06 de novo, agora na GSI; foi o que o `scan.sh` de fato apontou:
  `infra/dynamodb.tf:22`).
- **GSI com `hash_key = tenant`** (correção óbvia para N-06): melhor que `status` sozinho, mas o
  número de tenants (operadoras) é baixo frente aos ~12.000 writes/s, e toda validação nasce com
  `status = RECEBIDA` — ou seja, a GSI recebe essencialmente o mesmo pico de escrita da tabela
  base, só que concentrado em poucas partições por tenant. Ainda é uma chave de baixa cardinalidade
  frente ao volume.

Desenho adotado: `hash_key = tenant_status_shard`, no formato
`TENANT#<tenant>#STATUS#<status>#SHARD#<0..9>`, `range_key = em`. O sufixo de shard (`SHARD_COUNT
= 10` em `services/validacoes/src/handlers/registrarValidacao.ts`) é calculado por hash do
`validacao_id`, distribuindo a escrita do pico entre 10 partições por tenant em vez de uma. O
painel (`pendentes()` em `historicoCartao.ts`) faz `SHARD_COUNT` queries paralelas na GSI e junta o
resultado em memória — aceitável porque o padrão 3 tolera "alguns segundos de atraso" e o volume de
leitura do painel é muito menor que o de escrita.

`SHARD_COUNT = 10` é heurística de partida (marca `[Heurística]`, sem fonte primária para esse
número específico) — meça a distribuição real por tenant com CloudWatch Contributor Insights em
homologação (40M itens já existem lá) antes de fechar produção, e ajuste para cima se algum tenant
concentrar operação. Essa medição é runtime e está fora do alcance desta revisão estática.

Projeção da GSI: `INCLUDE` com os campos que o painel usa (`validacao_id`, `cartao_id`, `linha`,
`status`, `tenant`), não `ALL` — o desenho original projetava o item inteiro na GSI, dobrando o
custo de escrita sem necessidade (N-10, `scan.sh` achou em `infra/dynamodb.tf:24`).

## Consistência

- **Histórico do cartão (padrão 2):** `Query` na tabela base com `ConsistentRead: true`. É válido
  aqui porque é a tabela base, não uma GSI — o passageiro pode consultar o extrato logo após
  validar, e leitura forte na tabela base do DynamoDB não tem o problema de leitura eventual.
- **Painel do operador (padrão 3):** leitura eventual na GSI, sem `ConsistentRead`. O desenho em
  homologação passava `ConsistentRead: true` numa `QueryCommand` com `IndexName` de GSI — o
  DynamoDB **recusa** essa combinação (N-11, catálogo `data-nosql-practices`: "GSI só oferece
  leitura eventual"; `scan.sh` achou em `historicoCartao.ts:15`, na versão anterior). O painel
  tolera segundos de atraso, então a leitura eventual é a escolha certa, não uma concessão.

## Item que cresce — `cartoes-transporte.passagens` (N-09)

O handler original também fazia `UpdateCommand` com
`list_append(if_not_exists(passagens, :vazia), :nova)` em `cartoes-transporte`, mantendo a lista
de passagens do cartão dentro do próprio item — sem teto (N-09: item até 400 KB, um cartão com
milhares de passagens por ano eventualmente estoura o limite, e cada escrita reescreve o item
inteiro, ficando mais cara conforme ele cresce). Além do risco de tamanho, essa escrita duplicava
dado que já é consultável pela própria tabela `validacoes-catraca` via `Query` em `cartao_id`
(padrão 2). Removida em `registrarValidacao.ts`: `historicoCartao()` passa a ler o extrato
diretamente da tabela de validações, sem segunda fonte para manter sincronizada. A tabela
`cartoes-transporte` fica só com o cadastro do cartão (fora do escopo desta mudança).

## Backfill (`services/validacoes/scripts/backfill/reprocessarTarifas.ts`)

Mantido como está, conforme a tarefa. Usa `ScanCommand` com `Segment`/`TotalSegments` (Scan
paralelo) — o próprio catálogo `data-nosql-practices` documenta que "`Scan` numa migração offline é
o uso certo" (seção "O que o scanner não faz"): é job manual, fora do horário de operação, fora do
caminho da requisição. O `scan.sh` aponta essas linhas como `FOUND N-08` porque é detecção estática
por padrão de código (não distingue caminho de requisição de job offline) — julgamento manual
confirma que não é antipattern aqui.

Ponto de atenção fora do escopo pedido: se o backfill reclassifica `linha` de validações antigas
que hoje ficam sob a chave antiga (`data_validacao` + `validacao_id`), ele precisa ser adaptado
para a nova chave (`cartao_id` + `validacao_sk`) antes de rodar em produção, ou os 40M itens de
homologação precisam ser migrados para o novo esquema de chave — chave de partição é decisão de
migração no DynamoDB (não muda in-place). Como a tarefa autorizou deixar o script como está,
isso fica registrado aqui e não foi tocado.

## Antipatterns do catálogo endereçados

| Id | Onde estava | Correção |
|---|---|---|
| N-06 | `hash_key = "data_validacao"` (tabela) e `hash_key = "status"` (GSI) | `cartao_id` na tabela; `tenant_status_shard` com write sharding na GSI |
| N-08 | `ScanCommand` em `historicoCartao()` (caminho da requisição) | `QueryCommand` por `cartao_id` |
| N-09 | `list_append` sem teto em `cartoes-transporte.passagens` | removido; extrato lido da tabela de validações |
| N-10 | `projection_type = "ALL"` na GSI | `INCLUDE` com os campos que o painel usa |
| N-11 | `ConsistentRead: true` com `IndexName` de GSI | leitura eventual na GSI; `ConsistentRead` só na tabela base |
