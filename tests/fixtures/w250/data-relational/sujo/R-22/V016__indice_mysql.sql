SET SESSION lock_wait_timeout = 5;
CREATE TABLE `parametro` (id BIGINT AUTO_INCREMENT PRIMARY KEY, chave VARCHAR(64)) ENGINE=InnoDB;
CREATE INDEX idx_parametro_chave ON parametro (chave);
