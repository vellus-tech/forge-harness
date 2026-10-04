# Entrega: TASK-07 — cashback ao consumir ViagemValidada

## Resumo

O worker passa a consumir o evento `ViagemValidada` do exchange `bilhetagem.viagens` e credita 2% da tarifa na carteira do passageiro pelo `CarteiraClient`. O POST de crédito tem até 5 tentativas em falha transitória (timeout, erro de rede, 5xx, 408, 429). Todas as tentativas usam a mesma `Idempotency-Key`, que é o `eventoId` da viagem. Os 6 testes unitários passam.

## Decisão que diverge do pedido: Idempotency-Key

O pedido era só o retry de 5 tentativas. Sem chave de idempotência, o retry não resolve o timeout e ainda pode duplicar o crédito. O `docs/integracoes/carteira-api.md` diz que `POST /v1/creditos` não é idempotente por padrão e que o crédito pode ter sido efetivado mesmo quando o cliente recebe timeout. Por isso o `eventoId` vai no header `Idempotency-Key` (uuid, 36 caracteres, dentro do limite de 64). Com a mesma chave em até 72 h, a carteira devolve o resultado da primeira chamada. Isso também cobre o critério "a mesma viagem nunca gera dois créditos" da TASK-07, já que a validadora republica eventos após reconexão.

Alternativa descartada: deduplicar localmente (tabela de eventos processados). Exigiria banco e transação entre o registro local e a chamada à carteira, e ainda assim não cobriria o caso de timeout com crédito efetivado. A chave na API da carteira resolve na origem.

## Arquivos alterados

- `src/Cashback.Infrastructure/Carteira/CarteiraClient.cs`: `CreditarAsync` recebe `idempotencyKey`, valida o tamanho (até 64) e repete até 5 tentativas com backoff exponencial (base de 300 ms). Erros 4xx (exceto 408 e 429) não são repetidos. O construtor aceita `atrasoBase` opcional para os testes.
- `src/Cashback.Worker/Consumers/ViagemValidadaConsumer.cs` (novo): record `ViagemValidada` e consumidor MassTransit. Tarifa zero não gera crédito.
- `src/Cashback.Worker/Program.cs`: `cfg.Message<ViagemValidada>(m => m.SetEntityName("bilhetagem.viagens"))`.
- `tests/Cashback.UnitTests/CarteiraClientTests.cs` (novo): 4 testes (retry com mesma chave, 5 tentativas em timeout, 400 sem retry, chave acima de 64 caracteres).
- `tests/Cashback.UnitTests/Cashback.UnitTests.csproj`: referência ao projeto Infrastructure.

## Verificação

- `dotnet test tests/Cashback.UnitTests` (restore offline a partir do cache local): 6 de 6 aprovados. Antes da correção, um teste pegou um bug: o `EnsureSuccessStatusCode` ficava dentro do `try` e um 400 era repetido. Corrigido separando o envio da checagem de status.
- `dotnet build` do Worker: falha com `CS0103: Host` em `Program.cs` linha 5. A linha é a mesma do HEAD e o erro vem de o pacote `Microsoft.Extensions.Hosting` não estar no cache offline. Não é causado por esta mudança, mas o Worker não foi compilado de ponta a ponta. A compilação do consumidor não reportou erro próprio. Precisa de `dotnet build` com rede antes de merge.

## Pontos em aberto

1. Tipo do exchange `bilhetagem.viagens`: não encontrei o contrato da validadora no repositório. Com `SetEntityName`, o MassTransit cria a fila e o binding com o tipo padrão. Se o exchange já existir como `topic` ou `direct`, o startup falha. Confirmar com o time da validadora.
2. Nome da fila e o schema de `ViagemValidada` vêm do `tasks.md`. Não há contrato `.yaml` de entrada em `contracts/`, só o de saída (`cashback.creditado`).
3. Janela de 72 h da Idempotency-Key: uma redelivery depois disso geraria novo crédito. Risco residual, a avaliar com o time da carteira ou com um registro local de eventos.
4. `Origem` do crédito está fixa em `cashback-viagem`. Confirmar o valor esperado pela carteira.
5. Sem commit. As mudanças estão na árvore de trabalho. O `git status` já mostrava remoções de `.claude/` e `.forge/` antes desta tarefa, e eu não mexi nelas.
