# Revisão analítica — projeto dbt de bilhetagem (`analytics/`)

Escopo revisado: `analytics/models/staging`, `analytics/models/intermediate`, `analytics/models/marts`, `analytics/snapshots`, `analytics/ddl`, `analytics/dbt_project.yml`. Revisão de diagnóstico, sem alteração de arquivos.

## Resumo executivo

O projeto tem a separação de camadas correta (staging → intermediate → marts) mas duas falhas graves comprometem a confiabilidade dos números de receita e viagens antes do PR: (1) `fct_viagens` ignora a camada de staging e lê a source diretamente, e (2) nenhum modelo incremental tem `unique_key`, o que abre risco real de duplicação de viagens e receita em reprocessamentos. Há ainda dois modelos intermediários (`int_viagens_diarias`, `int_validacoes`) que não são consumidos por nada — código morto que custa manutenção sem entregar valor — e uma tabela gold fora do dbt (`ddl/gold_receita_linha.sql`) que recalcula receita por linha com lógica própria, criando uma segunda fonte de verdade para a mesma métrica. Zero testes (`not_null`/`unique`/`relationships`) em um pipeline financeiro é o gap mais crítico de qualidade. Recomendo resolver os itens P0 antes do PR; P1/P2 podem virar itens de acompanhamento pós-merge.

## Achados por severidade

### P0 — bloqueadores (risco de dado errado em produção)

1. **`fct_viagens` bypassa a staging e lê a source direto** (`models/marts/fct_viagens.sql:9`, `select ... from {{ source('bilhetagem','viagens') }} v`). Toda a modelagem em camadas existe para centralizar limpeza/tipagem em um lugar só; aqui o fato mais importante do projeto (receita por viagem) ignora `stg_viagens` e duplica a lógica de conversão de `valor_tarifa_centavos`. Qualquer regra futura de limpeza aplicada em staging (dedupe, filtro de registros inválidos, cast) não chega ao fato. Corrigir para `from {{ ref('stg_viagens') }}`.

2. **Nenhum modelo incremental declara `unique_key`** (`int_viagens_diarias.sql`, `int_validacoes.sql`). `int_viagens_diarias` filtra por `where ts_embarque > (select max(ts_embarque) from {{ this }})` sem chave única — se o job rodar duas vezes para a mesma janela (retry, backfill, reprocessamento de late-arriving data), o modelo duplica viagens. Em um pipeline de bilhetagem isso é duplicação de receita, não um detalhe cosmético. Todo `materialized='incremental'` aqui precisa de `unique_key` e de uma estratégia (`merge`/`delete+insert`) explícita — não depender do default do adapter.

3. **`gold_receita_linha.sql` recalcula receita por linha fora do dbt**, com filtro de data hardcoded (`dt='2026-09-27'`, `date '2026-09-27'`) dentro de um arquivo de DDL. Isso mistura definição de schema com carga de dado (uma execução manual de um dia específico, não reexecutável), fica fora do grafo de lineage do dbt (sem testes, sem docs, sem `dbt build`), e duplica a métrica de receita que também nasce em `fct_viagens` — com filtros e grão diferentes (linha+dia vs. viagem individual). Duas fontes de verdade para receita divergem cedo ou tarde. Decidir: ou essa agregação vira um mart dbt (`fct_receita_linha_dia`) que lê de `fct_viagens`, ou a tabela gold documenta explicitamente por que existe fora do dbt e como se reconcilia com o mart.

4. **Zero testes de schema no projeto inteiro.** Não há nenhum `schema.yml` com `not_null`/`unique` para chaves primárias (`id_viagem`, `cod_linha`), nem `relationships` entre `fct_viagens.cod_linha` e `dim_linha.cod_linha`, nem `accepted_values` para `modal`. Para um pipeline que alimenta receita de bilhetagem, isso é o maior risco de qualidade do PR — um erro de join ou um `cod_linha` órfão não quebra o build, só aparece no dashboard.

### P1 — antes do próximo ciclo

5. **Dois modelos intermediários órfãos.** `int_viagens_diarias` e `int_validacoes` não são referenciados por nenhum outro modelo (busquei `ref('int_viagens_diarias')` e `ref('int_validacoes')` no projeto — nenhuma ocorrência). São custo de manutenção e de execução sem consumidor. Ou removem do PR, ou conectam a um mart antes de mergear — código morto revisado em PR tende a ficar morto para sempre.

6. **`int_viagens_diarias` tem nome de agregação diária mas não agrega nada** — é `select` linha a linha com `cast(ts_embarque as date)`, sem `group by`. O nome promete uma granularidade (dia) que o SQL não entrega; quem for consumir esse modelo vai assumir que já está agregado por dia e vai contar viagem errado. Renomear (`int_viagens_com_data`, por exemplo) ou implementar a agregação de fato.

