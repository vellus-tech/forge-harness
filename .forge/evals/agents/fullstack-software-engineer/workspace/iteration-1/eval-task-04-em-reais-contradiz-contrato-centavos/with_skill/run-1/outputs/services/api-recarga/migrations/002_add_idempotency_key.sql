ALTER TABLE recargas
  ADD COLUMN idempotency_key UUID;

-- Backfill de linhas anteriores a esta feature (TASK-01/02 já tinham gerado histórico
-- sem Idempotency-Key). Cada uma recebe uma chave sintética própria; nunca serão
-- reconsultadas por chave, então isso não cria colisão de deduplicação real.
UPDATE recargas SET idempotency_key = gen_random_uuid() WHERE idempotency_key IS NULL;

ALTER TABLE recargas
  ALTER COLUMN idempotency_key SET NOT NULL;

-- DD-002: a mesma tentativa de compra (mesma Idempotency-Key) nunca cria duas linhas.
-- Unicidade garantida por constraint no banco, não por checagem em memória.
ALTER TABLE recargas
  ADD CONSTRAINT uq_recargas_idempotency_key UNIQUE (idempotency_key);
