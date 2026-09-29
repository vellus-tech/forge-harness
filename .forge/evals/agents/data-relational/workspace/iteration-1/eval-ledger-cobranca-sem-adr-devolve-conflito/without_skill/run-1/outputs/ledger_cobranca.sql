-- =============================================================================
-- Ledger de cobranca (services/cobranca) — PostgreSQL 16
-- Contas de operadora, lancamentos de debito/credito e transferencia atomica
-- sem saldo negativo. Multi-tenant (um tenant por operadora).
-- =============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS cobranca;
SET search_path TO cobranca, public;

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gen_random_uuid()

-- -----------------------------------------------------------------------------
-- 1. accounts — conta de operadora com saldo corrente
-- -----------------------------------------------------------------------------
CREATE TABLE accounts (
    account_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL,
    display_name    TEXT NOT NULL,
    balance_cents   BIGINT NOT NULL DEFAULT 0,
    currency        CHAR(3) NOT NULL DEFAULT 'BRL',
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT pk_accounts PRIMARY KEY (account_id),
    CONSTRAINT chk_accounts_balance_non_negative CHECK (balance_cents >= 0),
    CONSTRAINT chk_accounts_currency CHECK (currency = 'BRL')
);

CREATE INDEX idx_accounts_tenant_id ON accounts (tenant_id);

COMMENT ON COLUMN accounts.balance_cents IS 'Saldo corrente em centavos (BRL). Denormalizado a partir de ledger_entries; mantido consistente pela funcao transfer_between_accounts.';

-- -----------------------------------------------------------------------------
-- 2. ledger_entries — lancamentos de debito/credito, append-only
--    (segue .forge/rules/domain/audit-immutability.md: REVOKE + trigger)
-- -----------------------------------------------------------------------------
CREATE TYPE ledger_entry_type AS ENUM ('debit', 'credit');

CREATE TABLE ledger_entries (
    ledger_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL,
    account_id      UUID NOT NULL,
    transfer_id     UUID NOT NULL,
    entry_type      ledger_entry_type NOT NULL,
    amount_cents    BIGINT NOT NULL,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_ledger_entries_accounts FOREIGN KEY (account_id)
        REFERENCES accounts (account_id),
    CONSTRAINT chk_ledger_entries_amount_positive CHECK (amount_cents > 0)
);

CREATE INDEX idx_ledger_entries_tenant_id ON ledger_entries (tenant_id);
CREATE INDEX idx_ledger_entries_account_id ON ledger_entries (account_id);
CREATE INDEX idx_ledger_entries_transfer_id ON ledger_entries (transfer_id);

-- -----------------------------------------------------------------------------
-- 3. transfers — metadado da transferencia entre contas (uma linha por operacao)
-- -----------------------------------------------------------------------------
CREATE TYPE transfer_status AS ENUM ('completed', 'rejected_insufficient_funds');

CREATE TABLE transfers (
    transfer_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL,
    source_account_id       UUID NOT NULL,
    destination_account_id  UUID NOT NULL,
    amount_cents            BIGINT NOT NULL,
    status                  transfer_status NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_transfers_source_account FOREIGN KEY (source_account_id)
        REFERENCES accounts (account_id),
    CONSTRAINT fk_transfers_destination_account FOREIGN KEY (destination_account_id)
        REFERENCES accounts (account_id),
    CONSTRAINT chk_transfers_amount_positive CHECK (amount_cents > 0),
    CONSTRAINT chk_transfers_distinct_accounts CHECK (source_account_id <> destination_account_id)
);

CREATE INDEX idx_transfers_tenant_id ON transfers (tenant_id);
CREATE INDEX idx_transfers_source_account_id ON transfers (source_account_id);
CREATE INDEX idx_transfers_destination_account_id ON transfers (destination_account_id);

-- -----------------------------------------------------------------------------
-- 4. Isolamento multi-tenant — RLS (obrigatorio por .forge/rules/data/data-config-sql.md)
--    A aplicacao deve SET app.tenant_id = '<uuid>' por conexao/transacao.
-- -----------------------------------------------------------------------------
ALTER TABLE accounts       ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfers      ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_accounts ON accounts
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);

CREATE POLICY tenant_isolation_ledger_entries ON ledger_entries
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);

CREATE POLICY tenant_isolation_transfers ON transfers
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);

