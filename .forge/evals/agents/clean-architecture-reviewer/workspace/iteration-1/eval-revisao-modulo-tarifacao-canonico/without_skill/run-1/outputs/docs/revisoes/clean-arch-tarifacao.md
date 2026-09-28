# Revisão de Clean Architecture — módulo Tarifacao (tarifação de integração)

Data: 2026-09-28
Escopo: `src/Tarifacao/{Tarifacao.Api, Tarifacao.Application, Tarifacao.Domain, Tarifacao.Infrastructure, Tarifacao.Contracts}`

## Achados

### 1. Domain depende de infraestrutura (AWS SDK) — violação de dependência
`src/Tarifacao/Tarifacao.Domain/Entities/Tarifa.cs:1` importa `Amazon.DynamoDBv2.DataModel`, e `src/Tarifacao/Tarifacao.Domain/Entities/Tarifa.cs:5` decora a entidade com `[DynamoDBTable("tarifas")]`. O `.csproj` do Domain reforça isso: `src/Tarifacao/Tarifacao.Domain/Tarifacao.Domain.csproj:7` referencia o pacote `AWSSDK.DynamoDBv2`. Em Clean Architecture, o Domain é o núcleo e não pode conhecer o mecanismo de persistência — quem sabe que a tarifa é salva em DynamoDB é a Infrastructure. Hoje, trocar o banco (ex. Postgres) exige alterar a entidade de domínio. Correção: mover o atributo `[DynamoDBTable]` e a dependência do pacote para um modelo de persistência próprio em `Tarifacao.Infrastructure` (ex. `TarifaRecord`), mapeando para `Tarifa` no repositório.

### 2. Regra de negócio (desconto de integração) fora do Domain
A regra "25% de desconto se o segundo embarque for em outro modal dentro de 120 minutos" está implementada inteiramente no handler de aplicação, em `src/Tarifacao/Tarifacao.Application/Handlers/CalcularTarifaIntegracaoHandler.cs:14-22`, operando sobre primitivos (`DateTime`, `string`) em vez de expressar a regra como comportamento da entidade `Tarifa`. `src/Tarifacao/Tarifacao.Domain/Entities/Tarifa.cs` só expõe getters e o factory `Criar` (linhas 15-19); não há método como `CalcularValorIntegracao(modalAnterior, minutosDesdeEmbarqueAnterior)`. Isso é modelo anêmico: a regra de negócio, que é a razão de existir do módulo, vive na camada de orquestração (Application) e não pode ser reutilizada nem testada isoladamente a partir do Domain. Correção: mover o cálculo do desconto para um método da entidade `Tarifa` (ou de um serviço de domínio, se a regra depender de mais de uma entidade), e reduzir o handler a orquestrar repositório + chamada a esse método.

### 3. `Tarifacao.Contracts` existe mas não é usado
`src/Tarifacao/Tarifacao.Contracts/Tarifacao.Contracts.csproj` não contém nenhuma classe (nenhum arquivo `.cs` no projeto), embora `Tarifacao.Application` o referencie (`src/Tarifacao/Tarifacao.Application/Tarifacao.Application.csproj:8`). O endpoint em `src/Tarifacao/Tarifacao.Api/Program.cs:10-11` retorna o `long` cru do handler diretamente via `Results.Ok`, sem DTO de contrato. No formato canônico Api/Application/Domain/Infrastructure/Contracts, `Contracts` deveria carregar os DTOs de entrada/saída da API (ex. `TarifaIntegracaoResponse`), desacoplando o formato de resposta do tipo de retorno interno do handler. Hoje o projeto é código morto e a API vaza um tipo primitivo em vez de um contrato estável. Correção: definir os DTOs de request/response em `Tarifacao.Contracts` e fazer o handler (ou um mapeamento no endpoint) retornar esse tipo.

