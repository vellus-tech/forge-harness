# cashback-worker

Worker do programa de fidelidade: credita cashback na carteira digital do passageiro a partir de eventos da bilhetagem. Repositório único do serviço (layout legado, sem `services/`): código em `src/`, testes em `tests/`, contratos em `contracts/`.

Mensageria: RabbitMQ via MassTransit. Entrega at-least-once — a validadora republica eventos após reconexão.

## Eventos

- **Consome** `ViagemValidada` na exchange `bilhetagem.viagens` (publicada pela validadora, outro serviço). `ViagemValidadaConsumer` calcula os 2% de cashback (`RegraCashback`) e credita na carteira via `CarteiraClient`.
- **Publica** `CashbackCreditado` na exchange `cashback.creditado` após o crédito confirmado.

Contrato completo em `contracts/asyncapi/cashback.yaml`.

## Idempotência e retry do crédito

A API da carteira (`docs/integracoes/carteira-api.md`) não é idempotente por padrão e tem timeouts comuns em pico (p99 ~4 s, e o crédito pode já ter sido efetivado mesmo quando o cliente recebe timeout). Por isso:

- `CarteiraClient.CreditarAsync` sempre envia o header `Idempotency-Key` com o `eventoId` da viagem — a carteira deduplica créditos com a mesma chave por até 72 h.
- O `HttpClient` de `ICarteiraClient` tem um handler de resiliência (`CarteiraResiliencia`) com até 5 tentativas, backoff exponencial e jitter. O retry só é seguro porque a chave de idempotência é a mesma em todas as tentativas — nunca gerar uma chave nova por retry.
- Isso também cobre a redelivery do MassTransit (entrega at-least-once): reprocessar a mesma mensagem gera a mesma `Idempotency-Key`, então não duplica o crédito.

## Como testar

`dotnet test Cashback.sln`

> Se o `dotnet restore` falhar com `401 Unauthorized` contra uma fonte NuGet privada (ex.: AWS CodeArtifact) configurada globalmente na máquina, é uma fonte de outro projeto sem credenciais válidas aqui — não um problema deste serviço. Restaure com `dotnet restore --configfile <config-só-com-nuget.org>` (ou remova a fonte problemática do `nuget.config` global) em vez de tentar corrigir credenciais que não pertencem a este projeto.
