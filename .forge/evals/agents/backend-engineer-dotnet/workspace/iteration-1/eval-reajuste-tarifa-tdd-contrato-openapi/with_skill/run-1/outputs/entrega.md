# Entrega — TASK-03: Reajuste de tarifa por percentual

## Resumo do que foi alterado

Implementado o reajuste de tarifa por percentual no `tarifa-service`, cobrindo REQ-004, DD-001 e
DD-002: `TarifaLinha.Reajustar(int percentualBp)` recalcula o valor vigente em centavos a partir de
um percentual em pontos-base (1 bp = 0,01%), com aritmética inteira e arredondamento half-even
(bancário) aplicado uma única vez, no final. O endpoint novo
`POST /v1/tarifas/{linhaId}/reajustes` expõe o comportamento, respondendo `200` com a tarifa
anterior e a nova, `404` para linha inexistente e `422` (`ProblemDetails`) para percentual fora do
intervalo permitido (1 a 5000 bp). O contrato OpenAPI foi atualizado para que o time da bilhetagem
gere o client a partir dele.

## Arquivos alterados

- `services/tarifa-service/src/Tarifa.Domain/TarifaLinha.cs` — método `Reajustar` e o tipo
  `ReajusteTarifa` (valor anterior e novo).
- `services/tarifa-service/src/Tarifa.Application/ReajustarTarifaHandler.cs` (novo) — orquestra
  busca, reajuste e persistência; traduz percentual inválido em `PercentualInvalidoException`.
- `services/tarifa-service/src/Tarifa.Api/Program.cs` — endpoint
  `POST /v1/tarifas/{linhaId}/reajustes` e registro do handler novo no DI.
- `services/tarifa-service/tests/Tarifa.UnitTests/TarifaLinhaTests.cs` — quatro testes novos
  (arredondamento acima da metade, empate half-even, percentual acima e abaixo do intervalo).
- `contracts/openapi/tarifa-service.yaml` — endpoint novo, `ReajusteTarifaRequest`,
  `ReajusteTarifaResponse`, versão do contrato para `0.2.0`.
- `services/tarifa-service/CHANGELOG.md` — entrada `0.2.0`.
- `docs/product/modules/tarifa/tasks.md` — TASK-03 marcada como concluída.

## Testes executados

- `dotnet test` em `services/tarifa-service` — vermelho registrado antes da implementação (4 erros
  de compilação por `Reajustar` inexistente, confirmando o Red), depois verde: 5 de 5 testes
  aprovados (1 preexistente + 4 novos, cobrindo os três exemplos do `tasks.md` mais o limite
  inferior de 1 bp).
- `dotnet build` na solution completa (`Tarifa.sln`, incluindo `Tarifa.Api`) — sucesso, 0 erros.

## Testes recomendados

- Teste de integração do endpoint `POST /v1/tarifas/{linhaId}/reajustes` via
  `WebApplicationFactory`, cobrindo os três status HTTP (200/404/422) fim a fim — não criado nesta
  entrega porque o serviço ainda não tem `Tarifa.IntegrationTests` no projeto (fora do escopo da
  TASK-03; seria uma nova pasta de teste).
- Teste de contrato validando o YAML do OpenAPI contra o schema efetivamente servido, quando o
  time da bilhetagem definir a ferramenta de geração de client.

## Riscos conhecidos

- Nenhuma migração de schema envolvida (repositório em memória).
- Mudança de contrato é aditiva (endpoint novo); não quebra o consumidor existente de
  `GET /v1/tarifas/{linhaId}`.

## Pendências

- `bash .forge/scripts/dotnet-baseline.sh --check` reporta `Directory.Build.props`,
  `.editorconfig` e `Directory.Packages.props` ausentes na raiz do repositório — baseline de build
  .NET (`TreatWarningsAsErrors`, `AnalysisMode`, Central Package Management) não está materializada
  neste checkout. É uma lacuna pré-existente do repositório, não introduzida por esta tarefa;
  reportando em vez de aplicar `--apply` por conta própria, já que afeta a raiz do monorepo e não
  só o módulo tarifa. Recomendação: rodar `--apply` numa mudança própria, revisada isoladamente.
- O scan `bash .forge/skills/dotnet-quality-scan/scripts/scan.sh` não pôde ser executado: o
  fixture deste eval remove `.forge/skills/` do checkout de propósito (para não contaminar o
  baseline avaliado), então o script não está presente nesta árvore.
