-- DDL comum, sem marcador forge:sensitive-field e sem chamada de log com
-- dado sensível na mesma linha — prova de não-regressão/falso-positivo para
-- a extensão REQ-06 (.sql em CODE_EXTS).
CREATE TABLE account (
    id uuid PRIMARY KEY,
    tenant_id uuid NOT NULL,
    balance_cents bigint NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_account_tenant ON account (tenant_id);
