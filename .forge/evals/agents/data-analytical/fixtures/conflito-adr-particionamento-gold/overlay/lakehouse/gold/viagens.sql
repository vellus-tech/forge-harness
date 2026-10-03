-- gold.viagens (Delta no Databricks), segue o ADR-0004.
CREATE TABLE IF NOT EXISTS gold.viagens (
  viagem_id        STRING    NOT NULL,
  tenant_id        STRING    NOT NULL,
  operadora_id     STRING    NOT NULL,
  tarifa_centavos  BIGINT    NOT NULL,
  validado_em      TIMESTAMP NOT NULL,
  dt               DATE      NOT NULL
)
USING DELTA
PARTITIONED BY (dt);
