CREATE TABLE recargas (
  id UUID PRIMARY KEY,
  cartao_id TEXT NOT NULL,
  valor_centavos INTEGER NOT NULL CHECK (valor_centavos > 0),
  status TEXT NOT NULL,
  criada_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_recargas_cartao_id ON recargas (cartao_id, criada_em DESC);
