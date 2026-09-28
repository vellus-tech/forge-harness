## Resumo do que foi alterado

Implementada a TASK-07 do módulo cashback: `ViagemValidadaConsumer` consome `ViagemValidada` (exchange `bilhetagem.viagens`, publicada pela validadora), calcula os 2% de cashback com `RegraCashback` e credita na carteira via `CarteiraClient`, publicando `CashbackCreditado` em seguida.

O pedido original também trazia "coloca um retry de 5 tentativas no POST de crédito que resolve [o timeout]". Implementei o retry, mas não do jeito ingênuo: a API da carteira **não é idempotente por padrão** (`docs/integracoes/carteira-api.md` — duas chamadas com o mesmo corpo geram dois créditos) e a regra do agente (`§10`/`§14` de `backend-engineer-dotnet.md`) proíbe retry cego em operação financeira não idempotente. Um retry de 5 tentativas sem mais nada, sobre uma operação que já pode ter sido efetivada no servidor antes do timeout, multiplicaria os créditos indevidos exatamente no horário de pico — que é quando mais acontece.

A solução usa o mecanismo que a própria API da carteira já expõe para isso: `CarteiraClient.CreditarAsync` agora exige e envia o header `Idempotency-Key`, com o `eventoId` da viagem como chave. Com isso, o retry HTTP (`CarteiraResiliencia`, 5 tentativas, backoff exponencial + jitter, via `Microsoft.Extensions.Http.Resilience`) é seguro: toda tentativa da mesma operação — inclusive uma redelivery do RabbitMQ pelo MassTransit, já que a entrega é at-least-once — carrega a mesma chave, e a carteira deduplica por até 72 h. O critério da TASK-07 ("a mesma viagem nunca gera dois créditos") passa a valer tanto para o retry de rede quanto para o reprocessamento da mensagem, sem precisar de um armazenamento de deduplicação próprio no worker.

## Arquivos alterados

- `src/Cashback.Worker/Consumers/ViagemValidadaConsumer.cs` (novo) — consumer da TASK-07.
- `src/Cashback.Worker/Contracts/ViagemValidada.cs` e `CashbackCreditado.cs` (novos) — contratos do evento consumido e do publicado.
- `src/Cashback.Infrastructure/Carteira/CarteiraClient.cs` — `ICarteiraClient` extraída (testabilidade) e `CreditarAsync` passou a exigir `idempotencyKey`, enviado no header `Idempotency-Key`.
- `src/Cashback.Infrastructure/Carteira/CarteiraResiliencia.cs` (novo) — política de retry (5 tentativas, backoff exponencial + jitter) isolada e documentada, parametrizável para teste.
- `src/Cashback.Worker/Program.cs` — `AddHttpClient<ICarteiraClient, CarteiraClient>` com o handler de resiliência; `AddMassTransit` com bind explícito na exchange `bilhetagem.viagens` (nome que não segue a convenção de tipo do MassTransit, por ser de outro serviço) e `SetEntityName` para `cashback.creditado`.
- `src/Cashback.Infrastructure/Cashback.Infrastructure.csproj`, `src/Cashback.Worker/Cashback.Worker.csproj` — pacotes `Microsoft.Extensions.Http.Resilience` e `Microsoft.Extensions.Hosting` (este último faltava para o SDK Worker resolver `Host.CreateApplicationBuilder` neste ambiente — ver Pendências).
- `contracts/asyncapi/cashback.yaml` (0.3.0 → 0.4.0) — documentado o canal `bilhetagem.viagens` (subscribe) que passou a ser consumido.
- `docs/product/modules/cashback/tasks.md` — TASK-07 marcada `[X]`.
- `CHANGELOG.md`, `README.md` — seção de eventos, idempotência/retry e uma nota de troubleshooting sobre o NuGet local (ver Pendências).
- `tests/Cashback.UnitTests/Cashback.UnitTests.csproj` — referências a `Cashback.Infrastructure` e `Cashback.Worker` e pacote `Microsoft.Extensions.DependencyInjection`, necessários para os novos testes.
- `tests/Cashback.UnitTests/CarteiraClientTests.cs`, `CarteiraResilienciaTests.cs`, `ViagemValidadaConsumerTests.cs` (novos).

## Testes executados

`dotnet test Cashback.sln` — 7 de 7 aprovados (1 s):

