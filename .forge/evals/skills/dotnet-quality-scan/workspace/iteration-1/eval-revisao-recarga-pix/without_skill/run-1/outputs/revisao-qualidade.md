# Revisão de qualidade — cobrança Pix de recarga de cartão (branch `feature/recarga-pix`)

Escopo revisado: diff entre `main` e `feature/recarga-pix` (6 arquivos, 105 linhas), todos em `src/Recarga/`. Nenhuma correção foi aplicada — apenas apontamentos para decisão antes do PR.

## Bloqueadores (impedem build ou representam falha crítica)

1. **`RecargaDbContext` não existe em lugar nenhum do código e não há `PackageReference` de EF Core no projeto.** `src/Recarga/Recarga.Api/Infra/PixGatewayClient.cs` usa `Microsoft.EntityFrameworkCore` e injeta `RecargaDbContext`, mas nem o tipo nem o pacote foram adicionados (`Recarga.Api.csproj` não declara nenhum `PackageReference`, e `Directory.Packages.props` não lista EF Core). A build quebra.
2. **`Recarga.Api` e `Recarga.Seed` não estão registrados em `Recarga.sln`.** Um `dotnet build`/`dotnet test` na raiz do monorepo não compila os projetos novos — quem rodar o baseline de build não vai nem chegar a ver os erros acima.
3. **Nenhum registro de DI para `ISaldoService`, `PixGatewayClient` ou `RecargaDbContext`.** `Program.cs` só tem `AddControllers()`; a aplicação sobe mas quebra em runtime no primeiro `POST /recargas/{cartaoId}/pix` por falta de serviço registrado.
4. **SQL injection em `PixGatewayClient.Historico`.** `FromSqlRaw($"SELECT * FROM recargas WHERE cartao_id = '{cartaoId}'")` interpola a entrada do usuário diretamente na query. Precisa de parâmetro (`FromSqlInterpolated` ou parâmetro nomeado). Isso também viola a regra do repositório em `.forge/rules/data/data-config-sql.md` sobre acesso a dados parametrizado.
5. **Valor monetário como `decimal`, não como inteiro em centavos.** `.forge/rules/domain/money-as-cents.md` exige `long`/`amountInCents` para todo valor financeiro (erro de arredondamento de ponto flutuante é inaceitável em cobrança). `RecargaPix.Valor` e o parâmetro `valor` do controller são `decimal`. Isso é regra de domínio do próprio repositório, não só boa prática genérica.

## Riscos sérios (corrigir antes do PR, alta probabilidade de incidente)

6. **`catch { }` vazio em `RegistrarCobranca` engole qualquer falha do PSP.** O controller sempre retorna `202 Accepted` mesmo quando a chamada ao gateway Pix falhou (timeout, 5xx, payload rejeitado). O cliente acredita que a cobrança foi registrada quando não foi — não há log, métrica ou retorno de erro. Preciso saber se isso é intencional (fire-and-forget) ou esquecimento.
7. **Cobrança criada nunca é persistida.** `CriarCobranca` monta o `RecargaPix` e chama `_pix.RegistrarCobranca`, mas não há nenhum `_db.Recargas.Add(...)`/`SaveChanges`. Como `Historico` lê de `_db.Recargas`, o histórico nunca vai mostrar as cobranças criadas por este endpoint — inconsistência de dados entre escrita e leitura.
8. **Chamada síncrona bloqueante em código async (`.Result` e `.Wait()`).** `_saldoService.ConsultarAsync(cartaoId).Result` no controller e `http.PostAsJsonAsync(...).Wait()` em `PixGatewayClient` bloqueiam thread do pool do Kestrel; sob carga isso é risco real de esgotamento de threads/deadlock. O action method deveria ser `async Task<IActionResult>` usando `await` de ponta a ponta.
9. **`new HttpClient()` por chamada.** `PixGatewayClient.RegistrarCobranca` instancia um `HttpClient` novo a cada cobrança em vez de usar `IHttpClientFactory`/`HttpClient` injetado — risco conhecido de esgotamento de sockets (`SocketException`) sob volume.
10. **Nenhuma validação de `valor`.** O endpoint aceita `decimal` sem checar `> 0` nem limites — permite cobrança Pix de valor zero, negativo ou arbitrariamente alto sem nenhuma barreira de negócio.
11. **Endpoint financeiro sem autenticação/autorização.** `RecargaController` não tem `[Authorize]` nem qualquer guarda — qualquer chamador não autenticado pode criar uma cobrança Pix associada a um `cartaoId` arbitrário.
12. **Sem idempotência.** Não há chave de idempotência no POST; um retry de cliente (comum em timeout de rede) gera duas cobranças Pix distintas para a mesma intenção do usuário.

## Observações menores

13. **`DateTime.Now` em vez de `DateTime.UtcNow`** para `ExpiraEm` — gera inconsistência de fuso quando o serviço roda em ambiente com timezone diferente do esperado; convenção usual em backend é sempre UTC no domínio.
14. **`PixGatewayClient` mistura duas responsabilidades**: chamada HTTP ao PSP e consulta direta ao banco via EF Core (`Historico`). Vale separar em um client de gateway e um repositório — facilita testar cada parte isoladamente e reduz o raio de mudança.
15. **URL do PSP hardcoded** (`https://psp.example.invalid/cob`) direto no código em vez de configuração (`appsettings`/`IOptions`) — dificulta trocar de ambiente (sandbox PSP vs. produção) sem novo build.
16. **`[FromBody] decimal valor`** como parâmetro primitivo solto, sem um DTO de request — funciona no ASP.NET Core, mas não dá espaço para atributos de validação (`[Range]`, `[Required]`) nem para evoluir o contrato sem quebrar compatibilidade.

## Resumo para priorização

Antes de abrir o PR, os itens 1–5 (bloqueadores) precisam estar resolvidos só para o código compilar e rodar; os itens 6–12 são risco de negócio/segurança que eu revisaria pessoalmente com o time antes de mergear, mesmo que o build passe. Os itens 13–16 são melhorias de manutenibilidade, não bloqueiam o PR.
