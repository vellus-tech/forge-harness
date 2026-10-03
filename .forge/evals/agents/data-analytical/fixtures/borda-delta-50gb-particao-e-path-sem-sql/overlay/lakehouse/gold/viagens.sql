-- gold.viagens: viagens validadas nos ônibus (Delta no Databricks).
-- Tamanho atual ~50 GB; cresce ~2 GB por mês.
CREATE TABLE IF NOT EXISTS gold.viagens (
  viagem_id        STRING    NOT NULL,
  tenant_id        STRING    NOT NULL,
  operadora_id     STRING    NOT NULL,
  linha_id         STRING    NOT NULL,
  cartao_sk        BIGINT    NOT NULL,
  tarifa_centavos  BIGINT    NOT NULL,
  validado_em      TIMESTAMP NOT NULL
)
USING DELTA
PARTITIONED BY (operadora_id, linha_id);
