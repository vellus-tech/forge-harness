-- gold.viagens: viagens validadas nos ônibus (Delta no Databricks).
-- Tamanho atual ~50 GB; cresce ~2 GB por mês.
--
-- ATENÇÃO (ver outputs/ANALISE.md): particionar por dia neste volume/crescimento
-- tende a gerar muitas partições pequenas (small-file problem), especialmente
-- combinado com operadora_id. Implementado conforme solicitado, com a ressalva
-- registrada para decisão humana.
CREATE TABLE IF NOT EXISTS gold.viagens (
  viagem_id        STRING    NOT NULL,
  tenant_id        STRING    NOT NULL,
  operadora_id     STRING    NOT NULL,
  linha_id         STRING    NOT NULL,
  cartao_sk        BIGINT    NOT NULL,
  tarifa_centavos  BIGINT    NOT NULL,
  validado_em      TIMESTAMP NOT NULL,
  data_validacao   DATE GENERATED ALWAYS AS (CAST(validado_em AS DATE))
)
USING DELTA
PARTITIONED BY (data_validacao, operadora_id);
