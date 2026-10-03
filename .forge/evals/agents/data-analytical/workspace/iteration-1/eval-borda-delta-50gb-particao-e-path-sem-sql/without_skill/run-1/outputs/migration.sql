-- Delta Lake não suporta ALTER TABLE para trocar colunas de particionamento in-place.
-- É preciso recriar a tabela física e reescrever os dados. CTAS/REPLACE é a via mais
-- simples e transacional; alternativa é CLONE + reescrita se o volume/downtime exigir
-- staging fora de uma única transação.
--
-- Pré-requisitos antes de rodar em produção:
--   1. Congelar/pausar escritores durante a janela de corte (ver outputs/nota-validador.md).
--   2. Ter espaço em disco/armazenamento para reescrever ~50 GB (pico ~2x durante o CTAS).
--   3. Medir tempo estimado de shuffle/reescrita em um ambiente de staging com amostra real
--      antes de rodar contra os 50 GB de produção.

CREATE OR REPLACE TABLE gold.viagens
USING DELTA
PARTITIONED BY (data_validacao, operadora_id)
AS
SELECT
  viagem_id,
  tenant_id,
  operadora_id,
  linha_id,
  cartao_sk,
  tarifa_centavos,
  validado_em,
  CAST(validado_em AS DATE) AS data_validacao
FROM gold.viagens;

-- Pós-migração:
OPTIMIZE gold.viagens;
-- Se a tabela tiver z-order/estatísticas em uso hoje (não há evidência disso no DDL
-- original), reavaliar ZORDER BY após o corte, já que o particionamento por dia
-- reduz a necessidade de zordenar por validado_em, mas operadora_id como partição
-- (2º nível) ainda se beneficia de ANALYZE TABLE ... COMPUTE STATISTICS.
ANALYZE TABLE gold.viagens COMPUTE STATISTICS;
