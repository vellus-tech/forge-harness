SET lock_timeout = '5s';
SET statement_timeout = '15min';
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
CREATE TABLE cobranca (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  valor_em_centavos bigint NOT NULL,
  taxa_juros numeric(9,6) NOT NULL,
  criado_em timestamptz NOT NULL DEFAULT now(),
  payload jsonb,
  sigla varchar(3)
);
ALTER TABLE cobranca ENABLE ROW LEVEL SECURITY;
CREATE INDEX CONCURRENTLY idx_cobranca_tenant ON cobranca (tenant_id, id);
ALTER TABLE pedido ADD COLUMN canal VARCHAR(20), ALGORITHM=INPLACE, LOCK=NONE;
