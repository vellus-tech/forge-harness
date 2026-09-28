# Transcript — eval dim-passageiro-historico-delta (without_skill, run-1)

## Passos executados

1. Inspecionei o fixture já preparado em `work/`: `analytics/snapshots/snap_passageiro.sql`
   (rascunho de snapshot dbt), `analytics/ddl/gold_fct_recargas.sql` (rascunho de DDL Delta) e
   `docs/contexto-lakehouse.md` (contexto da plataforma), além de
   `analytics/models/marts/fct_recargas.sql` (mart que consome `stg_recargas`) para entender o
   grão já assumido pelo pipeline.

2. Li `docs/contexto-lakehouse.md`: plataforma Databricks/Unity Catalog com Delta;
   `gold.fct_recargas` em ~300 GB crescendo ~8 GB/mês, filtrado por BI em `data_recarga` e
   `cod_canal`; `gold.dim_passageiro` com ~4 milhões de passageiros; réplica no BigQuery
   (`bi_parceiro`, ~40 GB) mantida pelo time de BI da parceira; pedidos de eliminação LGPD com
   prazo de 15 dias via DPO. Também confirmei em `CLAUDE.md` do projeto as convenções: money como
   inteiro em centavos, identificadores em inglês, docs em PT-BR — já seguidas pelo rascunho.

3. **`analytics/snapshots/snap_passageiro.sql`**: o rascunho já usava `dbt snapshot` com
   `strategy='check'`, `unique_key='id_passageiro'`, `check_cols` cobrindo os atributos relevantes
   (incluindo `categoria_tarifaria`, essencial para a análise de migração) e
   `invalidate_hard_deletes=True`. Estruturalmente correto para gerar SCD2
   (`dbt_valid_from`/`dbt_valid_to`). Ajustei formatação/comentários e documentei explicitamente o
   ponto que o rascunho não resolvia: `invalidate_hard_deletes` fecha a versão vigente quando o
   registro some da origem, mas **não apaga PII histórica** — um pedido de eliminação LGPD (15
   dias) exige uma rotina de expurgo separada (UPDATE nas linhas históricas do snapshot), fora do
   `dbt snapshot` normal. Registrei essa lacuna como decisão de design pendente em
   `docs/design-dim-passageiro.md`, sem implementar a rotina (fora do escopo dos dois arquivos
   pedidos).

4. **`analytics/ddl/gold_fct_recargas.sql`**: mantive `PARTITIONED BY (data_recarga)` (particionamento
   diário), que já casava com o padrão de filtro de BI e com o pedido do time de BI da parceira de
   espelhar o mesmo particionamento no BigQuery. Adicionei: `NOT NULL` nas colunas de grão/chaves,
   `COMMENT` por coluna e na tabela (documentação embutida), e `TBLPROPERTIES` com
   `autoOptimize.optimizeWrite`/`autoCompact` para mitigar o problema de arquivos pequenos em uma
   tabela particionada por dia com ~8 GB/mês de escrita incremental. Deixei como comentário a
   recomendação de manutenção `OPTIMIZE ... ZORDER BY (cod_canal)` (job periódico, fora da DDL de
   criação) para o segundo filtro mais comum de BI.

5. **`docs/design-dim-passageiro.md`**: escrevi o desenho da dimensão com histórico (SCD2 via
   snapshot dbt, exemplo de join por intervalo `dbt_valid_from`/`dbt_valid_to` para responder "qual
   categoria tarifária valia na data da recarga"), a justificativa do particionamento diário de
   `fct_recargas` no Databricks, e a seção espelhando o mesmo particionamento diário no BigQuery
   (`PARTITION BY data_recarga` direto, já que a coluna é `DATE`; `CLUSTER BY cod_canal` como
   equivalente ao `ZORDER`). Incluí uma ressalva sobre o limite de 4000 partições por tabela no
   BigQuery (particionamento diário sem expiração) como item a revisitar, não bloqueante hoje. A
   seção de LGPD documenta o trade-off entre reter histórico de PII e o direito de eliminação, e
   propõe a rotina de expurgo como decisão a validar com o DPO antes de produção.

## Decisões e trade-offs

- Mantive particionamento estático diário (`PARTITIONED BY`) em vez de liquid clustering
  (`CLUSTER BY`) no Databricks porque o requisito explícito do time de BI da parceira é espelhar o
  **mesmo particionamento diário** no BigQuery — usar liquid clustering no Databricks quebraria
  essa correspondência 1:1 de forma direta.
- Não implementei a rotina de expurgo de PII (LGPD) nos arquivos pedidos — é uma peça de
  infraestrutura adicional (job/macro separado), não parte do snapshot nem da DDL da fato. Deixei
  registrada como pendência de design explícita, para decisão humana/DPO.
- Não alterei `analytics/models/marts/fct_recargas.sql` nem `stg_recargas`/`stg_passageiros`: não
  foram pedidos pela tarefa e já estão consistentes com os dois arquivos ajustados.

## Comandos executados

```
date +%s > .../run-1/.t0
mkdir -p .../run-1/work
bash .../fixtures/dim-passageiro-historico-delta/setup.sh .../run-1/work
find .../run-1/work -path '*/analytics/*' -o -iname 'contexto-lakehouse*'
```

Nenhum comando de teste, build, git ou execução externa foi rodado (fora do escopo permitido para
este caso de eval).
