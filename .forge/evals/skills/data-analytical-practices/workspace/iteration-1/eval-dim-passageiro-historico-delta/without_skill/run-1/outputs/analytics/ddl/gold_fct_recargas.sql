-- Fato de recargas no Databricks (Delta) — grão: uma linha por recarga confirmada.
-- Particionamento diário por data_recarga: casa com o filtro mais comum de BI
-- (data_recarga, cod_canal) e espelha o particionamento que o time de BI da
-- parceira replica no BigQuery (ver docs/design-dim-passageiro.md).
-- valor_centavos: dinheiro como inteiro em centavos (convenção do projeto).
CREATE TABLE gold.fct_recargas (
    id_recarga        BIGINT  NOT NULL COMMENT 'chave da recarga confirmada',
    id_passageiro     BIGINT  NOT NULL COMMENT 'FK para gold.dim_passageiro (id_passageiro)',
    cod_canal         STRING  NOT NULL COMMENT 'canal de origem da recarga',
    valor_centavos    BIGINT  NOT NULL COMMENT 'valor da recarga em centavos (BRL)',
    data_recarga      DATE    NOT NULL COMMENT 'data de confirmação da recarga; coluna de particionamento'
)
USING DELTA
PARTITIONED BY (data_recarga)
COMMENT 'Fato de recargas confirmadas. Particionado por dia (data_recarga).'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true'
);

-- Manutenção recorrente (rodar via job agendado, fora do escopo desta DDL):
-- OPTIMIZE gold.fct_recargas ZORDER BY (cod_canal);
-- Compacta arquivos pequenos dentro de cada partição diária e melhora o filtro
-- adicional por cod_canal sem trocar a estratégia de particionamento.
