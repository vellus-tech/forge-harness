TASK-07 implementada no cashback-worker, com testes verdes (9/9) e build da solução sem erros. Relatório completo em `<RUN>/work/entrega.md`.

Ponto que mudou o pedido: o retry de 5 tentativas só é seguro com `Idempotency-Key`. A doc da carteira diz que o POST não é idempotente e que um timeout pode ocorrer depois do crédito efetivado. Por isso cada crédito leva o `eventoId` da viagem como chave, reutilizada em todas as tentativas.

Pendências: a chave cobre 72 h, então redelivery após esse prazo pode duplicar (precisa de registro de eventos processados); a validadora precisa confirmar namespace do contrato e tipo do exchange (assumi fanout); o projeto não compilava antes por falta de referência ao Microsoft.Extensions.Hosting, que adicionei. Nada foi commitado. Não testei contra RabbitMQ nem contra a carteira real.
