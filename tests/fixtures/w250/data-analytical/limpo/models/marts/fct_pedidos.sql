{{ config(materialized='incremental', incremental_strategy='microbatch', event_time='criado_em', batch_size='day') }}
select pedido_id, valor_em_centavos from {{ ref('stg_pedidos') }}
