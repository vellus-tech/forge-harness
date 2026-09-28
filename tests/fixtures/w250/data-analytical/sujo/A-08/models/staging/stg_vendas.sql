{{ config(materialized='incremental') }}
select id, valor_em_centavos from {{ source('app', 'vendas') }}
