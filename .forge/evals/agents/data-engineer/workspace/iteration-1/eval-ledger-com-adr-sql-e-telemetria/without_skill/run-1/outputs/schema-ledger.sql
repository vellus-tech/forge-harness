-- Ledger de créditos do cartão transporte — banco lógico dedicado (ex.: ledger_db)
-- Segue .forge/rules/conventions/database-naming.md, data-config-sql.md, domain/money-as-cents.md,
-- domain/nbr-5891-rounding.md e domain/audit-immutability.md.

CREATE TABLE ledger_entries (
    ledger_entry_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL,
    card_id             UUID NOT NULL,
    entry_type          TEXT NOT NULL,
    amount_cents        BIGINT NOT NULL,
    balance_after_cents BIGINT NOT NULL,
    related_entry_id    UUID NULL REFERENCES ledger_entries (ledger_entry_id),
    idempotency_key     TEXT NOT NULL,
    occurred_at         TIMESTAMPTZ NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata            JSONB NULL,
    CONSTRAINT chk_ledger_entries_entry_type
        CHECK (entry_type IN ('credit_recarga', 'debit_embarque', 'estorno', 'ajuste')),
    CONSTRAINT chk_ledger_entries_amount_not_zero
        CHECK (amount_cents <> 0)
);

CREATE UNIQUE INDEX uq_ledger_entries_tenant_idempotency
    ON ledger_entries (tenant_id, idempotency_key);

CREATE INDEX idx_ledger_entries_tenant_card
    ON ledger_entries (tenant_id, card_id, occurred_at DESC);

-- Isolamento multi-tenant: RLS obrigatório (data-config-sql.md), além do EF Global Query
-- Filter que fica na camada de aplicação (fora do escopo deste DDL).
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_ledger_entries ON ledger_entries
    USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- Imutabilidade: função compartilhada (criar uma vez por banco) + trigger por tabela,
-- conforme o template obrigatório em .forge/rules/domain/audit-immutability.md.
CREATE OR REPLACE FUNCTION prevent_immutable_table_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION
        'Tabela imutável: operação % proibida em %.%',
        TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ledger_entries_immutable
    BEFORE UPDATE OR DELETE OR TRUNCATE ON ledger_entries
    FOR EACH STATEMENT EXECUTE FUNCTION prevent_immutable_table_modification();

REVOKE UPDATE, DELETE, TRUNCATE ON ledger_entries FROM app;

-- Estorno: NUNCA UPDATE/DELETE na entrada original de débito. Insere-se uma nova linha
-- entry_type = 'estorno', amount_cents positivo, related_entry_id = ledger_entry_id do débito
-- original. O saldo é recalculado a partir do encadeamento de balance_after_cents.

-- Saldo: leitura direta é "balance_after_cents da última entrada do card_id, ordenada por
-- occurred_at/created_at". Se o volume de leitura exigir O(1) em vez de varrer o ledger,
-- uma tabela de cache derivada (não autoritativa, atualizada na MESMA transação do INSERT
-- em ledger_entries) é aceitável — ela não substitui o ledger como fonte de verdade e não
-- entra no regime de imutabilidade acima.
