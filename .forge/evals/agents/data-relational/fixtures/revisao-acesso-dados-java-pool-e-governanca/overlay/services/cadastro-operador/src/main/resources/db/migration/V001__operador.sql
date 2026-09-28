SET lock_timeout = '5s';

CREATE TABLE operador (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  nome text NOT NULL,
  cpf text NOT NULL,
  frota_id bigint,
  criado_em timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_operador_tenant_id_id ON operador (tenant_id, id);
ALTER TABLE operador ENABLE ROW LEVEL SECURITY;
ALTER TABLE operador FORCE ROW LEVEL SECURITY;
CREATE POLICY operador_por_tenant ON operador USING (tenant_id = current_setting('app.tenant_id')::uuid);
