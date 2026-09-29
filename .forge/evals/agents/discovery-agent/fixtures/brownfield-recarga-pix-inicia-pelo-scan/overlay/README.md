# recarga-api

Serviço de recarga de créditos do cartão de transporte da Viação Norte (bilhetagem eletrônica). Hoje a recarga é feita apenas nos postos de venda presenciais e em totens, com pagamento em dinheiro ou cartão de débito. O saldo é gravado no PostgreSQL e sincronizado com os validadores embarcados a cada 15 minutos.

## Rodando localmente

`docker compose up` sobe o PostgreSQL e a API em http://localhost:8080.
