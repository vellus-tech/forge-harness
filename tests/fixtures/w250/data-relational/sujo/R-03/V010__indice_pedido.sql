SET lock_timeout = '5s';
CREATE INDEX idx_pedido_cliente ON pedido (cliente_id);
