-- V032: índice de validador em viagem (~60M linhas) — CONCURRENTLY, fora de transação, para não bloquear
-- escrita com a aplicação (antiga e nova) no ar durante o deploy.
-- flyway:executeInTransaction=false
SET lock_timeout = '5s';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_viagem_validador_id ON viagem (validador_id);
