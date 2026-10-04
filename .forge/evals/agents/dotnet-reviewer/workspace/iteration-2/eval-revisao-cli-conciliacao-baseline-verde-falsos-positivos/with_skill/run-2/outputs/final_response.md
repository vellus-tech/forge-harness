Revisão da `feature/conciliacao-cli` contra `main` concluída. Findings em `review/dotnet-review.json` e resumo em `review/resumo.md`, ambos dentro do projeto.

Recomendação: não aprovar como está.

Os dois pontos mais graves:

- O teste do Conciliador (`tests/Conciliacao.Testes/ConciliadorTests.cs:19`) usa `Assert.NotNull(lote)` numa variável que nunca é nula. Ele passa independentemente do resultado, não verifica o status gravado e não cobre divergência, que é o caso que faz o cron sair com 1.
- O `Conciliacao.sln` lista só `Conciliacao.Dominio`. O CLI, a infra e o teste ficam de fora. Um `dotnet build` ou `dotnet test` sobre a solução não compila o CLI nem roda o teste, então o "CI verde" não cobre o caminho das 3h. Não há configuração de CI no repositório, então não consegui confirmar qual comando o CI executa.

Demais findings (médios): código de saída que não separa divergência de falha de infra; loop lotes x lançamentos que pode pesar com volume real (estimativa, o volume não está no repositório); parse de CSV sem validação e sem vírgula decimal; retorno do UPDATE ignorado, então um lote inexistente conta como processado. Baixos: sync-over-async no Main (scan marcou BLOCKER, rebaixado, não há deadlock em console); condição `EndsWith('Tests')` no `Directory.Build.props` que não casa com `Conciliacao.Testes`; ausência de transação.

Verificação: baseline PASS. Scan com 2 FOUND, ambos julgados caso a caso. Build e testes não foram verificados, porque o restore do NuGet exige rede, que não estava disponível nesta execução.
