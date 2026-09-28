# Revisão de Clean Architecture — repositório completo

Data: 2026-09-26 · Escopo: todo o repositório (`Bilhetagem.sln`), dois formatos convivendo — legado congelado (ADR-0007) e módulos extraídos no formato canônico.

## Sumário para o planning

O legado `src/Legacy.Bilhetagem` está **fora de escopo desta revisão**: a ADR-0007 (migração estrangulada) congela esse projeto — só correção de bug, sem refatoração estrutural, e entidades anêmicas/atributos de mapeamento EF são aceitos ali até a extração. Nenhuma violação é reportada para ele.

O módulo extraído `src/Validacao` (formato canônico `Api`/`Application`/`Domain`/`Infrastructure`/`Contracts`) é onde a regra de dependência `Api → Application → Domain` se aplica de forma estrita, e é onde a revisão encontrou **3 violações**, nenhuma delas bloqueando a sprint mas todas com custo crescente se código novo continuar empilhando sobre elas.

## Violações encontradas

### 1. `Validacao.Application` referencia `Validacao.Infrastructure` diretamente

- **Arquivo:** `src/Validacao/Validacao.Application/Validacao.Application.csproj:9`
- **Regra violada:** Application deve referenciar apenas `Domain` e `Contracts`; a implementação concreta de Infrastructure só deveria ser conhecida pelo composition root (`Validacao.Api`), via injeção de dependência sobre a interface `IEmbarqueRepository` definida em Domain.
- **Impacto:** hoje nenhum arquivo de `Validacao.Application` importa o namespace `Infrastructure` — a referência está "morta" no código, mas presente no `.csproj`. Isso já quebra a regra de dependência e abre a porta para alguém acoplar um handler a um tipo concreto de Infrastructure (ex.: `DbContext`) sem que o build acuse nada.
- **Correção sugerida:** remover a `<ProjectReference>` para `Validacao.Infrastructure` do `Validacao.Application.csproj`; a referência a Infrastructure fica só em `Validacao.Api.csproj`, que já a declara para o wiring de DI.

### 2. `Validacao.Domain` com `<ProjectReference>` para outro projeto

- **Arquivo:** `src/Validacao/Validacao.Domain/Validacao.Domain.csproj:7`
- **Regra violada:** `Domain.csproj` não deveria ter `<ProjectReference>` para nenhum outro projeto do módulo — é a camada mais interna e não deve depender de nada.
- **Detalhe:** a referência é para `Validacao.Contracts`, que hoje é um projeto vazio (sem nenhum arquivo além do `.csproj`), então o impacto prático é nulo agora — mas o padrão do checklist trata isso como anti-pattern independente do conteúdo de Contracts.
- **Correção sugerida:** se `Contracts` vai carregar DTOs de borda (request/response da API), a referência correta é `Application → Contracts` e `Api → Contracts`, não `Domain → Contracts`. Avaliar se a referência em Domain é necessária; se não for, remover.

### 3. Setter público em propriedade de estado da entidade `Embarque`

- **Arquivo:** `src/Validacao/Validacao.Domain/Entities/Embarque.cs:10`
- **Trecho:** `public string Status { get; set; } = "PENDENTE";`
- **Regra violada:** setters públicos de propriedades de estado não devem existir em entidades — o estado só deveria mudar por método de domínio que preserva invariantes (aqui já existe `Aprovar()`, que faz isso corretamente).
- **Impacto:** qualquer código com referência ao objeto `Embarque` pode fazer `embarque.Status = "APROVADO"` sem passar pela regra de negócio de `Aprovar()`, contornando a garantia de invariante que a entidade tenta impor.
- **Correção sugerida:** trocar para `public string Status { get; private set; }` — a mutação já é feita via `Aprovar()`, então não há caller legítimo hoje que dependa do setter público.

## Fora de escopo (legado, ADR-0007) — não reportado como violação

`src/Legacy.Bilhetagem/Models/Cartao.cs` (atributos `[Table]`/`[Key]` de EF Core numa classe de domínio) e `src/Legacy.Bilhetagem/Services/RecargaService.cs` (serviço com `DbContext` injetado diretamente, sem camada de Application/Domain separada) seriam violações clássicas de Clean Architecture — mas a ADR-0007 aceita esse formato explicitamente até a extração, e o mandato do legado é só correção de bug. Nenhuma ação é sugerida aqui; mencionado só para registro de que foi inspecionado e conscientemente excluído.

## Itens sem violação (verificados, para constar)

- `Validacao.Infrastructure.csproj` referencia apenas `Validacao.Domain` — correto (implementa a interface de repositório definida em Domain).
- `Validacao.Api.csproj` referencia `Application` e `Infrastructure` — correto, é o composition root.
- Nenhum `using Microsoft.EntityFrameworkCore`, `Microsoft.AspNetCore`, `Amazon.*` ou `MassTransit`/`RabbitMQ.Client` em arquivos de `Validacao.Domain`.
- `Embarque` tem construtor privado e factory estática (`Registrar`) — padrão correto.
- `IEmbarqueRepository` não expõe tipos de EF Core (`IQueryable`, `DbSet`) na assinatura.
- `EmbarqueRepository` (Infrastructure) implementa a interface de Domain e fica em `Infrastructure/Persistence/Repositories/` — local correto.
- Nenhum handler de Application contém lógica de negócio condicional (if/else de regra) — `RegistrarEmbarqueHandler` delega para métodos de domínio.
- Nenhum prefixo de tecnologia em nomes de classe (ex.: nada como `EfEmbarqueRepository`).

## Recomendação para o planning

Nenhuma das 3 violações bloqueia a sprint de migração da bilhetagem, mas as três são baratas de corrigir agora (são remoções de referência/setter, sem lógica nova) e caras de corrigir depois que mais código for escrito em cima do padrão errado. Sugiro alocar isso como item de baixo esforço no início da sprint, antes de novos handlers/entidades nascerem replicando o mesmo padrão.
