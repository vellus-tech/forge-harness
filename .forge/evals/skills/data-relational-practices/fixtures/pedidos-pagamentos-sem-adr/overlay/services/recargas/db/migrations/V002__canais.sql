SET lock_timeout = '5s';

CREATE TABLE recargas_param.canais (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  nome text NOT NULL,
  limite_diario_em_centavos bigint NOT NULL
);

ALTER TABLE recargas_param.canais ENABLE ROW LEVEL SECURITY;
ALTER TABLE recargas_param.canais FORCE ROW LEVEL SECURITY;
CREATE POLICY canais_por_tenant ON recargas_param.canais
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
