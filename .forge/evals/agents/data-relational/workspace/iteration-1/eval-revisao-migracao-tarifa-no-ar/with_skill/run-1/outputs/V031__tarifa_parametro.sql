-- V031: parâmetros de tarifa por linha (fase "expand"; tabela nova, vazia — transação normal é segura aqui)
SET lock_timeout = '5s';

CREATE TABLE tarifa_parametro (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  linha_id bigint NOT NULL REFERENCES linha(id),
  valor_tarifa_em_centavos BIGINT NOT NULL,
  vigente_desde timestamptz NOT NULL
);

-- cobre o prefixo da FK (linha_id) e segue a convenção da casa: tenant_id na frente do índice composto
CREATE INDEX idx_tarifa_parametro_tenant_id_linha_id ON tarifa_parametro (tenant_id, linha_id);

ALTER TABLE tarifa_parametro ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarifa_parametro FORCE ROW LEVEL SECURITY;
CREATE POLICY tarifa_parametro_por_tenant ON tarifa_parametro
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
