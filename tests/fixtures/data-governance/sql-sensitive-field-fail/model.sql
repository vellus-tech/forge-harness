-- Cpf é um campo sensível (REQ-12b) marcado via comentário de linha SQL, mas
-- este diretório NÃO tem um data-classification.json com entrada "cpf" — deve
-- reprovar (mesmo contrato do REQ-12b, extensão REQ-06 para .sql).
CREATE TABLE customer (
    id uuid PRIMARY KEY,
    -- forge:sensitive-field="cpf"
    cpf text NOT NULL
);
