TASK-07 implementada no cashback-worker, sem commit. Relatório completo em `work/entrega.md`.

O worker consome o `ViagemValidada` do exchange `bilhetagem.viagens`, calcula os 2% com a `RegraCashback` e credita pelo `CarteiraClient`. A suíte passou de 2 para 10 testes, todos verdes. Escrevi os testes antes da implementação e os vi falhando.

Decisão principal: o POST de crédito não é idempotente (`docs/integracoes/carteira-api.md`). Um retry de 5 tentativas sem chave duplicaria crédito no pico. Por isso o crédito envia `Idempotency-Key` com o `eventoId` da viagem, que a carteira deduplica por 72 h. O retry é de até 5 tentativas, só para falhas transitórias (rede, timeout, 408, 429, 5xx), com backoff e jitter.

Pontos que precisam de confirmação antes de produção:
- Não verifiquei o nome de tipo da mensagem. O MassTransit roteia pelo namespace do tipo, e escolhi `Cashback.Infrastructure.Bilhetagem`. Se a validadora publicar de outro jeito, o consumer não recebe nada.
- O `Bind("bilhetagem.viagens")` usa o tipo de exchange padrão, não confirmado. Não há RabbitMQ nem carteira neste ambiente, então não testei ponta a ponta.
- A proteção contra crédito duplicado vale só dentro da janela de 72 h. Republicação depois disso duplicaria.
- Depois de 5 falhas a mensagem vai para o `_error` do MassTransit. Não há reprocessamento automático.

Além disso, o worker não compilava antes (`Host` sem `using`, e o SDK de worker não trouxe o pacote). Corrigi com o `using` e a referência explícita a `Microsoft.Extensions.Hosting` 10.0.0.

O `dotnet-baseline.sh --check` reprova: faltam `Directory.Build.props`, `.editorconfig` e `Directory.Packages.props`. Não apliquei o `--apply` nem desliguei nada para passar; a lacuna fica para decisão de vocês.

A árvore já vinha com cerca de 200 arquivos de `.claude/` e `.forge/` removidos do índice, antes de qualquer edição minha. Não toquei neles.
