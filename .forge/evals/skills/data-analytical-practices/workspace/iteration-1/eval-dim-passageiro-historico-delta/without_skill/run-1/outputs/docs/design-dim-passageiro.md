# Desenho: dim_passageiro (histórico) e particionamento de fct_recargas

## Contexto

Análise de migração de categoria tarifária precisa saber, para cada passageiro, qual era a
`categoria_tarifaria` (e demais atributos de cadastro) em cada ponto no tempo, cruzada com as
recargas realizadas em `gold.fct_recargas`. Plataforma: Databricks/Unity Catalog, tabelas Delta.
`gold.fct_recargas` tem hoje ~300 GB e cresce ~8 GB/mês; `gold.dim_passageiro` cobre ~4 milhões de
passageiros. O time de BI da parceira replica os marts no BigQuery (`bi_parceiro`), onde
`fct_recargas` fica em ~40 GB, e pediu o mesmo particionamento diário.

## Dimensão com histórico (SCD tipo 2)

`analytics/snapshots/snap_passageiro.sql` usa `dbt snapshot` com `strategy='check'` sobre
`stg_passageiros`, comparando `nome, email, telefone, cpf, bairro, categoria_tarifaria`. O dbt
gera automaticamente `dbt_valid_from` / `dbt_valid_to` por `id_passageiro`, o que dá o histórico
necessário para reconstruir "qual categoria tarifária valia na data da recarga X" com um join por
intervalo:

```sql
select r.id_recarga, r.data_recarga, p.categoria_tarifaria
from fct_recargas r
join snap_passageiro p
  on r.id_passageiro = p.id_passageiro
 and r.data_recarga >= p.dbt_valid_from
 and (r.data_recarga < p.dbt_valid_to or p.dbt_valid_to is null)
```

`dim_passageiro` (o mart consumido por BI) deve ser construído sobre esse snapshot — não sobre
`stg_passageiros` diretamente — para não perder o histórico. `invalidate_hard_deletes=True` fecha
a versão vigente quando o cadastro some da origem (ex.: exclusão de conta), preservando a
integridade da série histórica.

### LGPD: histórico de PII x direito de eliminação

Um risco real desse desenho: o snapshot SCD2 retém `nome`, `email`, `telefone`, `cpf` em todas as
versões históricas indefinidamente. Pedido de eliminação de titular (prazo de 15 dias, via DPO)
não é atendido apenas pelo `invalidate_hard_deletes` — isso fecha a versão vigente, mas as linhas
antigas continuam com PII em texto claro. Recomendação: manter o snapshot como está para os
atributos analíticos (`categoria_tarifaria`, `bairro`), mas tratar um pedido de eliminação como uma
rotina de expurgo separada, executada fora do `dbt snapshot` normal, que faz `UPDATE` nas linhas
históricas de `snapshots.snap_passageiro` para o `id_passageiro` afetado, anonimizando
`nome/email/telefone/cpf` (ex.: hash irreversível ou `NULL`) preservando `categoria_tarifaria` e as
datas de validade — Delta suporta `UPDATE` diretamente na tabela do snapshot. Essa rotina não foi
implementada aqui (fora do escopo dos dois arquivos pedidos); fica registrada como pendência de
design a decidir com o DPO antes de produção.

## Particionamento de fct_recargas (Databricks + espelho no BigQuery)

`analytics/ddl/gold_fct_recargas.sql` particiona por `data_recarga` (`PARTITIONED BY
(data_recarga)`), diário, porque:

- O padrão de consulta de BI filtra por `data_recarga` e `cod_canal` — particionar pela coluna
  mais seletiva do filtro (`data_recarga`) reduz scan sem exigir reescrita de partição a cada
  atualização de canal.
- Com ~300 GB e ~8 GB/mês de crescimento, partição diária mantém um volume de dados por partição
  saudável (não fragmenta em partições vazias nem concentra tudo em poucas partições grandes).
- `TBLPROPERTIES` com `autoOptimize.optimizeWrite`/`autoCompact` mitiga o problema clássico de
  "muitos arquivos pequenos" em fato particionado por dia com escrita incremental frequente.
- Para o filtro adicional por `cod_canal` dentro de cada partição diária, a recomendação é
  `OPTIMIZE gold.fct_recargas ZORDER BY (cod_canal)` como job de manutenção periódico — não altera
  o esquema de particionamento, só a organização física dos arquivos dentro de cada partição.

### Espelho no BigQuery (`bi_parceiro`)

Para manter o mesmo particionamento diário que o time de BI da parceira pediu:

```sql
CREATE TABLE bi_parceiro.fct_recargas (
  id_recarga     INT64 NOT NULL,
  id_passageiro  INT64 NOT NULL,
  cod_canal      STRING NOT NULL,
  valor_centavos INT64 NOT NULL,
  data_recarga   DATE NOT NULL
)
PARTITION BY data_recarga
CLUSTER BY cod_canal
OPTIONS (
  description = 'Fato de recargas confirmadas replicado do Databricks; particionado por dia (data_recarga).'
);
```

- `PARTITION BY data_recarga` funciona direto porque a coluna já é `DATE` (sem precisar de
  `DATE(timestamp_col)`), o que dá o mesmo particionamento diário 1:1 com o Delta.
- `CLUSTER BY cod_canal` no BigQuery cumpre o mesmo papel do `ZORDER BY cod_canal` no Databricks:
  organiza fisicamente os dados dentro de cada partição diária pelo segundo filtro mais comum.
- Atenção a médio prazo: particionamento diário no BigQuery tem limite de 4000 partições por
  tabela (dataset por padrão, sem expiração); com ~40 GB hoje e crescimento proporcional ao
  Databricks, isso dá margem de anos, mas vale registrar como item a revisitar (partição por
  mês, ou `require_partition_filter=true`, se o volume de partições crescer além do previsto).
- A réplica para o BigQuery precisa do mesmo cuidado de LGPD descrito acima caso replique também
  `dim_passageiro`: o expurgo de PII deve valer nos dois lados, não só no Databricks.
