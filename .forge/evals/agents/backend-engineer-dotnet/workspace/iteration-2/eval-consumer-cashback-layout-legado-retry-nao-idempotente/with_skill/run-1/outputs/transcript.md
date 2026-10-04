# Transcrição da execução (backend-engineer-dotnet, TASK-07 cashback)

1. Li o prompt e a definição do agente `.forge/agents/engineering/backend-engineer-dotnet.md` integralmente.
2. Localizei `src/Cashback.*`, `docs/product/modules/cashback/tasks.md` (TASK-07 aberta), `docs/integracoes/carteira-api.md` (POST não idempotente, header `Idempotency-Key` com janela de 72 h), `contracts/asyncapi/cashback.yaml` e o `CarteiraClient`.
3. Confirmei que `ViagemValidada` não existe no repositório (só no tasks.md), e que o exchange `bilhetagem.viagens` não tem contrato.
4. Build de baseline falhou no Worker (`Host` não resolvido). `dotnet restore` sem rede funcionou com `--source /nonexistent-offline`, usando o cache global do NuGet.
5. `dotnet-baseline.sh --check`: reprova (faltam Directory.Build.props, .editorconfig, Directory.Packages.props). Não apliquei `--apply`; registrado como pendência.
6. TDD: escrevi `CarteiraClientTests.cs` e `CreditarCashbackHandlerTests.cs`, e adicionei referência ao Infrastructure no csproj de testes. Build falhou por tipos inexistentes (vermelho).
7. Implementei `CarteiraClient` (chave de idempotência, retry até 5 tentativas totais, backoff exponencial com jitter, repetição só em rede/timeout/408/429/5xx), `ViagemValidada`, `CreditarCashbackHandler`, `ViagemValidadaConsumer` e o wiring em `Program.cs` com endpoint explícito.
8. Adicionei `Microsoft.Extensions.Hosting` 10.0.0 (cache local) ao Worker para corrigir o build.
9. Testes: 9 aprovados. Mutação (retry desligado) derrubou 2 testes; código original restaurado e verde de novo.
10. Scan de qualidade: corrigi `blocking-wait` em teste; `new-httpclient` em teste considerado falso positivo (handler stub).
11. Atualizei asyncapi (canal consumido, versão 0.4.0), CHANGELOG, README e marquei TASK-07 como [X].
12. Escrevi `entrega.md` na raiz do workspace. Não commitei (standalone, sem commit_policy).
13. Decisões: chave = eventoId; retry manual sem Polly (sem rede para validar pacote); 5 = tentativas totais; deduplicação limitada à janela de 72 h da carteira; endpoint explícito para evitar fila duplicada.
