# Data Model — Tarifa Viva

| Tabela | Serviço | Campos sensíveis |
|---|---|---|
| viagens | validacao-embarque-api | nenhum |
| cartoes_transporte | validacao-embarque-api | nenhum (número lógico, não é cartão de pagamento) |
| pedidos_recarga | recarga-api | token_cartao, ultimos4 |
| lotes_liquidacao | liquidacao-operadoras-worker | nenhum |
| passageiros | cadastro-passageiro-api | cpf, data_nascimento, comprovante_matricula_url |
