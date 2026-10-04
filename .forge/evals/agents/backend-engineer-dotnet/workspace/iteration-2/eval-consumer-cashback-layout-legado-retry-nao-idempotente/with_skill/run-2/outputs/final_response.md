## TASK-07 implementada no cashback-worker

O worker agora consome `ViagemValidada` do exchange `bilhetagem.viagens` e credita 2% da tarifa na carteira do passageiro pelo `CarteiraClient`. O POST de crédito tenta até 5 vezes, com backoff exponencial e jitter, e repete só em timeout, erro de rede, 408, 429 e 5xx.

A chave de idempotência é o `eventoId`, enviada no header `Idempotency-Key`. Isso é o que torna o retry seguro: a carteira devolve o resultado da primeira chamada quando a mesma chave chega em até 72 h, inclusive quando o timeout escondeu um crédito já efetivado. Retry com chave nova a cada tentativa duplicaria crédito no pico.

Verificação: `dotnet test Cashback.sln` com 7 testes aprovados (5 novos, escritos antes da implementação). `dotnet build Cashback.sln` sem erros. Não executei contra RabbitMQ nem contra a carteira, porque esta execução não tem rede.

Pontos que exigem atenção antes de subir:

1. O namespace de `ViagemValidada` é um chute, porque o publicador não está no repositório. O MassTransit desserializa pelo tipo URN, então é preciso confirmar o envelope e o tipo do exchange com a validadora.
2. A idempotência vale só em 72 h. A validadora republica após reconexão, então uma republicação posterior duplica crédito. A correção durável é uma tabela de deduplicação por `eventoId`, e o projeto ainda não tem banco. Recomendo decidir isso antes de marcar a TASK como concluída, por isso mantive o `[ ]` no tracker.
3. O Worker não compilava no HEAD: `Program.cs` usa `Host`, mas o csproj não referenciava `Microsoft.Extensions.Hosting`. Adicionei a referência 10.0.0, que já estava no cache local.
4. O baseline de build .NET (`Directory.Build.props`, `.editorconfig`, `Directory.Packages.props`) está ausente. Não apliquei, porque mudaria a configuração de build do repositório inteiro.

O relatório completo está em `entrega.md` na raiz do projeto. Não fiz commit, porque o modo é standalone e não há `commit_policy`.
