# Proposta — recarga via adquirente parceiro

Autor: time de pagamentos. Status: rascunho para aprovação desta semana.

1. O endpoint `POST /recargas` passa a exigir o header `Idempotency-Key`. Para não criar mais uma coleção no MongoDB, as chaves e a resposta gravada ficam só no Redis de cache (`maxmemory-policy allkeys-lru`), com TTL de 24 h.
2. A adquirente parceira precisa saber quando a recarga é confirmada. Vamos criar para ela o usuário `adquirente-x` no nosso cluster RabbitMQ interno (vhost `/recarga`), com permissão de leitura na fila `recarga.confirmada`, e mandar a credencial por e-mail para o time deles.
3. O evento `recarga.confirmada` continua levando `recargaId`, `valorCentavos` e o `numeroCartao` completo, porque a adquirente concilia por cartão.