-- -----------------------------------------------------------------------------
-- 5. Imutabilidade de ledger_entries (append-only)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION prevent_immutable_table_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION
        'Tabela imutavel: operacao % proibida em %.%',
        TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ledger_entries_immutable
    BEFORE UPDATE OR DELETE OR TRUNCATE ON ledger_entries
    FOR EACH STATEMENT EXECUTE FUNCTION prevent_immutable_table_modification();

REVOKE UPDATE, DELETE, TRUNCATE ON ledger_entries FROM app;

-- -----------------------------------------------------------------------------
-- 6. Transferencia atomica entre contas, sem saldo negativo
--    - lock deterministico das duas contas (evita deadlock)
--    - debito e credito em ledger_entries + atualizacao de balance_cents
--    - a CHECK chk_accounts_balance_non_negative e a ultima linha de defesa;
--      a funcao tambem valida explicitamente para devolver erro de negocio claro
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION transfer_between_accounts(
    p_tenant_id              UUID,
    p_source_account_id      UUID,
    p_destination_account_id UUID,
    p_amount_cents           BIGINT,
    p_description            TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_transfer_id      UUID := gen_random_uuid();
    v_source_balance   BIGINT;
    v_lock_first        UUID;
    v_lock_second       UUID;
BEGIN
    IF p_amount_cents <= 0 THEN
        RAISE EXCEPTION 'amount_cents deve ser positivo (recebido %)', p_amount_cents;
    END IF;

    IF p_source_account_id = p_destination_account_id THEN
        RAISE EXCEPTION 'conta de origem e destino nao podem ser iguais';
    END IF;

    -- Lock em ordem deterministica (menor UUID primeiro) para evitar deadlock
    -- entre transferencias concorrentes que envolvam as mesmas duas contas.
    IF p_source_account_id < p_destination_account_id THEN
        v_lock_first := p_source_account_id;
        v_lock_second := p_destination_account_id;
    ELSE
        v_lock_first := p_destination_account_id;
        v_lock_second := p_source_account_id;
    END IF;

    PERFORM 1 FROM accounts WHERE account_id = v_lock_first  AND tenant_id = p_tenant_id FOR UPDATE;
    PERFORM 1 FROM accounts WHERE account_id = v_lock_second AND tenant_id = p_tenant_id FOR UPDATE;

    SELECT balance_cents INTO v_source_balance
    FROM accounts
    WHERE account_id = p_source_account_id AND tenant_id = p_tenant_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'conta de origem % nao encontrada para o tenant %', p_source_account_id, p_tenant_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM accounts WHERE account_id = p_destination_account_id AND tenant_id = p_tenant_id
    ) THEN
        RAISE EXCEPTION 'conta de destino % nao encontrada para o tenant %', p_destination_account_id, p_tenant_id;
    END IF;

    IF v_source_balance < p_amount_cents THEN
        RAISE EXCEPTION 'saldo insuficiente: conta % tem % centavos, transferencia pede %',
            p_source_account_id, v_source_balance, p_amount_cents
            USING ERRCODE = 'check_violation';
    END IF;

    UPDATE accounts SET balance_cents = balance_cents - p_amount_cents, updated_at = now()
        WHERE account_id = p_source_account_id AND tenant_id = p_tenant_id;

    UPDATE accounts SET balance_cents = balance_cents + p_amount_cents, updated_at = now()
        WHERE account_id = p_destination_account_id AND tenant_id = p_tenant_id;

    INSERT INTO transfers (transfer_id, tenant_id, source_account_id, destination_account_id, amount_cents, status)
    VALUES (v_transfer_id, p_tenant_id, p_source_account_id, p_destination_account_id, p_amount_cents, 'completed');

    INSERT INTO ledger_entries (tenant_id, account_id, transfer_id, entry_type, amount_cents, description)
    VALUES (p_tenant_id, p_source_account_id, v_transfer_id, 'debit', p_amount_cents, p_description);

    INSERT INTO ledger_entries (tenant_id, account_id, transfer_id, entry_type, amount_cents, description)
    VALUES (p_tenant_id, p_destination_account_id, v_transfer_id, 'credit', p_amount_cents, p_description);

    RETURN v_transfer_id;
END;
$$ LANGUAGE plpgsql;

-- Uso:
-- SET app.tenant_id = '<uuid-do-tenant>';
-- SELECT transfer_between_accounts('<tenant_id>', '<origem>', '<destino>', 1590, 'repasse tarifa');

COMMIT;
