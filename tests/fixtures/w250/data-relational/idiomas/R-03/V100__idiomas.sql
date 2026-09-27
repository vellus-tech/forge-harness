SET lock_timeout = '5s'; -- w250:contexto
CREATE TABLE nova (id bigint); -- w250:contexto
CREATE INDEX idx_pedido_cliente ON pedido (cliente_id);
ALTER TABLE pedido ALTER COLUMN canal SET NOT NULL;
