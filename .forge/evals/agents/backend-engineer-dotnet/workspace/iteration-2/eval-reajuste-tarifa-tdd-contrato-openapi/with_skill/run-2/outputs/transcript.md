# Transcrição — TASK-03 tarifa (reajuste por percentual)

1. Li o prompt e a definição de `backend-engineer-dotnet` integralmente.
2. Li `docs/product/modules/tarifa/{tasks,requirements,design}.md`, `contracts/openapi/tarifa-service.yaml` e o código do tarifa-service (Api, Application, Domain, Infrastructure, teste unitário), além de README, CHANGELOG e csproj.
3. Verifiquei `dotnet` (10.0.107) e rodei `dotnet-baseline.sh --check`: reprovou por ausência de `Directory.Build.props`, `.editorconfig` e `Directory.Packages.props`. Não apliquei `--apply`; reportei a lacuna.
4. `dotnet test` sem restore falhou (NETSDK1004, sem project.assets.json). Rede proibida, então restaurei offline com `dotnet restore Tarifa.sln --source ~/.nuget/packages`. Restaurou os 5 projetos.
5. Baseline: 1 teste aprovado.
6. Red: acrescentei em `TarifaLinhaTests.cs` os testes do exemplo 1 (430 → 484), do empate (420 → 472) e da faixa inválida (0, -1, 5001). Compilação falhou por `Reajustar` ausente (CS1061).
7. Green: `TarifaLinha.Reajustar(int)` com validação 1..5000 e half-even em aritmética inteira; record `ReajusteTarifa` em arquivo próprio. Suíte: 6 aprovados.
8. Criei `ReajustarTarifaHandler` (Application) e `POST /v1/tarifas/{linhaId}/reajustes` em `Program.cs`, com 404 quando a linha não existe e 422 mapeado de `ArgumentOutOfRangeException`. Build sem erros e sem avisos.
9. `dotnet-quality-scan`: único achado é `single-impl-interface` em `ITarifaRepository`, pré-existente; não alterado.
10. Atualizei `contracts/openapi/tarifa-service.yaml` (path, schemas, 200/404/422) e validei o parse com PyYAML.
11. Atualizei o CHANGELOG em `[Unreleased]`.
12. Escrevi `entrega.md` na raiz do repositório de trabalho.
13. Removi bin/obj criados pelos builds. Não fiz commit. Não marquei TASK-03 no tracker.
14. Decisões: regra de domínio no agregado e conversão para 422 na Api; reajuste como aumento (valor × (10000 + bp) / 10000), coerente com os exemplos.
15. Não exercitei o endpoint por HTTP (sem rede e sem teste de API). Lacuna: o repositório in-memory não tem como cadastrar tarifas, então o endpoint só responde 404 na prática.