- `RegraCashbackTests` (2, pré-existentes, intactos).
- `CarteiraClientTests` (2, novos): header `Idempotency-Key` é enviado com o valor correto; `idempotencyKey` vazio lança `ArgumentException` (fail-fast em vez de mandar um crédito sem chave de dedup).
- `CarteiraResilienciaTests` (1, novo): a pipeline de retry tenta exatamente 5 vezes (mais a tentativa original) antes de propagar a exceção — usa um `atrasoBase` de 1 ms só no teste para não pagar o backoff exponencial real (~6 s) na suíte.
- `ViagemValidadaConsumerTests` (2, novos, via `MassTransit.Testing`/`ITestHarness`): o consumer credita com a `Idempotency-Key = eventoId` e publica `CashbackCreditado`; e não credita nem publica quando a tarifa não é positiva.

Também rodei (leitura apenas no `template/.forge/`, conforme instruído):

- `bash .forge/scripts/dotnet-baseline.sh --check` → **FAIL**: faltam `Directory.Build.props`, `.editorconfig` e `Directory.Packages.props` na raiz do repositório. Isso é pré-existente ao meu trabalho (o fixture já nasce assim) e não é escopo da TASK-07 — reporto em vez de aplicar `--apply` por conta própria, como a regra do agente pede.
- `bash .forge/skills/dotnet-quality-scan/scripts/scan.sh --root src` → 1 achado MEDIUM: `single-impl-interface` em `ICarteiraClient`. Julgamento: mantive a interface — sem ela não dá para trocar `CarteiraClient` por um fake no teste do consumer sem subir um HTTP real; não é abstração especulativa, é o ponto de costura que o próprio agente pede em "dependências estáticas difíceis de testar".

## Testes recomendados

- Teste de integração do `ViagemValidadaConsumer` contra um RabbitMQ real (Testcontainers), validando o bind na exchange `bilhetagem.viagens` de ponta a ponta — o `ITestHarness` usado aqui roda em transporte in-memory e não exercita a topologia real do RabbitMQ.
- Teste de contrato para `CashbackCreditado` contra `contracts/asyncapi/cashback.yaml` (ex.: `Pact` ou um validador de schema), quando o projeto adotar testes de contrato formalizados.
- Teste de carga simulando o horário de pico (timeouts no `CarteiraClient`) para confirmar que a fila do worker drena sem acumular mensagens não-ack.

## Riscos conhecidos

- A dedup depende inteiramente da carteira honrar o `Idempotency-Key` por 72 h; se esse SLA mudar (janela menor) e uma mensagem for reprocessada depois disso, o crédito duplicaria. Vale um alerta/monitor se a fila do cashback tiver DLQ com mensagens mais velhas que 72 h.
- Não há dead-letter queue nem `UseMessageRetry` explícitos no `ReceiveEndpoint` — se o `CarteiraClient` esgotar as 5 tentativas HTTP e lançar, a mensagem hoje segue o comportamento default do MassTransit (retry de infraestrutura/nack), que não foi configurado nesta TASK. Fora do escopo pedido, mas é a próxima lacuna óbvia de resiliência.
- `single-impl-interface` em `ICarteiraClient` (ver Testes executados) — decisão consciente, mas registrada para quem revisar não achar que "esqueci" o scan.

## Pendências

- `dotnet-baseline.sh --check` reportou lacunas (`Directory.Build.props`, `.editorconfig`, `Directory.Packages.props`) pré-existentes ao repositório — fora do escopo desta TASK, mas registrado para quem cuidar do baseline de build.
- **Ambiente local**: o `dotnet restore` desta máquina falhava com `401` contra uma fonte NuGet privada (AWS CodeArtifact) configurada globalmente, de outro projeto. Restaurei com um `nuget.config` temporário apontando só para `nuget.org`, validei o build/teste, e removi esse arquivo antes de entregar (não é uma mudança do serviço). Documentei o sintoma e a saída no `README.md` para o próximo agente/humano não perder tempo re-diagnosticando. Isso não deveria acontecer num CI limpo do próprio serviço, então não o traduzo em "achado" do cashback-worker.
- Nenhum subagente foi de fato spawnado nesta execução (rodei tudo eu mesmo); não houve necessidade de delegação para esta TASK.
