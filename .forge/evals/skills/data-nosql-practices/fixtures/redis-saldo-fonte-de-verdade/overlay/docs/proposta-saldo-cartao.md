# Proposta — saldo do cartão de transporte

O saldo de créditos do cartão (recargas via PIX e débitos de tarifa a cada validação) precisa responder em menos de 5 ms para o validador embarcado. Proposta do time: guardar o saldo e o extrato de recargas diretamente no Redis com AOF ligado (`appendfsync everysec`), sem outro banco, usando `INCRBY` no débito e `LPUSH` no extrato. Estimativa: 3 milhões de cartões ativos, 4 tenants (operadoras). Nenhum ADR sobre o store do saldo foi registrado ainda.
