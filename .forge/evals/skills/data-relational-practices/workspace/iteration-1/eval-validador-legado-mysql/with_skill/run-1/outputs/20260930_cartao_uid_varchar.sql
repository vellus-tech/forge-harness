-- Revisada: cartao_uid vai de CHAR(14) para VARCHAR(32) via expand -> migrate -> contract
-- (R-13: ALGORITHM=COPY/LOCK=SHARED nesta tabela de ~180M linhas e 2 mil inserts/s, sem
-- janela de manutenção, travaria escrita por minutos/horas). Este arquivo é só o passo 1.
ALTER TABLE `validacoes` ADD COLUMN `cartao_uid_v2` VARCHAR(32) NULL, ALGORITHM=INSTANT, LOCK=NONE;
