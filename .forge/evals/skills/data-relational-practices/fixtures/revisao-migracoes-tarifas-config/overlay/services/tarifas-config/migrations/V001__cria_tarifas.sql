-- V001: aplicada em produção em 2026-08-10.
SET lock_timeout = '5s';

CREATE TABLE tarifas (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  linha_id bigint NOT NULL,
  valor_tarifa_em_centavos bigint NOT NULL,
  fator_tarifa numeric(6,4) NOT NULL DEFAULT 1.0000,
  taxa_desconto_percentual numeric(5,2) NOT NULL DEFAULT 0,
  vigente_desde timestamptz NOT NULL
);

CREATE INDEX idx_tarifas_tenant_linha ON tarifas (tenant_id, linha_id);

ALTER TABLE tarifas ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarifas FORCE ROW LEVEL SECURITY;
CREATE POLICY tarifas_por_tenant ON tarifas
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
