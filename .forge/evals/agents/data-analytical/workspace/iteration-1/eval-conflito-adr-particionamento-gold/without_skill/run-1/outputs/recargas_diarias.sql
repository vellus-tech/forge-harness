-- gold.recargas_diarias (Delta no Databricks).
-- Entrega em cumprimento literal do ADR-0004 (toda tabela gold particionada por `dt`).
-- ATENÇÃO: ver outputs/CONFLITO-ADR-0004.md antes de aplicar em produção — há uma tensão entre
-- o ADR-0004 e o volume/grão desta tabela específica que ainda não foi decidida por um humano.
CREATE TABLE IF NOT EXISTS gold.recargas_diarias (
  dt                    DATE      NOT NULL,
  tenant_id             STRING    NOT NULL,
  operadora_id          STRING    NOT NULL,
  qtd_recargas          BIGINT    NOT NULL,
  valor_total_centavos  BIGINT    NOT NULL,
  atualizado_em         TIMESTAMP NOT NULL
)
USING DELTA
PARTITIONED BY (dt)
COMMENT 'Agregado diário de recargas por operadora (grão: dt x operadora_id), consumido pelo dashboard de recargas por operadora. Segue ADR-0004. Conflito de particionamento em aberto — ver outputs/CONFLITO-ADR-0004.md.';