### 4. Evento de domínio declarado mas nunca disparado
`src/Tarifacao/Tarifacao.Domain/Events/CalcularTarifaIntegracao.cs:3` define o record `CalcularTarifaIntegracao`, mas nenhum arquivo do módulo o instancia ou publica — nem o handler (`CalcularTarifaIntegracaoHandler.cs`) nem o repositório (`DynamoTarifaRepository.cs`) fazem uso dele. Isso indica ou uma intenção arquitetural (side-effect de auditoria/integração) que não foi implementada, ou código morto que deveria ser removido antes do PR. Correção: decidir explicitamente — implementar a publicação do evento após o cálculo bem-sucedido, ou remover o arquivo se não fizer parte do escopo desta extração.

### 5. Referências entre `.csproj` — direção correta, mas acoplamento indevido pelo achado 1
As referências de projeto seguem a direção esperada por Clean Architecture: `Tarifacao.Api.csproj` (linhas 7-8) referencia Application e Infrastructure; `Tarifacao.Application.csproj` (linhas 7-8) referencia Domain e Contracts; `Tarifacao.Infrastructure.csproj` (linhas 7-9) referencia Application e Domain. Nenhum projeto interno referencia o Api, e o Domain não referencia Application/Infrastructure/Api via `ProjectReference`. O único desvio da regra "dependências apontam para dentro" é o `PackageReference` de infraestrutura dentro do Domain (achado 1) — que é uma dependência de pacote, não de projeto, mas viola o mesmo princípio.

### 6. `DynamoTarifaRepository.ObterPorLinhaAsync` usa `linha` como chave de partição sem validação de contrato
`src/Tarifacao/Tarifacao.Infrastructure/Persistence/Repositories/DynamoTarifaRepository.cs:13-14` chama `_contexto.LoadAsync<Tarifa?>(linha, ct)`, assumindo implicitamente que `Linha` é a chave primária da tabela DynamoDB — mas isso não está declarado em lugar nenhum (não há atributo de chave em `Tarifa.cs`, que só declara `[DynamoDBTable]` sem `[DynamoDBHashKey]` explícito na propriedade `Linha` ou `Id`). Isso é mais um risco de infraestrutura do que uma violação de Clean Architecture, mas vale registrar: o `Id` (Guid) parece ser a chave natural pelo padrão de nomenclatura da entidade, e não `Linha`. Correção: confirmar a chave de partição pretendida e declará-la explicitamente com atributos do SDK na camada de Infrastructure (fora do Domain, ver achado 1).

## Resumo

| # | Achado | Severidade | Arquivo:linha |
|---|--------|-----------|----------------|
| 1 | Domain depende do AWS SDK (DynamoDB) | Alta | `Tarifacao.Domain/Entities/Tarifa.cs:1,5`; `Tarifacao.Domain/Tarifacao.Domain.csproj:7` |
| 2 | Regra de desconto de integração fora do Domain (modelo anêmico) | Alta | `Tarifacao.Application/Handlers/CalcularTarifaIntegracaoHandler.cs:14-22` |
| 3 | `Tarifacao.Contracts` vazio; API retorna tipo primitivo em vez de DTO | Média | `Tarifacao.Contracts/Tarifacao.Contracts.csproj`; `Tarifacao.Api/Program.cs:10-11` |
| 4 | Evento de domínio declarado e nunca publicado | Média | `Tarifacao.Domain/Events/CalcularTarifaIntegracao.cs:3` |
| 5 | Direção das referências entre `.csproj` está correta (nenhuma ação) | Informativo | `Tarifacao.Api.csproj:7-8`; `Tarifacao.Application.csproj:7-8`; `Tarifacao.Infrastructure.csproj:7-9` |
| 6 | Chave de partição do DynamoDB não declarada explicitamente | Baixa | `Tarifacao.Infrastructure/Persistence/Repositories/DynamoTarifaRepository.cs:13-14` |

## Recomendação antes de abrir o PR

Bloquear o PR até os achados 1 e 2 (severidade alta) serem corrigidos: o vazamento do AWS SDK para o Domain e a regra de negócio fora da entidade são as duas violações centrais de Clean Architecture neste módulo. Os achados 3 e 4 (média) devem ser resolvidos ou explicitamente adiados com justificativa no PR. O achado 6 (baixa) é uma observação de infraestrutura, não bloqueante.
