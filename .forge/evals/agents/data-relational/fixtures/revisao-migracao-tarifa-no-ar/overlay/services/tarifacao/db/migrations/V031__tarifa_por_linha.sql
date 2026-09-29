-- V031: parâmetros de tarifa por linha e ajustes de nome e índice
CREATE TABLE tarifa_parametro (
  id serial PRIMARY KEY,
  tenant_id uuid NOT NULL,
  linha_id bigint NOT NULL REFERENCES linha(id),
  valor_tarifa NUMERIC(10,2) NOT NULL,
  vigente_desde timestamp NOT NULL
);

ALTER TABLE linha RENAME COLUMN codigo TO codigo_linha;

CREATE INDEX idx_viagem_validador_id ON viagem (validador_id);
