# Transcrição — TASK-07 cashback (agente backend-engineer-dotnet)

## Contexto lido

- Definição do agente em `work/.forge/agents/engineering/backend-engineer-dotnet.md`, lida integralmente.
- `docs/product/modules/cashback/tasks.md`: TASK-07 descrita, payload de `ViagemValidada` e critério de não duplicar crédito.
- `docs/integracoes/carteira-api.md`: `POST /v1/creditos` não é idempotente por padrão, aceita `Idempotency-Key` (até 64 caracteres, janela de 72 h), e timeouts no pico (p99 ~4 s) podem ocultar crédito já efetivado.
- `src/Cashback.Infrastructure/Carteira/CarteiraClient.cs`, `src/Cashback.Worker/Program.cs`, csprojs, `src/Cashback.Domain/RegraCashback.cs`, `contracts/asyncapi/cashback.yaml`, `CHANGELOG.md`, `README.md`, `AGENTS.md`, `.forge/rules/architecture/internal-grpc-communication.md`.
- Não há `ViagemValidada` nem publicador no repositório. O namespace do evento é desconhecido.

## Ambiente

- `dotnet` 10.0.107 disponível. Cache NuGet local contém MassTransit 8.3.0, Polly, xunit e Microsoft.Extensions.Hosting 10.0.0.
- `git status` do checkout já mostrava deleções pré-existentes em `.forge/agents/` e `.claude/`. Não foram tocadas.

## Comandos relevantes

1. `bash .forge/scripts/dotnet-baseline.sh --check` gerou MISS para `Directory.Build.props`, `.editorconfig` e `Directory.Packages.props`. Lacuna reportada, não materializada.
2. `dotnet test tests/Cashback.UnitTests/...` antes de mudar: 2 aprovados. Restore sem falha, com NU1900 por falta de rede.
3. Teste novo escrito primeiro (`CreditarCashbackDaViagemTests.cs`) e referência de projeto a `Cashback.Infrastructure` adicionada. `dotnet test`: falha de compilação, `CreditarCashbackDaViagem` inexistente. Vermelho confirmado.
4. Implementação: `CarteiraClient` com header `Idempotency-Key`, `CreditarCashbackDaViagem` com 5 tentativas, backoff exponencial, jitter e classificação de erros retentáveis.
5. `dotnet test`: 7 aprovados.
6. Worker: `ViagemValidada`, `ViagemValidadaConsumer`, endpoint `cashback.viagem-validada` com `Bind("bilhetagem.viagens")` em `Program.cs`.
7. `dotnet build Cashback.sln`: erro CS0103 `Host`. A linha já existia no HEAD. Tentativa com `using Microsoft.Extensions.Hosting;` falhou, porque o pacote não estava referenciado. Adicionada referência `Microsoft.Extensions.Hosting` 10.0.0 (cache local).
8. `dotnet build Cashback.sln`: 0 erros, 6 avisos NU1900.
9. `dotnet test Cashback.sln --no-build`: 7 aprovados.
10. `scan.sh --root src`: sem achados. `scan.sh --root tests`: 1 achado de `new HttpClient(handler)` em teste, mantido por ser handler em memória.
11. AsyncAPI e CHANGELOG atualizados.
12. `entrega.md` gravado na raiz do projeto.

## Decisões

- Chave de idempotência = `eventoId`, para que retry seja seguro frente a crédito já efetivado.
- Retry no caso de uso, não no cliente. Sem Polly, por falta de necessidade e de rede para validar.
- Repetição só em erro de rede, timeout, 408, 429 e 5xx. Não repete 4xx.
- Tarifa zero não chama a carteira.
- TASK-07 não marcada como `[X]`, porque o critério de unicidade só vale em 72 h.
- Nenhum commit, push ou tag: modo standalone, sem `commit_policy`.

## Pendências registradas

- Namespace e formato do envelope de `ViagemValidada` precisam de confirmação com a validadora.
- Deduplicação durável além de 72 h exige banco, ainda inexistente.
- Baseline .NET ausente, não aplicado.
- Integração com RabbitMQ e carteira não testada (sem rede).
