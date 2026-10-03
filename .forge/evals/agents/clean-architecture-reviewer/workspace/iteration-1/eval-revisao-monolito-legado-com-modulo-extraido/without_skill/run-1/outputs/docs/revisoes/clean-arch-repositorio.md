# Revisão de Clean Architecture — repositório Bilhetagem

Data: 2026-09-26. Escopo: todo o repositório (`src/Legacy.Bilhetagem` e `src/Validacao`), preparação para o planning da sprint de migração da bilhetagem.

## Resumo executivo

O repositório contém dois mundos com maturidade arquitetural muito diferente. `Legacy.Bilhetagem` é um monólito sem separação de camadas: o "service" de aplicação acessa o ORM diretamente e o modelo de domínio carrega anotações de persistência — não há nenhuma camada de domínio isolável para migrar. `Validacao`, o módulo já extraído, segue a estrutura Domain/Application/Contracts/Infrastructure/Api corretamente na maior parte, mas tem uma violação de direção de dependência (Application referenciando Infrastructure) e uma quebra de encapsulamento na entidade de domínio. Nenhuma violação encontrada é de correção trivial no código legado — a recomendação para o planning é tratar `Legacy.Bilhetagem` como reescrita orientada por domínio, não como refatoração incremental.

Total: 4 violações (1 crítica, 2 médias, 1 leve), listadas abaixo com arquivo e linha.

## Violações

### 1. [Crítica] Camada de aplicação acoplada diretamente ao ORM (sem camada de domínio)

**Arquivo:** `src/Legacy.Bilhetagem/Services/RecargaService.cs`, linhas 1, 8, 10, 14, 17

`RecargaService` recebe um `Microsoft.EntityFrameworkCore.DbContext` bruto no construtor (linha 10) e consulta a tabela diretamente via `_db.Set<Cartao>().FirstAsync(...)` (linha 14) e `_db.SaveChangesAsync()` (linha 17). Não existe abstração de repositório, não existe camada de domínio separada da infraestrutura — a regra de negócio ("cartão bloqueado não recarrega", linha 15) está misturada com a chamada de persistência no mesmo método. Isso é o oposto da Regra de Dependência: a camada que deveria conter a política de negócio depende diretamente de um framework de infraestrutura (EF Core).

Impacto para a migração: não há fronteira de domínio para extrair — o candidato a "Domain" e o candidato a "Infrastructure" estão na mesma classe. Qualquer extração precisa começar criando essa fronteira (entidade de domínio + interface de repositório), não apenas mover arquivos.

### 2. [Crítica] Modelo de domínio anotado com metadados de persistência (ORM vazando para o domínio)

**Arquivo:** `src/Legacy.Bilhetagem/Models/Cartao.cs`, linhas 1–2, 6, 9

`Cartao` usa `[Table("cartoes")]` (linha 6) e `[Key]` (linha 9) do `System.ComponentModel.DataAnnotations`/`.Schema` diretamente na classe de domínio. O nome do namespace já sinaliza o problema: `Legacy.Bilhetagem.Models`, não `Domain`/`Entities` — é um modelo de dados, não uma entidade de domínio. Compare com `Validacao.Domain.Entities.Embarque`, que não tem nenhuma anotação de EF Core e é mapeado externamente (via `Validacao.Infrastructure`).

Impacto: a entidade de domínio e o modelo de persistência são o mesmo tipo. Trocar de banco, versionar o mapeamento independente do domínio, ou testar a regra de negócio sem infraestrutura fica inviável enquanto essa mistura existir.

### 3. [Média] Application referencia Infrastructure diretamente — inversão de dependência quebrada

**Arquivo:** `src/Validacao/Validacao.Application/Validacao.Application.csproj`, linha 9

```
<ProjectReference Include="..\Validacao.Infrastructure\Validacao.Infrastructure.csproj" />
```

O projeto `Validacao.Application` referencia `Validacao.Domain` (linha 7, correto) e `Validacao.Contracts` (linha 8, correto), mas também referencia `Validacao.Infrastructure` (linha 9). Nada no código de `Validacao.Application` hoje usa esse pacote — o único handler existente, `RegistrarEmbarqueHandler`, depende apenas de `IEmbarqueRepository` (interface do Domain). A referência é supérflua e, mais grave, inverte a direção que o resto do projeto respeita: em Clean Architecture, Infrastructure depende de Application/Domain (implementa as interfaces deles), nunca o contrário. Com essa referência, Application passa a enxergar tipos concretos de infraestrutura (EF Core, `DbContext`) mesmo sem usá-los diretamente, e abre a porta para o próximo desenvolvedor instanciar `EmbarqueRepository` dentro de um handler em vez de receber a interface por injeção — a composição (bind da interface à implementação) deveria acontecer só em `Validacao.Api` (composition root).

Recomendação: remover essa `ProjectReference` de `Validacao.Application.csproj`. O registro de `IEmbarqueRepository → EmbarqueRepository` no DI container continua em `Validacao.Api`, que já referencia os dois projetos (linhas 7–8 de `Validacao.Api.csproj`).

### 4. [Leve] Setter público em propriedade que deveria ser mutada só via regra de negócio

**Arquivo:** `src/Validacao/Validacao.Domain/Entities/Embarque.cs`, linha 10

```
public string Status { get; set; } = "PENDENTE";
```

Todas as outras propriedades da entidade (`Id`, `NumeroLogicoCartao`, `OcorridoEm`) têm `private set` e só mudam via método de fábrica (`Registrar`, linha 12–13) ou método de domínio (`Aprovar`, linha 15). `Status` é a exceção: tem setter público, então qualquer código fora da entidade pode fazer `embarque.Status = "APROVADO"` sem passar por `Aprovar()` — e sem as validações que esse método eventualmente ganhe. Não é uma violação de camada (está dentro do próprio Domain), mas é uma quebra do padrão de encapsulamento que o resto da entidade estabelece, e head-de-migração deveria fechar antes de outras entidades copiarem o padrão errado.

Recomendação: `public string Status { get; private set; } = "PENDENTE";`.

## O que NÃO é violação (para não gerar ruído no planning)

- `Validacao.Api` referenciar tanto `Validacao.Application` quanto `Validacao.Infrastructure` (linhas 7–8 de `Validacao.Api.csproj`) é esperado — é o composition root, responsável por montar o DI container.
- `Validacao.Infrastructure` referenciar `Validacao.Domain` e depender do pacote `Microsoft.EntityFrameworkCore.SqlServer` é o lugar correto para essa dependência.
- `Validacao.Domain` referenciar `Validacao.Contracts` é aceitável, desde que `Contracts` continue sem depender de nada (hoje está vazio de dependências — confirmado no `.csproj`).

## Recomendação para o planning

1. Tratar `Legacy.Bilhetagem` como candidato a reescrita guiada por domínio (extrair `Cartao` como entidade pura + `ICartaoRepository`), não como refatoração de camadas existentes — não há camadas para preservar.
2. Corrigir a violação 3 (`Validacao.Application` → `Validacao.Infrastructure`) antes de usar `Validacao` como referência de padrão para o módulo novo de bilhetagem — hoje ela contradiz o próprio modelo que deveria ser copiado.
3. Fechar a violação 4 junto, é mudança de uma linha e evita que o padrão se propague para as próximas entidades.
