# Transcrição — TASK-03 (reajuste de tarifa por percentual)

Papel: backend-engineer-dotnet. Modo standalone: sem commit, push ou tag.

## Passo a passo

1. Leitura do prompt.md e da definição do agente `.forge/agents/engineering/backend-engineer-dotnet.md`.
2. Inspeção do repositório `work`: `git status` mostrava exclusões pré-existentes de `.claude/agents/*` e `.forge/agents/*` no índice de trabalho. Não tocadas.
3. Leitura de `docs/product/modules/tarifa/tasks.md` (TASK-03), `requirements.md` (REQ-004), `design.md` (DD-001, DD-002), `contracts/openapi/tarifa-service.yaml`, e do código de `services/tarifa-service` (Domain, Application, Infrastructure, Api, testes, CHANGELOG, README).
4. Verificação do baseline: `bash .forge/scripts/dotnet-baseline.sh --check` reprovou (faltam Directory.Build.props, .editorconfig, Directory.Packages.props). Decisão: reportar a lacuna, não rodar `--apply`, não desligar regras.
5. Red: escritos os testes de `Reajustar` em `TarifaLinhaTests.cs` antes da implementação. Primeira tentativa de `dotnet test` falhou por falta de `project.assets.json`. Restore offline com `dotnet restore --source ~/.nuget/packages` (sem rede). Após restore, `dotnet test` falhou por erro de compilação CS1061 (`Reajustar` inexistente). Red confirmado.
6. Green: `TarifaLinha.Reajustar(int)` com validação 1 a 5000 bp, cálculo `valor * (10000 + bp) / 10000` em inteiros com `checked`, arredondamento half-even numa única divisão. Record `ReajusteTarifa` no Domain.
7. Application: `ReajustarTarifaHandler` (busca, aplica, salva, devolve resposta ou nulo).
8. Api: rota `POST /v1/tarifas/{linhaId:guid}/reajustes`, 404 para linha inexistente, 422 via catch de `ArgumentOutOfRangeException`.
9. Decisão de implementação: não usei filtro `when (ex.ParamName == nameof(request.PercentualBp))`, porque `nameof` daria "PercentualBp" enquanto o `ParamName` do Domain é "percentualBp". Como o `checked` lança `OverflowException` e não `ArgumentOutOfRangeException`, o catch amplo não mascara outro erro.
10. Contrato OpenAPI atualizado (POST, 200/404/422, schemas). CHANGELOG em Unreleased.
11. Verificação: `dotnet restore Tarifa.sln --source ~/.nuget/packages` (exit 0); `dotnet test Tarifa.sln --no-restore` (9/9 aprovados); `dotnet build Tarifa.Api.csproj --no-restore` (0 avisos, 0 erros); `scan.sh --root services/tarifa-service` (1 achado: `single-impl-interface` em `ITarifaRepository`, pré-existente).
12. Limpeza de bin/ e obj/ gerados pelo build. Entrega escrita em `entrega.md` na raiz de `work`.

## Não feito

- Teste HTTP do endpoint (subir a API e chamar a rota). Sem rede e sem curl nesta execução.
- Marcação `[X]` em `tasks.md`: fica para o orquestrador após validação.
- Commit: sem `commit_policy` no payload.

## Arquivos lidos ou escritos

Lidos: prompt.md, backend-engineer-dotnet.md, docs/product/modules/tarifa/{tasks,requirements,design}.md, contracts/openapi/tarifa-service.yaml, todos os .cs e csproj de services/tarifa-service, CHANGELOG.md, README.md, .forge/scripts/dotnet-baseline.sh (check), scan.sh.

Escritos: services/tarifa-service/src/Tarifa.Domain/TarifaLinha.cs (editado), services/tarifa-service/src/Tarifa.Domain/ReajusteTarifa.cs (novo), services/tarifa-service/src/Tarifa.Application/ReajustarTarifaHandler.cs (novo), services/tarifa-service/src/Tarifa.Api/Program.cs (editado), services/tarifa-service/tests/Tarifa.UnitTests/TarifaLinhaTests.cs (editado), contracts/openapi/tarifa-service.yaml (editado), services/tarifa-service/CHANGELOG.md (editado), entrega.md (novo, raiz de work).

Logs em tmp/: test-red.log, test-green.log, build-api.log, scan.log, restore*.log.
