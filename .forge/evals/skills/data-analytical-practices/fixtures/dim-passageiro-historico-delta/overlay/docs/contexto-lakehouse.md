# Contexto do lakehouse de bilhetagem

- Plataforma: Databricks (Unity Catalog), tabelas Delta.
- `gold.fct_recargas`: ~300 GB hoje, cresce ~8 GB/mês; consultas de BI filtram por `data_recarga` e `cod_canal`.
- `gold.dim_passageiro`: ~4 milhões de passageiros cadastrados no app.
- O time de BI da operadora parceira replica os marts no BigQuery (dataset `bi_parceiro`), onde `fct_recargas` fica em ~40 GB.
- Pedidos de eliminação de titular (LGPD) chegam pelo DPO com prazo de 15 dias para conclusão.
