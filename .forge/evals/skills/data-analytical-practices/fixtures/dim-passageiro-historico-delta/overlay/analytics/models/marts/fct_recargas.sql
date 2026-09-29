{{ config(materialized='table') }}

-- grão: uma linha por recarga confirmada
select
    r.id_recarga,
    r.id_passageiro,
    r.cod_canal,
    r.valor_centavos,
    r.data_recarga
from {{ ref('stg_recargas') }} r
