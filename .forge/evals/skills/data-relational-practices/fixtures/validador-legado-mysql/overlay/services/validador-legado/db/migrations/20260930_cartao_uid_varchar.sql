-- Nova: cartao_uid passa de CHAR(14) para VARCHAR(32) (cartões novos têm UID de 7 e 10 bytes).
ALTER TABLE `validacoes` MODIFY COLUMN `cartao_uid` VARCHAR(32) NOT NULL, ALGORITHM=COPY, LOCK=SHARED;
