-- Nova: índice para a consulta de conciliação por linha e dia.
ALTER TABLE `validacoes` ADD INDEX `idx_validacoes_linha_data` (`linha_id`, `validado_em`);
