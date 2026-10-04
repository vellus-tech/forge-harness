Implementei a TASK-07 no cashback-worker, com uma mudança que você precisa conhecer: a `Idempotency-Key` no POST de crédito.

Sem a chave, o retry de 5 tentativas não resolve o timeout e ainda pode creditar duas vezes, porque a carteira pode efetivar o crédito mesmo quando dá timeout (`docs/integracoes/carteira-api.md`). Usei o `eventoId` da viagem como chave em todas as tentativas. Isso também cobre o critério "a mesma viagem nunca gera dois créditos".

Os 6 testes unitários passam. O build completo do Worker não rodou, porque o pacote `Microsoft.Extensions.Hosting` não está no cache offline. O erro é na linha `Host.CreateApplicationBuilder`, que já existia no HEAD.

Pendências antes de merge: confirmar com a validadora o tipo do exchange `bilhetagem.viagens`, a janela de 72 h da chave (redelivery depois disso gera novo crédito) e o valor de `Origem`. Não commitei. Detalhes em `entrega.md`.
