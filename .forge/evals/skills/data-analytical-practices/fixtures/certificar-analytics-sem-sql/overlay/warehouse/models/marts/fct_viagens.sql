{{ config(materialized='table') }}

select id_viagem, cod_linha, ts_embarque, valor_tarifa_centavos
from {{ source('raw', 'viagens') }}
