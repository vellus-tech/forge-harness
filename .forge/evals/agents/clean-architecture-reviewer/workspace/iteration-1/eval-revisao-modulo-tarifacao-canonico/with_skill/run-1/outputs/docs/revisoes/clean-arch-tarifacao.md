# Revisão de Clean Architecture — módulo Tarifacao

Revisor: `clean-architecture-reviewer`. Escopo: `src/Tarifacao/{Tarifacao.Api,Tarifacao.Application,Tarifacao.Domain,Tarifacao.Infrastructure,Tarifacao.Contracts}`, extraído no formato canônico antes da abertura do PR para `develop`.

## Resumo executivo

O módulo segue corretamente o formato de projetos (`Api`/`Application`/`Domain`/`Infrastructure`/`Contracts`) e as referências entre `.csproj` estão de acordo com a regra de dependência esperada (`Application` só referencia `Domain`+`Contracts`; `Infrastructure` referencia `Application`+`Domain`; `Api` referencia `Application`+`Infrastructure`). Ainda assim, há quatro violações que precisam ser corrigidas antes do PR: o `Domain` depende diretamente do SDK da AWS (pacote, `using` e atributo de mapeamento), a regra de negócio do desconto de integração está implementada no Handler de `Application` em vez de estar encapsulada na entidade de domínio, o repositório carrega prefixo de tecnologia no nome (`DynamoTarifaRepository`) e o evento de domínio está nomeado no infinitivo em vez do passado.

## Achados

### 1. `Domain` depende do SDK da AWS (violação crítica — camada de domínio acoplada a infraestrutura)

- `src/Tarifacao/Tarifacao.Domain/Tarifacao.Domain.csproj:7` — `<PackageReference Include="AWSSDK.DynamoDBv2" Version="3.7.300" />`: o projeto de domínio não deveria ter nenhuma dependência de infraestrutura/persistência, nem via `PackageReference`.
- `src/Tarifacao/Tarifacao.Domain/Entities/Tarifa.cs:1` — `using Amazon.DynamoDBv2.DataModel;`: import proibido em `Domain` (regra explícita do checklist: nada de `Amazon.DynamoDBv2` em arquivos de Domain).
- `src/Tarifacao/Tarifacao.Domain/Entities/Tarifa.cs:5` — `[DynamoDBTable("tarifas")]`: atributo de mapeamento do Dynamo aplicado diretamente na entidade de domínio; o mapeamento de persistência é responsabilidade de `Infrastructure`, não de `Domain`.

Correção sugerida: mover a `PackageReference` do Dynamo e o atributo `[DynamoDBTable]` para `Tarifacao.Infrastructure` (ex.: um modelo de persistência próprio em `Infrastructure/Persistence/Models/TarifaRecord.cs`, convertido de/para `Tarifa` dentro do repositório), deixando `Tarifa` em `Domain` livre de qualquer referência a SDK externo.

### 2. Regra de negócio do desconto de integração está no Handler de Application, não na entidade de Domain

- `src/Tarifacao/Tarifacao.Application/Handlers/CalcularTarifaIntegracaoHandler.cs:14-22`:
  ```
  var minutos = (agora - embarqueAnterior).TotalMinutes;
  if (minutos <= 120 && modalAnterior != tarifa.Modal)
  {
      return tarifa.ValorCentavos * 75 / 100;
  }
  else
  {
      return tarifa.ValorCentavos;
  }
  ```
  Este é exatamente o if/else de regra de negócio que o checklist veda em Handlers de Application — a regra "25% de desconto se o segundo embarque for em outro modal dentro de 120 minutos" é a invariante central do módulo de tarifação e deveria viver em `Tarifacao.Domain`, não no Handler.

Correção sugerida: mover o cálculo para um método de domínio, por exemplo `Tarifa.CalcularValorIntegracao(string modalAnterior, DateTime embarqueAnterior, DateTime agora)` em `Tarifacao.Domain/Entities/Tarifa.cs`, com o Handler reduzido a orquestrar: buscar a tarifa no repositório e chamar o método de domínio.

