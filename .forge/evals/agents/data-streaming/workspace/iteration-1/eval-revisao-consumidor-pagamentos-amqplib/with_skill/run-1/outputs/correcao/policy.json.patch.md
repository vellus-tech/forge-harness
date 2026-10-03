# infra/rabbitmq/policy.json — versão corrigida

Corrige RMQ-AP-06 (espelhamento clássico, removido no RabbitMQ 4.0): a fila `pagamentos` passa
a ser quorum, com `delivery-limit` sempre acompanhado de `dead-letter-exchange` (nunca um sem o
outro — sem DLX, a mensagem que estoura o limite é descartada em silêncio) e `overflow=reject-publish`
(nunca o `drop-head` silencioso, já que a fila tem confirms).

```json
{
  "name": "quorum-pagamentos",
  "pattern": "^pagamentos$",
  "apply-to": "queues",
  "definition": {
    "delivery-limit": 6,
    "dead-letter-exchange": "pagamentos.dlx",
    "dead-letter-strategy": "at-least-once",
    "max-length": 100000,
    "overflow": "reject-publish"
  }
}
```

O **tipo** da fila (`x-queue-type: quorum`) não é definido pela policy — é fixado na criação da
fila e é imutável. `ch.assertQueue('pagamentos', { durable: true })` hoje recria uma fila clássica
se ela não existir, ou falha com `PRECONDITION_FAILED` se a fila `pagamentos` clássica já existir
com esse nome. A migração é:

1. Declarar `pagamentos.dlx` (exchange, fanout ou topic conforme o roteamento de erro) e a fila
   `pagamentos.parking` (quorum, com `max-length` e alerta de profundidade > 0, sem consumidor
   automático — é o parking lot monitorado).
2. Declarar a fila nova `pagamentos` com `arguments: { 'x-queue-type': 'quorum' }` — isso exige
   um corte (blue-green): drenar a fila clássica atual, subir a definição acima e o consumidor
   apontando para a fila quorum, com `rabbitmqadmin` v2 ou um passo de deploy dedicado. Não dá
   para converter a fila existente in-place.
3. Remover a policy antiga (`ha-mode`/`ha-sync-mode`) do cluster depois do cutover.

`README.md` do worker deve documentar esse passo de migração, já que a policy é aplicada por
`rabbitmqctl import_definitions` no deploy — a definição de fila quorum não entra por policy, só
pela criação da fila em si (que fica no `consumidor.js` corrigido).
