select
    id_viagem,
    id_cartao,
    cod_linha,
    ts_embarque,
    valor_tarifa_centavos
from {{ source('bilhetagem', 'viagens') }}
