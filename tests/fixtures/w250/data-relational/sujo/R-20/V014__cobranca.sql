CREATE TABLE cobranca (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  valor_em_centavos bigint NOT NULL
);
