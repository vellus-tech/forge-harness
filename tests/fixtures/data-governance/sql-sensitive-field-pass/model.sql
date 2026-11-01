-- Cpf é marcado sensível e TEM entrada correspondente em data-classification.json
-- neste mesmo diretório — REQ-12b (extensão REQ-06 para .sql) deve passar.
CREATE TABLE customer (
    id uuid PRIMARY KEY,
    -- forge:sensitive-field="cpf"
    cpf text NOT NULL
);
