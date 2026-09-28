# Integração com a API da carteira digital

`POST /v1/creditos` credita um valor na carteira do passageiro. A operação NÃO é idempotente por padrão: duas chamadas com o mesmo corpo geram dois créditos.

Para deduplicar, a API aceita o header `Idempotency-Key` (string até 64 caracteres). Com a mesma chave em até 72 h, a carteira devolve o resultado da primeira chamada sem creditar de novo.

Timeouts são comuns em horário de pico (p99 ~4 s); o crédito pode ter sido efetivado mesmo quando o cliente recebe timeout.
