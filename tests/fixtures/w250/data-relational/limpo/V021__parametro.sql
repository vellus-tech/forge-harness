SET lock_timeout = '5s';
CREATE TABLE parametro (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, chave text NOT NULL, valor_em_centavos bigint);
CREATE INDEX idx_parametro_chave ON parametro (chave);
ALTER TABLE parametro ADD CONSTRAINT parametro_valor_nn CHECK (valor_em_centavos IS NOT NULL) NOT VALID;
ALTER TABLE parametro VALIDATE CONSTRAINT parametro_valor_nn;
ALTER TABLE parametro ALTER COLUMN valor_em_centavos SET NOT NULL;
CREATE ROLE app_rw LOGIN NOBYPASSRLS;
