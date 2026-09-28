{{ config(materialized='incremental') }}

select
    id as recarga_id,
    tenant_id,
    cartao_id,
    operadora_id,
    cast(valor as numeric(12,2)) as valor_reais,
    criado_em
from {{ source('app', 'recargas') }}
{% if is_incremental() %}
where criado_em > (select max(criado_em) from {{ this }})
{% endif %}
