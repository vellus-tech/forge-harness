-- rascunho: fato de recargas no Databricks (Delta)
CREATE TABLE gold.fct_recargas (
    id_recarga        BIGINT,
    id_passageiro     BIGINT,
    cod_canal         STRING,
    valor_centavos    BIGINT,
    data_recarga      DATE
)
USING DELTA
PARTITIONED BY (data_recarga);
