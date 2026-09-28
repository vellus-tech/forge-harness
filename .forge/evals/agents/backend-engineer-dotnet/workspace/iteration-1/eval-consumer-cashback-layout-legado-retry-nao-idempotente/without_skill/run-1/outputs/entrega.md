# Entrega — TASK-07: consumir ViagemValidada e creditar cashback

## Escopo implementado

- **Contrato do evento** (`src/Cashback.Domain/ViagemValidada.cs`): record com `EventoId`, `PassageiroId`, `TarifaCentavos`, `ValidadaEm` e `CorrelationId`, conforme o payload descrito em `docs/product/modules/cashback/tasks.md`.
- **Consumidor** (`src/Cashback.Worker/Consumers/ViagemValidadaConsumer.cs`): `IConsumer<ViagemValidada>` que calcula o cashback via `RegraCashback.CalcularCentavos`, ignora eventos que resultem em valor zero e credita na carteira via `CarteiraClient`.
- **Ligação à fila** (`src/Cashback.Worker/Program.cs`): endpoint MassTransit/RabbitMQ dedicado (`cashback-worker-viagem-validada`) vinculado explicitamente à exchange `bilhetagem.viagens` publicada pela validadora (fanout), em vez de depender da convenção de nomes do MassTransit — a exchange já existe e é de outro serviço.
- **Retry na chamada à carteira** (`src/Cashback.Worker/Program.cs`): política Polly de 5 tentativas com backoff exponencial (200ms, 400ms, 800ms, 1.6s, 3.2s) no `HttpClient` do `CarteiraClient`, cobrindo tanto erros 5xx quanto `TaskCanceledException` (timeout) — o cenário relatado no pico.
- **Idempotência do crédito** (`src/Cashback.Infrastructure/Carteira/CarteiraClient.cs`): `CreditarAsync` agora exige um `idempotencyKey` e o envia no header `Idempotency-Key` do `POST /v1/creditos`. O consumidor deriva essa chave do `EventoId` do evento (`cashback-viagem-{eventoId}`), que é único por viagem.

## Por que a idempotência não é opcional aqui

`docs/integracoes/carteira-api.md` documenta que a API da carteira **não é idempotente por padrão** — duas chamadas com o mesmo corpo geram dois créditos — e que timeouts no pico (p99 ~4s) não significam que o crédito falhou; ele pode ter sido efetivado mesmo com timeout no cliente. A tarefa (`docs/product/modules/cashback/tasks.md`, TASK-07) também é explícita: "a mesma viagem nunca gera dois créditos".

Um retry de 5 tentativas sobre um `POST` não idempotente, sem chave de deduplicação, multiplicaria créditos exatamente no cenário de pico que motivou o retry — a chamada original pode ter sido efetivada no servidor mesmo tendo estourado o timeout no cliente, e a tentativa seguinte creditaria de novo. Por isso a chave de idempotência (derivada do `EventoId`, único por viagem) foi tratada como parte da mesma mudança, não como melhoria futura: sem ela, o retry pedido é o próprio mecanismo do bug de crédito duplicado.

A mesma chave também protege contra redelivery da fila (at-least-once do RabbitMQ/MassTransit): se o broker reentregar o `ViagemValidada` após um ack perdido, a segunda tentativa de crédito é deduplicada pela carteira dentro da janela de 72h documentada.

## Decisões e trade-offs

- **Vínculo explícito à exchange em vez de topologia por convenção do MassTransit**: como a exchange `bilhetagem.viagens` é publicada por outro serviço (a validadora) e não é modelada como mensagem MassTransit deste lado, usei `ReceiveEndpoint(...).Bind("bilhetagem.viagens", ...)` com tipo `fanout`. Assumi fanout por falta de especificação do tipo de exchange na task; se a validadora usar `topic` ou `direct` com routing key, é um ajuste de uma linha, mas precisa ser confirmado com o time da validadora (ou registrado como pendência no canal de liaison, que este ambiente de eval não permite acionar).
- **Descartar eventos com cashback calculado igual a zero** (`RegraCashback.CalcularCentavos` retorna 0 para tarifa ≤ 0): evita chamar a carteira para créditos de valor zero. Não há requisito explícito para isso; é uma decisão defensiva de baixo risco.
- **Retry com Polly no nível do `HttpClient` (não no consumidor MassTransit)**: mantém o retry de transporte HTTP isolado da política de redelivery do MassTransit (que já existe por padrão via `at-least-once`). Evita empilhar dois mecanismos de retry com backoffs somados sem controle.
- **Pacote `Microsoft.Extensions.Hosting` adicionado explicitamente ao `Cashback.Worker.csproj`**: o projeto, como estava, não compilava (`Host.CreateApplicationBuilder` não resolvia) porque só a dependência transitiva `Microsoft.Extensions.Hosting.Abstractions` chegava via MassTransit — faltava a referência direta ao pacote completo. Corrigi por ser bloqueador para qualquer build, não é uma mudança de escopo da task.

## O que não foi feito (fora do escopo desta entrega)

- Não há teste automatizado do fluxo completo do consumidor MassTransit (`ViagemValidadaConsumer.Consume`) — testar via `MassTransit.Testing`/`InMemoryTestHarness` exigiria um novo pacote de teste e um harness de host, o que ampliaria bastante o escopo desta mudança pontual. Cobri a parte que dá o maior risco de regressão silenciosa: o `CarteiraClient` envia o header `Idempotency-Key` corretamente (teste em `tests/Cashback.UnitTests/CarteiraClientTests.cs`).
- Não testei o comportamento do retry Polly (5 tentativas, backoff) com um handler HTTP que simula falhas intermitentes — seria o próximo teste a adicionar antes de considerar isso pronto para produção.
- Não configurei dead-letter / mensagens envenenadas (evento que falha as 5 tentativas de retry): o comportamento atual é deixar o MassTransit aplicar sua política padrão de retry/erro do transporte, o que provavelmente move a mensagem para a fila de erro padrão (`_error`), mas isso não foi verificado nem configurado explicitamente.

## Verificação

- `dotnet build Cashback.sln` — sucesso (0 erros).
- `dotnet test tests/Cashback.UnitTests/Cashback.UnitTests.csproj` — 3/3 testes passando (2 pré-existentes de `RegraCashback` + 1 novo de `CarteiraClient`).
