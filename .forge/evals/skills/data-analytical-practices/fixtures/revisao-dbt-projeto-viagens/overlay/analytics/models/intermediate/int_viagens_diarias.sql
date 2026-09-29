{{ config(materialized='incremental') }}

select
    id_viagem,
    cod_linha,
    cast(ts_embarque as date) as data_viagem,
    valor_tarifa_centavos
from {{ ref('stg_viagens') }}
{% if is_incremental() %}
where ts_embarque > (select max(ts_embarque) from {{ this }})
{% endif %}
