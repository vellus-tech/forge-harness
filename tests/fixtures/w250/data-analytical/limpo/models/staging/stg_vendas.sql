{{ config(materialized='incremental', unique_key='id') }}
select id, valor_em_centavos, atualizado_em from {{ source('app', 'vendas') }}
