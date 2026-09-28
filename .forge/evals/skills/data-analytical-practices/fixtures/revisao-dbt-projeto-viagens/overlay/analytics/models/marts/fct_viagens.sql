{{ config(materialized='table') }}

-- grão: uma linha por viagem (embarque validado)
select
    v.id_viagem,
    v.id_cartao,
    v.cod_linha,
    v.ts_embarque,
    cast(v.valor_tarifa_centavos as numeric(12,2)) / 100 as valor_tarifa
from {{ source('bilhetagem', 'viagens') }} v
