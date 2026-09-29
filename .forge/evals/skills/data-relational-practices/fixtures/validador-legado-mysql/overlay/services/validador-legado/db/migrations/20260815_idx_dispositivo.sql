-- Aplicada em produção em 2026-08-15.
ALTER TABLE `validacoes` ADD INDEX `idx_validacoes_dispositivo` (`dispositivo_id`), ALGORITHM=INPLACE, LOCK=NONE;
