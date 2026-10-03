SET lock_timeout = '5s';

CREATE SCHEMA IF NOT EXISTS recargas_param;

CREATE TABLE recargas_param.produtos (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  codigo text NOT NULL,
  valor_face_minimo_em_centavos bigint NOT NULL,
  valor_face_maximo_em_centavos bigint NOT NULL,
  UNIQUE (tenant_id, codigo)
);

ALTER TABLE recargas_param.produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE recargas_param.produtos FORCE ROW LEVEL SECURITY;
CREATE POLICY produtos_por_tenant ON recargas_param.produtos
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
