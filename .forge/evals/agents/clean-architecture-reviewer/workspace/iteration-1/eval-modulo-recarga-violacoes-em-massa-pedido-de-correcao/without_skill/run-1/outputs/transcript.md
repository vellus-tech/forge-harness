# Transcript — eval `modulo-recarga-violacoes-em-massa-pedido-de-correcao` / `without_skill` / `run-1`

Condição: baseline sem skill/agente (`without_skill`). Nenhum arquivo em `template/.forge/skills`, `template/.forge/agents`, `plugin/` ou `.forge/evals` foi lido. A tarefa foi resolvida só com conhecimento geral de Clean Architecture / .NET.

## Passos executados, em ordem

1. `date +%s > .t0` — registrado o instante inicial.
2. `mkdir -p work` e execução de `fixtures/modulo-recarga-violacoes-em-massa-pedido-de-correcao/setup.sh work` — montou o projeto .NET (`src/Recarga/*`) mais o esqueleto do consumidor forge-harness (`.forge`, `.claude`, `AGENTS.md` etc., irrelevantes para a tarefa).
3. Leitura de todos os arquivos sob `work/src/Recarga` (9 arquivos: 5 `.csproj` + 4 `.cs`) para entender o grafo de dependências entre `Recarga.Domain`, `Recarga.Application`, `Recarga.Contracts`, `Recarga.Infrastructure` e `Recarga.Api`.
4. Identificadas as violações de Clean Architecture (lista completa e racional em `outputs/docs/revisoes/clean-arch-recarga.md`):
   - `Recarga.Domain.csproj` referenciando `Recarga.Infrastructure.csproj` (regra de dependência invertida).
   - `Recarga.Domain.csproj` com `PackageReference` direto a `Microsoft.EntityFrameworkCore` e `MassTransit`.
   - Entidade `RecargaCartao` com atributos de mapeamento EF Core (`[Table]`, `[Column]`) e publicando diretamente no MassTransit via `ConfirmarAsync(IPublishEndpoint)`.
   - `IRecargaRepository` (no Domain) expondo `DbSet<RecargaCartao>` e um método `Filtrar(IQueryable<...>)` sem nenhum chamador.
   - `SolicitarRecargaHandler` (Application) usando LINQ assíncrono do EF Core (`SumAsync`) diretamente sobre o `DbSet` exposto pelo repositório.
   - `Recarga.Application.csproj` sem `PackageReference` a `MassTransit`, embora o handler usasse `IPublishEndpoint` — só compilava por referência transitiva via Domain.
   - `Recarga.Infrastructure.csproj` sem `ProjectReference` a `Recarga.Domain`, apesar do `DbContext` precisar da entidade.
   - Evento publicado como objeto anônimo, sem contrato tipado, apesar de existir um projeto `Recarga.Contracts` vazio destinado a isso.
5. Aplicadas as correções diretamente nos arquivos (sem passar por revisão humana intermediária, conforme pedido pelo usuário da fixture):
   - `Recarga.Domain.csproj`: removida toda `ProjectReference`/`PackageReference`.
   - `RecargaCartao.cs`: sem `using` de infraestrutura, sem atributos de mapeamento; `Confirmar()` virou método síncrono só de mudança de estado.
   - `IRecargaRepository.cs`: reescrita em termos de domínio (`ObterTotalConfirmadoNoDiaAsync`, `AdicionarAsync`), sem tipos do EF Core.
   - Criado `Recarga.Contracts/Events/RecargaConfirmada.cs` (record) como contrato tipado do evento.
   - `Recarga.Application.csproj`: adicionado `PackageReference MassTransit 8.2.5` explícito.
   - `SolicitarRecargaHandler.cs`: sem `using` de EF Core; usa os novos métodos do repositório; publica `RecargaConfirmada`; limite diário extraído para constante nomeada.
   - `Recarga.Infrastructure.csproj`: adicionada `ProjectReference` a `Recarga.Domain`.
   - `RecargaDbContext.cs`: `DbSet<RecargaCartao>` + mapeamento via Fluent API em `OnModelCreating` (substitui os atributos removidos da entidade).
   - Criado `Recarga.Infrastructure/Repositories/RecargaRepository.cs` implementando `IRecargaRepository` com EF Core.
6. Escrito `docs/revisoes/clean-arch-recarga.md` (dentro de `work/`) com: violações encontradas, arquivos alterados, e uma seção explícita de itens **não** corrigidos automaticamente por exigirem decisão humana — condição de corrida no limite diário (falta de transação/lock), ausência de composição/DI (`Program.cs`) para registrar `IRecargaRepository`/`DbContext`/MassTransit, e recomendação de abrir um ADR para a mudança que reverte a decisão de mensageria combinada com o fornecedor (havia um comentário no código citando uma reunião de 22/09 sem ADR).
7. Não executado `dotnet build`/`dotnet restore` — fora do escopo autorizado desta execução de eval (nenhuma verificação de build real, rede/NuGet inclusive, foi feita); registrado como ressalva explícita no resumo entregue.
8. Nenhum subagente foi necessário para esta tarefa — não há passo do fluxo que exigisse dispatch. Ver `outputs/dispatch.md`.
9. Cópia de todos os arquivos criados/alterados em `work/` para `outputs/`, preservando a árvore de caminhos relativa a `work/`.
10. Gravação de `.t0`/`timing.json` conforme instruído pelo harness.

## Decisões e trade-offs relevantes

- Optei por não introduzir um pipeline de domain events (evento de domínio interno + despachante) para manter o escopo dentro do que a fixture pedia (corrigir violações de camada, não redesenhar a mensageria). A publicação do evento de integração ficou na camada de Application, que é a orquestradora legítima de efeitos colaterais externos.
- Optei por remover o método `Filtrar(IQueryable<RecargaCartao>)` da interface de repositório por não ter nenhum chamador nos arquivos fornecidos e por vazar `IQueryable` (detalhe de infraestrutura) através de uma interface de domínio. Sinalizado no resumo para o caso de haver uso externo ao módulo.
- Não fabriquei um `Program.cs`/composição de DI que não existia na fixture original — apenas sinalizei a lacuna, para não inventar decisões de bootstrap que cabem ao time.
