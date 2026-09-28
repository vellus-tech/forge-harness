ALTER TABLE recargas ADD COLUMN idempotency_key UUID NOT NULL DEFAULT gen_random_uuid();
CREATE UNIQUE INDEX idx_recargas_idempotency_key ON recargas (idempotency_key);
