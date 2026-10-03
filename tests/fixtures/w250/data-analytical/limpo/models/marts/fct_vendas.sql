select v.id, v.valor_em_centavos, row_number() over (partition by v.cliente_id order by v.id) as ordem from {{ ref('stg_vendas') }} v
