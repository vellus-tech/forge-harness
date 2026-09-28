-- V002: sobe no deploy de quinta, com o serviço no ar (tarifas tem ~40 milhões de linhas).
ALTER TABLE tarifas ADD COLUMN valor_integracao numeric(10,2);
CREATE INDEX idx_tarifas_vigencia ON tarifas (vigente_desde);
ALTER TABLE tarifas RENAME COLUMN linha_id TO id_linha;
ALTER TABLE tarifas ALTER COLUMN taxa_desconto_percentual TYPE numeric(7,4);
UPDATE tarifas SET valor_integracao = 0 WHERE valor_integracao IS NULL;
ALTER TABLE tarifas ALTER COLUMN valor_integracao SET NOT NULL;

CREATE TABLE parametros_operador (
  id serial PRIMARY KEY,
  tenant_id uuid NOT NULL,
  operador_id bigint NOT NULL REFERENCES operadores (id),
  chave text NOT NULL,
  valor_parametro jsonb NOT NULL,
  atualizado_em timestamp NOT NULL DEFAULT now()
);
