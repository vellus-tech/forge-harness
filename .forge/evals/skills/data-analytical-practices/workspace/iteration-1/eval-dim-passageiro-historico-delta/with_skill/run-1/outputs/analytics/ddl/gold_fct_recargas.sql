-- fato de recargas no Databricks (Delta). Grão: uma linha por recarga confirmada.
-- ~300 GB hoje, crescendo ~8 GB/mês (docs/contexto-lakehouse.md) — abaixo do limiar de
-- 1 TB do Databricks para particionar; por isso liquid clustering (não PARTITIONED BY,
-- que seria A-06/A-05 aqui) nas colunas que o BI já filtra: data_recarga e cod_canal.
-- Revisitar quando a tabela aproximar de 1 TB (detalhe em docs/design-dim-passageiro.md).
CREATE TABLE gold.fct_recargas (
    id_recarga        BIGINT,
    id_passageiro     BIGINT,
    cod_canal         STRING,
    valor_centavos    BIGINT,
    data_recarga      DATE
)
USING DELTA
CLUSTER BY (data_recarga, cod_canal);
