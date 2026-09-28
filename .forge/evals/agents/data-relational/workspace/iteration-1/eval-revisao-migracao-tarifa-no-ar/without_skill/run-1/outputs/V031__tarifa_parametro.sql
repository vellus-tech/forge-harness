-- V031: parâmetros de tarifa por linha
-- Revisão: mantém apenas as mudanças ADITIVAS e seguras para rodar com a versão anterior
-- do serviço ainda no ar. O rename de coluna e o índice em `viagem` saem daqui (ver V032 e V033).
SET lock_timeout = '5s';

-- Nova tabela de parâmetros de tarifa, seguindo o mesmo padrão de tipos e RLS do restante do
-- schema (V030): bigint identity, timestamptz, valor monetário em centavos.
CREATE TABLE tarifa_parametro (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  linha_id bigint NOT NULL REFERENCES linha(id),
  valor_tarifa_em_centavos bigint NOT NULL,
  vigente_desde timestamptz NOT NULL
);

CREATE INDEX idx_tarifa_parametro_tenant_id_linha_id
  ON tarifa_parametro (tenant_id, linha_id, vigente_desde DESC);
-- tabela nova e vazia: CREATE INDEX comum aqui não é um problema de lock (nada para
-- concorrer). Diferente do índice em `viagem` na V033, que tem ~60M linhas.

ALTER TABLE tarifa_parametro ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarifa_parametro FORCE ROW LEVEL SECURITY;
CREATE POLICY tarifa_parametro_por_tenant ON tarifa_parametro
  USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- Fase "expand" do rename codigo -> codigo_linha (ver .forge/rules/data/schema-evolution.md):
-- adiciona a coluna nova e mantém as duas em sincronia via trigger, sem remover "codigo".
-- A versão anterior do serviço, ainda no ar durante o deploy, continua lendo/escrevendo
-- "codigo" sem quebrar.
ALTER TABLE linha ADD COLUMN codigo_linha text;

UPDATE linha SET codigo_linha = codigo WHERE codigo_linha IS NULL;
-- `linha` tem poucos milhares de linhas (README) — UPDATE em lote único é seguro aqui.
-- Não fazer o mesmo em `viagem` (60M linhas) sem lotes e sem CONCURRENTLY (ver V033).

CREATE OR REPLACE FUNCTION linha_sincroniza_codigo() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.codigo_linha := COALESCE(NEW.codigo_linha, NEW.codigo);
    NEW.codigo := COALESCE(NEW.codigo, NEW.codigo_linha);
  ELSIF NEW.codigo IS DISTINCT FROM OLD.codigo THEN
    NEW.codigo_linha := NEW.codigo;
  ELSIF NEW.codigo_linha IS DISTINCT FROM OLD.codigo_linha THEN
    NEW.codigo := NEW.codigo_linha;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_linha_sincroniza_codigo
  BEFORE INSERT OR UPDATE ON linha
  FOR EACH ROW EXECUTE FUNCTION linha_sincroniza_codigo();

-- Próximos passos (fora desta migration, ver outputs/revisao.md):
--   V032: CREATE INDEX CONCURRENTLY idx_viagem_validador_id (fora de transação).
--   V033 (só depois que a nova versão do serviço, lendo/escrevendo codigo_linha, estiver
--         100% implantada e estável): DROP TRIGGER trg_linha_sincroniza_codigo,
--         DROP FUNCTION linha_sincroniza_codigo, ALTER TABLE linha DROP COLUMN codigo,
--         e então (opcional) ALTER TABLE linha ALTER COLUMN codigo_linha SET NOT NULL.