### 3. Nome do repositório carrega prefixo de tecnologia

- `src/Tarifacao/Tarifacao.Infrastructure/Persistence/Repositories/DynamoTarifaRepository.cs:7` — `public sealed class DynamoTarifaRepository : ITarifaRepository`: o checklist de nomenclatura veda prefixo de tecnologia em nomes de classe, com o exemplo literal `DynamoFooRepository` → `FooRepository`. O uso do prefixo aqui repete exatamente o anti-pattern citado.
- Reflexo do mesmo nome em `src/Tarifacao/Tarifacao.Api/Program.cs:3` (`using Tarifacao.Infrastructure.Persistence.Repositories;`) e `Program.cs:6` (`builder.Services.AddScoped<ITarifaRepository, DynamoTarifaRepository>();`).

Correção sugerida: renomear a classe para `TarifaRepository` (o namespace `Tarifacao.Infrastructure.Persistence.Repositories` já deixa claro que é uma implementação de infraestrutura; não é preciso repetir a tecnologia no nome da classe).

### 4. Evento de domínio nomeado no infinitivo, não no passado

- `src/Tarifacao/Tarifacao.Domain/Events/CalcularTarifaIntegracao.cs:3` — `public sealed record CalcularTarifaIntegracao(Guid TarifaId, long ValorCentavos, DateTime OcorridoEm);`: o checklist exige eventos de domínio nomeados no passado (exemplo dado: `TransactionApproved`, não `ApproveTransaction`). `CalcularTarifaIntegracao` está no infinitivo ("calcular"), lendo como um comando, não como um fato ocorrido.

Correção sugerida: renomear para algo como `TarifaIntegracaoCalculada` (ou `TarifaDeIntegracaoAplicada`), mantendo os mesmos campos.

**Observação à parte (não é violação de camada, mas vale registrar):** este evento não é publicado em lugar nenhum do módulo — `CalcularTarifaIntegracaoHandler` não o instancia nem o despacha. Se a intenção é ter rastreabilidade/observabilidade do desconto aplicado, falta a publicação do evento (ex.: via `IPublisher` injetado no Handler ou no método de domínio, após mover a regra para lá).

## Itens conferidos e sem violação

- `Tarifacao.Domain.csproj` não tem `<ProjectReference>` para nenhum outro projeto do módulo — conforme.
- `Tarifacao.Application.csproj` referencia apenas `Domain` e `Contracts` — conforme.
- `Tarifacao.Infrastructure.csproj` referencia `Application` e `Domain` — conforme (é o padrão esperado, não confundir com "Infrastructure não pode depender de Application": neste formato canônico a dependência é esperada, para permitir DI/composição a partir de `Infrastructure` quando aplicável).
- `Tarifacao.Api.csproj` referencia `Application` e `Infrastructure`, e `Program.cs` só usa essas referências para registro de DI (`AddScoped`) e mapeamento de rota — conforme.
- `Tarifa` (`Tarifacao.Domain/Entities/Tarifa.cs`) tem construtor privado (linha 8) e factory estática `Criar` (linha 15) — conforme.
- Propriedades de `Tarifa` são `{ get; private set; }` — sem setters públicos de estado — conforme.
- `ITarifaRepository` está em `Domain/Repositories/` e a implementação está em `Infrastructure/Persistence/Repositories/` — conforme.
- `ITarifaRepository` não expõe tipos de EF Core nem do AWS SDK na assinatura (só `Tarifa`, `string`, `CancellationToken`) — conforme.

## Recomendação

Não abrir o PR para `develop` antes de resolver os achados 1 e 2 (acoplamento de `Domain` ao SDK da AWS e regra de negócio fora do `Domain`) — são violações estruturais da Dependency Rule e do local da lógica de negócio, o coração do que este módulo precisa garantir. Os achados 3 e 4 são de nomenclatura, corrigíveis junto com os anteriores no mesmo PR sem risco adicional. Não há necessidade de escalar para `ddd-validator` ou `adr-writer`: as quatro violações são correções mecânicas dentro do padrão já adotado, não divergências estruturais do módulo nem decisões arquiteturais novas.
