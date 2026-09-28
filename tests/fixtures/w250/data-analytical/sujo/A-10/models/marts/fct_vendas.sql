select v.id, v.valor_em_centavos from {{ source('app', 'vendas') }} v
