-- Tabela gold de receita por linha e dia (Spark/Hive metastore)
CREATE TABLE lake.gold.receita_linha (
    cod_linha      STRING,
    receita_centavos BIGINT,
    qtd_viagens    BIGINT,
    dt             STRING
)
USING parquet
PARTITIONED BY (dt);

INSERT OVERWRITE TABLE lake.gold.receita_linha PARTITION (dt='2026-09-27')
SELECT cod_linha, sum(valor_tarifa_centavos), count(*), '2026-09-27'
FROM lake.silver.embarques
WHERE cast(ts_embarque as date) = date '2026-09-27'
GROUP BY cod_linha;
