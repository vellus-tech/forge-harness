CREATE TABLE `pedido` (id BIGINT AUTO_INCREMENT PRIMARY KEY) ENGINE=InnoDB; -- w250:contexto
CREATE INDEX idx_pedido_cliente ON pedido (cliente_id);
ALTER TABLE pedido ADD INDEX idx_pedido_canal (canal);
