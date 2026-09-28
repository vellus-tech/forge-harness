SET lock_timeout = '5s';

CREATE SCHEMA IF NOT EXISTS recargas_pedido;

CREATE TABLE recargas_pedido.pedidos (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  canal_id bigint NOT NULL REFERENCES recargas_param.canais (id),
  status text NOT NULL DEFAULT 'criado'
    CHECK (status IN ('criado', 'aguardando_pagamento', 'pago', 'concluido', 'cancelado', 'falhou')),
  valor_total_em_centavos bigint NOT NULL CHECK (valor_total_em_centavos >= 0),
  criado_em timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE recargas_pedido.pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE recargas_pedido.pedidos FORCE ROW LEVEL SECURITY;
CREATE POLICY pedidos_por_tenant ON recargas_pedido.pedidos
  USING (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE TABLE recargas_pedido.itens_pedido (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  pedido_id bigint NOT NULL REFERENCES recargas_pedido.pedidos (id) ON DELETE CASCADE,
  produto_id bigint NOT NULL REFERENCES recargas_param.produtos (id),
  quantidade integer NOT NULL CHECK (quantidade > 0),
  valor_unitario_em_centavos bigint NOT NULL CHECK (valor_unitario_em_centavos >= 0),
  UNIQUE (pedido_id, produto_id)
);

ALTER TABLE recargas_pedido.itens_pedido ENABLE ROW LEVEL SECURITY;
ALTER TABLE recargas_pedido.itens_pedido FORCE ROW LEVEL SECURITY;
CREATE POLICY itens_pedido_por_tenant ON recargas_pedido.itens_pedido
  USING (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE TABLE recargas_pedido.pagamentos (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  pedido_id bigint NOT NULL REFERENCES recargas_pedido.pedidos (id),
  valor_em_centavos bigint NOT NULL CHECK (valor_em_centavos >= 0),
  status text NOT NULL DEFAULT 'pendente'
    CHECK (status IN ('pendente', 'autorizado', 'capturado', 'negado', 'estornado')),
  gateway text NOT NULL,
  nsu text,
  data_pagamento timestamptz,
  criado_em timestamptz NOT NULL DEFAULT now(),
  UNIQUE (gateway, nsu)
);

ALTER TABLE recargas_pedido.pagamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE recargas_pedido.pagamentos FORCE ROW LEVEL SECURITY;
CREATE POLICY pagamentos_por_tenant ON recargas_pedido.pagamentos
  USING (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE INDEX idx_pedidos_tenant_status ON recargas_pedido.pedidos (tenant_id, status);
CREATE INDEX idx_pagamentos_pedido ON recargas_pedido.pagamentos (pedido_id);
