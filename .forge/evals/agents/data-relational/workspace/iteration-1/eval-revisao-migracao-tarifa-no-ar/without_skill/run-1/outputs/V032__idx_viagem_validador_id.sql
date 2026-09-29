-- V032: índice de validador_id em viagem (~60M linhas), fora de transação.
--
-- ATENÇÃO ao runner: CREATE INDEX CONCURRENTLY não pode rodar dentro de uma transação, e o
-- Flyway (community) envolve cada script .sql numa transação BEGIN/COMMIT por padrão. Este
-- arquivo precisa ser executado com a transação desabilitada para este script específico
-- (ex.: flag por-migration do runner de Flyway em uso, ou um step de deploy dedicado que
-- roda `psql` fora de transação). Por isso ele fica em arquivo próprio, separado da V031.
--
-- Sem CONCURRENTLY, CREATE INDEX toma um SHARE lock que bloqueia todo INSERT/UPDATE/DELETE
-- em `viagem` até o índice terminar de ser construído — em 60M linhas, seriam minutos a
-- dezenas de minutos de bloqueio de escrita, com o serviço no ar e validadores inserindo
-- viagens em tempo real. Inaceitável para deploy contínuo sem janela.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_viagem_validador_id
  ON viagem (validador_id);

-- CONCURRENTLY pode falhar e deixar um índice INVALID para trás (ex.: se um DDL concorrente
-- ou timeout interromper a construção). Runbook para quem aplica:
--   1) Se a migration falhar, checar: SELECT indexrelid::regclass, indisvalid FROM pg_index
--      WHERE indexrelid = 'idx_viagem_validador_id'::regclass;
--   2) Se indisvalid = false, fazer DROP INDEX CONCURRENTLY idx_viagem_validador_id e
--      reexecutar esta migration (idempotente por causa do IF NOT EXISTS).
