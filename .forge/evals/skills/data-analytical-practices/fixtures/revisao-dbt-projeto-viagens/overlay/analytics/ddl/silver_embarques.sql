-- Tabela Iceberg (silver) no catálogo do lakehouse
CREATE TABLE lake.silver.embarques (
    id_viagem      BIGINT,
    cod_linha      STRING,
    ts_embarque    TIMESTAMP,
    valor_tarifa_centavos BIGINT
)
USING iceberg
PARTITIONED BY (days(ts_embarque));