7. **`int_validacoes` usa `incremental_strategy='microbatch'`** com `event_time`, `batch_size='day'`, `lookback=3`, `begin='2026-01-01'`. Estratégia correta em espírito (lookback cobre late-arriving data), mas (a) sem `unique_key` a estratégia microbatch ainda pode duplicar dependendo do adapter, e (b) `microbatch` exige suporte do adapter (nem todo destino do lakehouse aceita) — o projeto não expõe `profiles.yml`/target, então não dá para confirmar compatibilidade. Confirmar o adapter de destino antes do PR.

8. **`_sources.yml` sem freshness e sem `loaded_at_field`.** Fonte de bilhetagem (`raw_bilhetagem.viagens/linhas/validacoes`) não declara SLA de atualização nem coluna de carga — sem isso, `dbt source freshness` não funciona e atraso de ingestão passa despercebido até o dashboard estar errado.

9. **Materialização por padrão inadequada para o fato.** `dbt_project.yml` define `marts: +materialized: table` para toda a pasta, o que se aplica tanto a `dim_linha` (dimensão pequena, ok) quanto a `fct_viagens` (fato de viagens, potencialmente grande e crescente). Rebuild completo a cada run não escala e não tem paralelo com a estratégia incremental já usada em `int_viagens_diarias`. Definir materialização por modelo (`fct_viagens` incremental com `unique_key` e partição por data) em vez de herdar o default da pasta.

### P2 — observações menores

10. **Conversão de centavos para reais em `fct_viagens`**: `cast(v.valor_tarifa_centavos as numeric(12,2)) / 100`. O `cast` para `numeric(12,2)` acontece antes da divisão — como `valor_tarifa_centavos` já é inteiro, o cast não perde nada aqui, mas o padrão mais seguro e mais legível é dividir primeiro e então arredondar (`cast(v.valor_tarifa_centavos / 100.0 as numeric(12,2))`), deixando explícito que o arredondamento final é o que importa. Se essa conversão for reutilizada em outro modelo, considerar centralizá-la em staging ou em uma macro.

11. **Partição do `gold_receita_linha` como `STRING` (`dt STRING`)** enquanto `silver_embarques` usa partição nativa do Iceberg por `days(ts_embarque)`. Duas estratégias de particionamento diferentes para tabelas vizinhas do mesmo lakehouse — a coluna `dt` como string impede pruning por funções de data e é fonte comum de bug de comparação de string vs. data. Padronizar em cima de Iceberg hidden partitioning (como já feito em silver) ou, se Hive/parquet mesmo, usar `DATE` em vez de `STRING`.

12. **Snapshot `snap_linhas` aponta para `ref('stg_linhas')`**, não para a source bruta. Funciona, mas acopla o histórico do snapshot a qualquer mudança futura na transformação de staging (troca de coluna em `stg_linhas` quebra ou distorce o snapshot). Prática mais robusta é snapshotar a source diretamente (ou um staging que só faz rename/cast, sem lógica de negócio) — hoje `stg_linhas` é só rename/cast então o risco é baixo, mas vale documentar a decisão.

13. **`dbt_project.yml` não define `on_schema_change`** para os modelos incrementais — mudança de schema na source (nova coluna em `validacoes`/`viagens`) vai quebrar o incremental de forma pouco clara em vez de falhar com mensagem explícita ou evoluir automaticamente.

## O que mudar antes do PR (checklist)

- [ ] `fct_viagens`: trocar `source('bilhetagem','viagens')` por `ref('stg_viagens')`.
- [ ] Adicionar `unique_key` (e estratégia explícita `merge`/`delete+insert`) a todo modelo `materialized='incremental'`.
- [ ] Decidir o destino de `gold_receita_linha.sql`: virar mart dbt ou documentar a reconciliação com `fct_viagens`; parametrizar a data em vez de hardcode.
- [ ] Criar `schema.yml` com `not_null`/`unique` em `id_viagem` e `cod_linha`, e `relationships` entre `fct_viagens` e `dim_linha`.
- [ ] Remover ou conectar `int_viagens_diarias` e `int_validacoes`.
- [ ] Renomear ou implementar de fato a agregação diária em `int_viagens_diarias`.
- [ ] Adicionar freshness em `_sources.yml`.
- [ ] Sobrescrever materialização de `fct_viagens` para incremental (não herdar `+materialized: table` da pasta marts).

## Observação de escopo

Não encontrei `profiles.yml` nem indicação do adapter/warehouse alvo no diretório revisado — os pontos 7 e 11 dependem dessa confirmação para saber se `microbatch` e o formato de partição do gold são de fato compatíveis com o destino em produção.
