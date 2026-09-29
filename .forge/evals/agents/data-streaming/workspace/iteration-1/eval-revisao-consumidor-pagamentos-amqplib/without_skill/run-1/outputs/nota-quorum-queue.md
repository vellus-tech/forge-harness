`delivery-limit` só tem efeito em **quorum queues** — o `x-queue-type: quorum` precisa ser definido na declaração da fila (não dá pra trocar o tipo de uma fila clássica existente via policy; é preciso recriar a fila ou migrar com `rabbitmq-queues` / definindo a fila nova já como quorum). Ajuste equivalente em `assertQueue`:

```js
await ch.assertQueue('pagamentos', {
  durable: true,
  arguments: { 'x-queue-type': 'quorum' },
});
```

Isso substitui o mirror `ha-mode`/`ha-sync-mode` (removido no RabbitMQ 4.0+) pelo mecanismo de replicação suportado no 4.1, e habilita o `delivery-limit` da `policy.corrigida.json` para cortar o laço de redelivery em definitivo, mesmo se o código do consumidor voltar a ter algum bug de requeue.
