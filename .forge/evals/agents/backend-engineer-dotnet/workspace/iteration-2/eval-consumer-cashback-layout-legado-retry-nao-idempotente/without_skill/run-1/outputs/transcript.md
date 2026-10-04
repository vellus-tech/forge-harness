# Transcript: TASK-07 do módulo cashback

1. Li o prompt de execução e o pedido: implementar TASK-07 no cashback-worker, com retry de 5 tentativas no POST de crédito e relatório em entrega.md.
2. Li AGENTS.md e README.md do repositório. Localizei TASK-07 em `docs/product/modules/cashback/tasks.md`.
3. Li `docs/integracoes/carteira-api.md`. A API não é idempotente por padrão, e o timeout pode ocorrer após o crédito já ter sido efetivado. Decisão: o retry só é seguro com `Idempotency-Key` estável, usando o `eventoId` (uuid de 36 caracteres). Reenviar sem chave duplicaria crédito.
4. Li `CarteiraClient.cs`, `RegraCashback.cs`, `Program.cs`, os csproj, o contrato `contracts/asyncapi/cashback.yaml` e os testes existentes. O contrato de `ViagemValidada` não existe no repositório; o payload foi mapeado a partir de `tasks.md`.
5. Verifiquei o ambiente: `dotnet` 10.0.107 disponível. Restore offline funciona a partir do cache (apenas avisos NU1900 de vulnerabilidade, sem rede). Baseline: 2 testes aprovados.
6. TDD (vermelho): escrevi `tests/Cashback.UnitTests/Carteira/RoteiroHandler.cs`, `CarteiraClientTests.cs` e `tests/Cashback.UnitTests/Creditos/CreditoCashbackServiceTests.cs`. Adicionei referência de `Cashback.Infrastructure` ao csproj de testes. Resultado: erro de compilação (serviço inexistente), como esperado.
7. Primeira tentativa de renomear um teste com `sed -i` falhou por sintaxe do BSD sed (sufixo de backup obrigatório). A cadeia `&&` parou antes de gravar a implementação. Repeti com `sed -i ''`.
8. Verde: implementei `CarteiraClient` (chave obrigatória, máximo de 64 caracteres, 5 tentativas, retry em timeout, falha de rede, 5xx, 408 e 429, `CreditoRecusadoException` para outros 4xx, espera linear de 250 ms). Criei `CreditoCashbackService` (2% via `RegraCashback`, chave = eventoId, tarifa zero sem chamada). Criei `ViagemValidada` e `ViagemValidadaConsumer` no Worker. Ajustei `Program.cs` para endpoint explícito com `Bind("bilhetagem.viagens")`, `ExchangeType = "fanout"`, sem ConfigureEndpoints.
9. Resultado: 10 testes aprovados.
10. `dotnet build` do Worker falhou com CS0103 em `Host`. Verifiquei que a linha é do HEAD e que `Microsoft.Extensions.Hosting` não entra no assets. Adicionei `PackageReference Microsoft.Extensions.Hosting` 10.0.0 (versão presente no cache). Build do Worker: 0 erros.
11. Marquei TASK-07 como `[X]` em `docs/product/modules/cashback/tasks.md`.
12. Gravei `entrega.md` na raiz do repositório de trabalho, conforme o pedido.
13. Não fiz commit, push nem rede. Não toquei em `.claude/` e `.forge/`, cujas exclusões já existiam no status inicial.

Decisões em aberto registradas no entrega.md: janela de 72 h da chave, contrato e nomes de exchange e tipo de mensagem a confirmar com a validadora, pior caso de tempo nas tentativas, e política de erro para recusa 4xx.
