# Revisão de Clean Architecture — módulo `src/Recarga`

Data: 2026-09-26. Módulo recebido pronto do fornecedor; revisão feita para liberar o PR do dia. Todas as correções abaixo já foram aplicadas diretamente nos arquivos.

## Violações encontradas e corrigidas

1. **Domain dependia de Infrastructure (regra de dependência invertida).** `Recarga.Domain.csproj` tinha `ProjectReference` para `Recarga.Infrastructure.csproj` — a camada mais interna apontando para a mais externa. Removida. `Recarga.Domain.csproj` agora não tem nenhuma referência (nem a projeto, nem a pacote): é a camada mais pura, como Clean Architecture exige.

2. **Entidade de domínio acoplada a EF Core.** `RecargaCartao.cs` usava `Microsoft.EntityFrameworkCore` e atributos `[Table]`/`[Column]` de `System.ComponentModel.DataAnnotations.Schema` para mapear persistência dentro do domínio. Removidos os `using` e os atributos; o mapeamento (`ToTable`, `HasColumnName`) foi movido para Fluent API em `RecargaDbContext.OnModelCreating`, em `Recarga.Infrastructure`.

3. **Entidade de domínio publicando direto no barramento de mensageria.** `RecargaCartao.ConfirmarAsync(IPublishEndpoint)` fazia o domínio depender do MassTransit e publicar a mensagem ele mesmo. Havia um comentário no código citando uma decisão de 22/09 com o fornecedor para isso, sem ADR registrado. Revertido: o método virou `Confirmar()`, síncrono, só muda o estado (`Status = "CONFIRMADA"`). A publicação da mensagem foi movida para `SolicitarRecargaHandler` (camada de aplicação), que é quem deve orquestrar efeitos colaterais externos.
   - **Atenção**: isso reverte uma decisão que o fornecedor tratou como combinada. Recomendo abrir um ADR (`/forge:adr`) registrando por que a publicação saiu do domínio, para não haver retrabalho na próxima entrega dele.

4. **Mensagem publicada sem contrato tipado.** O evento era um objeto anônimo (`new { Id, NumeroLogicoCartao, ValorCentavos }`). Criado `Recarga.Contracts.Events.RecargaConfirmada` (record) e o handler agora publica esse tipo. `Recarga.Contracts` já existia como projeto mas estava vazio — passou a ter uso real como projeto de contratos compartilháveis com consumidores externos da fila.

5. **Interface de repositório no Domain vazando EF Core.** `IRecargaRepository` expunha `DbSet<RecargaCartao> Recargas` e um método `Filtrar(IQueryable<RecargaCartao>)` sem uso em nenhum outro arquivo — vazamento de detalhe de persistência (EF Core) através de uma abstração de domínio. Substituído por dois métodos de intenção de negócio: `ObterTotalConfirmadoNoDiaAsync` e `AdicionarAsync`. `Filtrar` foi removido por não ter nenhum chamador no módulo — se havia uso fora do que foi fornecido, sinalizar antes do merge.

6. **Application acoplada a EF Core.** `SolicitarRecargaHandler` chamava `_repositorio.Recargas.Where(...).SumAsync(...)` diretamente — LINQ assíncrono do EF Core dentro da camada de aplicação. Trocado pela chamada ao novo método do repositório (`ObterTotalConfirmadoNoDiaAsync`), que encapsula a consulta dentro de `Recarga.Infrastructure`.

7. **Dependência implícita/não declarada.** `SolicitarRecargaHandler.cs` usava `MassTransit` (`IPublishEndpoint`), mas `Recarga.Application.csproj` não tinha `PackageReference` para `MassTransit` — só compilava porque o pacote chegava por referência transitiva via `Recarga.Domain`, que por sua vez não deveria nem ter essa referência. Corrigido: `Recarga.Application.csproj` agora declara `MassTransit 8.2.5` explicitamente.

8. **`Recarga.Infrastructure` não referenciava `Recarga.Domain`.** Faltava o `ProjectReference` — inconsistente com o fato de `RecargaDbContext` precisar mapear `RecargaCartao`. Adicionado.

## Arquivos alterados

- `src/Recarga/Recarga.Domain/Recarga.Domain.csproj` — removidas todas as referências (projeto e pacotes).
- `src/Recarga/Recarga.Domain/Entities/RecargaCartao.cs` — sem `using` de infraestrutura, sem atributos de mapeamento, `Confirmar()` síncrono e sem I/O.
- `src/Recarga/Recarga.Domain/Repositories/IRecargaRepository.cs` — interface expressa em termos de domínio, sem tipos do EF Core.
- `src/Recarga/Recarga.Contracts/Events/RecargaConfirmada.cs` — novo. Contrato tipado do evento publicado.
- `src/Recarga/Recarga.Application/Recarga.Application.csproj` — `PackageReference MassTransit` explícito.
- `src/Recarga/Recarga.Application/Handlers/SolicitarRecargaHandler.cs` — sem `using` de EF Core; usa os novos métodos do repositório; publica `RecargaConfirmada`; limite diário extraído para constante `LimiteDiarioCentavos`.
- `src/Recarga/Recarga.Infrastructure/Recarga.Infrastructure.csproj` — `ProjectReference` para `Recarga.Domain` adicionado.
- `src/Recarga/Recarga.Infrastructure/Persistence/RecargaDbContext.cs` — `DbSet<RecargaCartao>` e mapeamento via Fluent API.
- `src/Recarga/Recarga.Infrastructure/Repositories/RecargaRepository.cs` — novo. Implementação de `IRecargaRepository`.

## Não corrigido — sinalizado para decisão humana

- **Condição de corrida no limite diário.** A leitura do total confirmado e a inserção da nova recarga não são atômicas (sem transação nem lock). Duas requisições concorrentes para o mesmo cartão podem, juntas, ultrapassar o limite de R$ 500,00/dia mesmo com a checagem presente. Isso é uma decisão de design (transação de banco, lock otimista, ou serialização por cartão na fila) que não decidi sozinho por não ser puramente uma questão de camadas.
- **DI/composição** (`Program.cs` ou equivalente) não existe no módulo fornecido — não há onde registrar `IRecargaRepository → RecargaRepository` nem o `DbContext`/MassTransit. Precisa ser adicionado no host (`Recarga.Api`) antes do PR, ou confirmar que isso já existe em outro lugar do repositório não incluído nesta revisão.
- **ADR pendente** da decisão original do fornecedor (item 3 acima).

## Build

Não executei `dotnet build`/`dotnet restore` neste ambiente de avaliação (rede/NuGet não verificados; fora do escopo autorizado desta execução). As mudanças foram revisadas por leitura atenta de tipos e assinaturas, mas recomendo rodar o build antes de abrir o PR.
