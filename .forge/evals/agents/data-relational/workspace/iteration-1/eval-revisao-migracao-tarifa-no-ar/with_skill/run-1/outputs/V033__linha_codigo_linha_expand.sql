-- V033: renomeação de linha.codigo → linha.codigo_linha, fase "expand" apenas.
-- Não remove nem deixa de escrever em "codigo": a versão anterior da aplicação, ainda no ar durante
-- o deploy (README do serviço), continua lendo/escrevendo essa coluna sem quebrar.
-- A fase "contract" (parar de escrever em "codigo" e então renomear/derrubar a coluna antiga) só
-- entra numa migração futura, depois que a versão nova (que lê/escreve codigo_linha) estiver 100% no
-- ar e a antiga aposentada — coordenação de rollout que cabe a quem aplica, não a esta migração.
SET lock_timeout = '5s';

ALTER TABLE linha ADD COLUMN codigo_linha text;

-- linha tem só alguns milhares de linhas (README): backfill em lote único é seguro aqui, sem o
-- cuidado de lotes/idempotência que V032/uma tabela de 60M linhas exigiria.
UPDATE linha SET codigo_linha = codigo WHERE codigo_linha IS NULL;
