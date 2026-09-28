select cod_linha, nome_linha, operadora, modal
from {{ source('bilhetagem', 'linhas') }}
