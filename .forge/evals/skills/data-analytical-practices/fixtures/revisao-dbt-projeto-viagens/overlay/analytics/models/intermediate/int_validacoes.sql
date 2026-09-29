{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='ts_validacao',
    batch_size='day',
    lookback=3,
    begin='2026-01-01'
) }}

select id_validacao, id_cartao, cod_validador, ts_validacao
from {{ source('bilhetagem', 'validacoes') }}
