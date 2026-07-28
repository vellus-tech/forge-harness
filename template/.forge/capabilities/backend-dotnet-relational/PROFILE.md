---
id: backend-dotnet-relational
version: 1
applies_to:
  - dotnet
  - relational-database
status: experimental
---

# Backend C#/.NET relacional

Use para áreas C#/.NET que persistem em banco relacional. Antes de aplicar, leia os ADRs e o código vizinho; a solução existente vence qualquer preferência deste pack.

## Defaults condicionais

- Para projetos novos, use versão LTS do SDK disponível, nullable reference types, injeção por construtor, `CancellationToken` propagado e `ProblemDetails` para erros HTTP. Não introduza esses padrões em brownfield sem task/ADR que os justifique.
- EF Core migrations devem ser revisadas como parte do diff. Em arquitetura hexagonal, entidade de domínio, modelo de persistência e mapper podem ser separados; em monólito em camadas, não crie a separação sem benefício demonstrável.
- Valide payloads na borda. O tipo C# não substitui validação de entrada. Autorização de recurso exige checagem de ownership quando aplicável e teste negativo contra acesso alheio.
- Para dinheiro, `money-as-cents.md` prevalece: `long` em centavos e `BIGINT`, nunca `decimal` como regra de domínio. `decimal` em mapeamento de coluna só é permitido por ADR que documente unidade, precisão e arredondamento.

## Verificação

Rode os comandos declarados em `FORGE.md`; na ausência deles, proponha `dotnet build` e `dotnet test` sem executá-los se o ambiente não estiver preparado. Para mudança de schema, aplique `data/schema-evolution.md`. Para API, teste contrato HTTP e autorização. Para domínio, aplique TDD e PBT quando houver propriedades matemáticas.

## Não fazer

- Não usar `latest` como versão de pacote ou imagem.
- Não ativar Docker, banco, migration ou instalação de ferramenta sem autorização operacional.
- Não bloquear uma mudança somente porque ela não usa EF Core, `ProblemDetails` ou uma arquitetura específica; o contrato existente governa.
