-- REQ-03 / DD-002: idempotência de POST /recargas garantida por constraint no banco,
-- não por checagem em memória. Coluna nullable para não quebrar linhas históricas
-- (criadas antes desta migration, sem idempotency_key); toda nova recarga avulsa
-- passa a exigi-la na camada de aplicação (routes.ts).
ALTER TABLE recargas ADD COLUMN idempotency_key UUID;
ALTER TABLE recargas ADD CONSTRAINT recargas_idempotency_key_key UNIQUE (idempotency_key);
