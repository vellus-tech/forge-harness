# Revisão de qualidade — cobrança Pix de recarga (feature/recarga-pix)

Escopo: diff de `main...feature/recarga-pix` (commit 5c26e6e), seis arquivos C#/csproj em `src/Recarga/`. Nenhuma correção foi aplicada; este relatório serve de base para decisão antes do PR para develop.

## Resumo executivo

O código não está pronto para PR. Há uma vulnerabilidade de SQL injection, uma falha de cobrança silenciosa que devolve 202 mesmo quando o PSP falha, stubs em caminhos de dinheiro (saldo sempre zero, seed com contagem falsa) e um provável erro de build com a configuração de `TreatWarningsAsErrors` do repositório. A feature também contraria duas convenções declaradas no AGENTS.md: valores monetários em decimal (a regra pede centavos inteiros) e identificadores em inglês. Nenhum teste foi adicionado.

## Críticos

`PixGatewayClient.Historico` monta SQL por interpolação: `FromSqlRaw($"SELECT * FROM recargas WHERE cartao_id = '{cartaoId}'")`. O `cartaoId` vem da rota HTTP, então é injeção de SQL direta. O método hoje não é chamado por nenhum endpoint, mas está público e pronto para uso. Correção: `FromSqlInterpolated` ou parâmetro explícito; idealmente, remover até haver caso de uso.

`RecargaController.CriarCobranca` tem `try { _pix.RegistrarCobranca(recarga); } catch { }` e responde `Accepted(recarga)`. Se o PSP falhar, o cliente recebe 202 como se a cobrança existisse, sem erro, sem retry e sem estado pendente. Em cobrança Pix isso significa cliente pagando um QR que nunca foi registrado, ou nunca pagando e o sistema não sabendo. Além disso, `RegistrarCobranca` retorna `void`, então a resposta não traz o identificador da cobrança nem o payload Pix (copia-e-cola/QR), que é o que o cliente precisa para pagar. Correção: o PSP deve devolver o resultado, a falha deve virar erro explícito (ou status pendente persistido), e a resposta deve conter o identificador e o payload.

## Altos

Bloqueio síncrono em caminho assíncrono. O controller usa `ConsultarAsync(cartaoId).Result` e o cliente usa `PostAsJsonAsync(...).Wait()`. Em ASP.NET Core não há SynchronizationContext, então deadlock é improvável, mas cada requisição segura uma thread do pool enquanto espera I/O, o que degrada sob carga. Correção: `async Task<IActionResult>` de ponta a ponta.

`new HttpClient()` a cada chamada em `RegistrarCobranca`. Com carga, isso esgota portas de socket. Correção: `IHttpClientFactory` registrado no `Program.cs`.

Registro de DI incompleto. `Program.cs` só chama `AddControllers()`. `ISaldoService`, `SaldoService`, `PixGatewayClient` e `RecargaDbContext` não estão registrados. Qualquer requisição a `/recargas/{id}/pix` falha com erro de resolução de dependência em runtime.

Tipo `RecargaDbContext` inexistente no diff e no projeto, e `Recarga.Api.csproj` não referencia `Microsoft.EntityFrameworkCore`, embora `PixGatewayClient` e `Historico` dependam dele. O projeto não compila nessa configuração.

Provável quebra de build por configuração do repositório. O `Directory.Build.props` da raiz define `GenerateDocumentationFile=true` e `TreatWarningsAsErrors=true`, com analisadores em `Recommended`. Os tipos públicos novos (`RecargaController`, `RecargaPix`, `ISaldoService`, `SaldoService`, `PixGatewayClient`) não têm comentário XML, o que gera CS1591, e isso vira erro. Os analisadores Sonar/Meziantou também devem acusar o `catch {}` vazio e o `.Result`/`.Wait()`, por serem padrões clássicos das regras deles (não conferi os IDs de regra individualmente).

Valor monetário em `decimal` e sem validação. `[FromBody] decimal valor` aceita zero, negativo e qualquer precisão. O AGENTS.md do repositório diz "money as integer cents". Hoje a convenção é violada no contrato da API, no domínio e na serialização para o PSP. Correção: valor em centavos (`long`), com validação de mínimo e máximo na entrada.

`SaldoService.ConsultarAsync` retorna `0m` fixo. Todo `SaldoAnterior` gravado e enviado ao PSP é zero. Isso é stub em caminho de dinheiro; precisa estar explícito como não-produção (feature flag ou exceção "não implementado") até existir integração real.

## Médios

Endereço do PSP hardcoded (`https://psp.example.invalid/cob`). Deve vir de configuração por ambiente.

`RecargaPix` é o objeto de domínio serializado diretamente para o PSP e devolvido ao cliente. Isso expõe `SaldoAnterior` e `CartaoId` ao PSP e ao chamador, sem DTO de contrato. Vale separar o modelo de domínio do contrato de integração e da resposta da API.

`RecargaPix` calcula `ExpiraEm` com `DateTime.Now`. Em servidor, o correto é `DateTime.UtcNow` (ou `DateTimeOffset`), para não depender do fuso do host.

Regra de negócio no controller. `CriarCobranca` consulta saldo, monta o domínio e chama o gateway. Esse fluxo deveria estar num serviço de aplicação, testável sem HTTP.

Nomes em português em código público (`CriarCobranca`, `RegistrarCobranca`, `Historico`, `ConsultarAsync`, `SaldoService`), enquanto o AGENTS.md pede identificadores em inglês. Resolver agora é mais barato do que depois de integrar consumidores.

Nenhum teste no diff. Não há teste para o fluxo de criação, para a falha do PSP, nem para validação de valor. A cobrança é o caminho de maior risco e está sem cobertura.

Verbo e status da rota. `POST /recargas/{cartaoId}/pix` responde 202 com o corpo do domínio. Para um recurso criado, 201 com `Location` apontando para o recurso seria mais aderente. Depende de a cobrança ser assíncrona ou não, o que hoje não está definido.

## Baixos e de manutenção

`Recarga.Seed/Program.cs`: `SeedRunner.PopularAsync` retorna `ambiente.Length`, então o programa imprime "N cartões populados" com um número sem relação com o banco. Enganoso para quem roda o seed.

`Recarga.Seed/Program.cs`: o argumento de ambiente é aceito sem allowlist. Um typo ou ambiente errado roda o seed onde não deveria. Recomendo aceitar só `local` (ou uma lista explícita) e falhar nos demais.

Comentário de cabeçalho do seed diz "popula cartões de teste no banco local", o que contradiz o argumento de ambiente aceito no código.

## Não verificado

Não rodei build nem testes. Tentei `dotnet build --no-restore` no `Recarga.Api` e falhou com NETSDK1004 (`project.assets.json` ausente), porque o restore exige rede e a política desta execução a proíbe. A análise acima é estática. Os itens de build (CS1591, DI, EF ausente) precisam ser confirmados com `dotnet build` após restore em ambiente com rede.

## Próximos passos sugeridos

Antes do PR: corrigir SQL injection (ou remover `Historico`), tratar falha do PSP sem 202 falso, remover `.Result`/`.Wait()` e `new HttpClient()`, registrar DI, adicionar XML docs ou ajustar a configuração, trocar `decimal` por centavos com validação, e cobrir o fluxo com testes. Saldo e endereço do PSP podem ficar como pendência explícita, desde que a feature não vá para produção com o stub.
