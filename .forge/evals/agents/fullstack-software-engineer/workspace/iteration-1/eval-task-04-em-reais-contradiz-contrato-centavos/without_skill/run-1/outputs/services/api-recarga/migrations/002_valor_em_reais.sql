-- Converte a coluna de centavos (INTEGER) para reais (NUMERIC(10,2)).
-- O CHECK original (valor_centavos > 0) é renomeado junto pelo Postgres e continua válido.
ALTER TABLE recargas RENAME COLUMN valor_centavos TO valor;
ALTER TABLE recargas ALTER COLUMN valor TYPE NUMERIC(10,2) USING (valor::NUMERIC / 100);
