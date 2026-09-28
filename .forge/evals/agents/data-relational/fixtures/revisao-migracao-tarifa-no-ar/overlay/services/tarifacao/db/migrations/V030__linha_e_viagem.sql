-- V030: tabelas base do serviço tarifacao (já aplicada em produção)
SET lock_timeout = '5s';

CREATE TABLE linha (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  codigo text NOT NULL,
  operador_id bigint NOT NULL,
  criado_em timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE linha ENABLE ROW LEVEL SECURITY;
ALTER TABLE linha FORCE ROW LEVEL SECURITY;
CREATE POLICY linha_por_tenant ON linha USING (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE TABLE viagem (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  linha_id bigint NOT NULL REFERENCES linha(id),
  validador_id bigint NOT NULL,
  valor_cobrado_em_centavos bigint NOT NULL,
  ocorrida_em timestamptz NOT NULL
);
CREATE INDEX idx_viagem_tenant_id_linha_id ON viagem (tenant_id, linha_id);
ALTER TABLE viagem ENABLE ROW LEVEL SECURITY;
ALTER TABLE viagem FORCE ROW LEVEL SECURITY;
CREATE POLICY viagem_por_tenant ON viagem USING (tenant_id = current_setting('app.tenant_id')::uuid);
