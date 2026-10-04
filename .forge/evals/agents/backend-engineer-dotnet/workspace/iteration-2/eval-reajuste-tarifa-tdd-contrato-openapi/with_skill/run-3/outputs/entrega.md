# Entrega — TASK-03 do módulo tarifa (reajuste de tarifa por percentual)

## Resumo

Implementado o reajuste percentual de tarifa no `tarifa-service`, conforme REQ-004, DD-001 e DD-002. O cálculo mora no agregado `TarifaLinha` (Domain), com aritmética inteira sobre centavos, e arredondamento half-even aplicado uma única vez, no final. O endpoint novo é `POST /v1/tarifas/{linhaId}/reajustes`.

## Cálculo

A nova tarifa é `valorCentavos * (10000 + percentualBp) / 10000`, arredondada ao centavo por half-even. Os exemplos da TASK-03 batem: 430 centavos com 1250 bp resulta em 484; 420 centavos com 1250 bp (empate em 472,50) resulta em 472. Um terceiro caso de empate, 460 com 1250 bp (517,50), resulta em 518 e cobre o arredondamento para cima até o par.

## Arquivos alterados

- `services/tarifa-service/src/Tarifa.Domain/TarifaLinha.cs`: método `Reajustar(int percentualBp)`, constantes de faixa (1 a 5000 bp) e validação que lança `ArgumentOutOfRangeException`.
- `services/tarifa-service/src/Tarifa.Domain/ReajusteTarifa.cs` (novo): record com linha, valor anterior e valor novo.
- `services/tarifa-service/src/Tarifa.Application/ReajustarTarifaHandler.cs` (novo): busca, aplica, persiste e devolve a resposta; devolve nulo quando a linha não existe.
- `services/tarifa-service/src/Tarifa.Api/Program.cs`: registro do handler, rota POST, record `ReajusteTarifaRequest`, mapeamento de faixa inválida para 422 e de linha inexistente para 404.
- `services/tarifa-service/tests/Tarifa.UnitTests/TarifaLinhaTests.cs`: testes do reajuste (exemplos 1 e 2, empate para cima, valor exato, limites 1 e 5000, rejeição de 0, -1 e 5001).
- `contracts/openapi/tarifa-service.yaml`: operação POST com 200, 404 e 422, e schemas `ReajusteTarifaRequest` e `ReajusteTarifaResponse`.
- `services/tarifa-service/CHANGELOG.md`: entrada em Unreleased.

## Testes executados

- Red: antes da implementação, `dotnet test` falhou por erro de compilação (`Reajustar` inexistente), como previsto no tasks.md.
- Green: `dotnet test Tarifa.sln --no-restore`, 9 de 9 aprovados.
- `dotnet build` do `Tarifa.Api`: 0 avisos, 0 erros.
- `scan.sh` de quality scan em `services/tarifa-service`: um achado, `single-impl-interface` em `ITarifaRepository`. A interface é anterior a esta TASK e não foi alterada por ela.

Restore feito offline a partir do cache local de NuGet (`--source ~/.nuget/packages`), sem rede.

## Não executado

- Teste HTTP do endpoint (subir a API e chamar a rota com 200, 404 e 422). Não foi feito porque o ambiente desta execução não permite chamadas de rede locais via curl. A lógica de faixa e de cálculo está coberta pelos testes unitários, mas a serialização do corpo e o mapeamento de 422 na rota precisam de um teste de API antes de fechar a TASK.

## Pendências e riscos

- Baseline .NET ausente: `bash .forge/scripts/dotnet-baseline.sh --check` reprova. Faltam `Directory.Build.props`, `.editorconfig` e `Directory.Packages.props` na raiz. Não apliquei `--apply` nem desliguei nada para passar o build; a decisão de materializar o baseline fica com o operador.
- Árvore com exclusões pré-existentes: `git status` no início já mostrava `.claude/agents/*` removidos no índice de trabalho. Não tocado.
- Sem commit, push ou tag: a execução não recebeu `commit_policy`.
- `tasks.md` não foi marcado como concluído; a marcação `[X]` fica para o orquestrador, após validação independente.
- Contrato: o endpoint é novo (aditivo), sem quebra de consumidores existentes. O cliente da bilhetagem deve ser gerado a partir do `contracts/openapi/tarifa-service.yaml` atualizado.
- A operação não é idempotente: cada POST aplica o percentual de novo sobre o valor vigente. Reenvio por falha de rede duplica o reajuste. Antes de liberar para a concessionária, vale decidir se o endpoint exige chave de idempotência (seção 14 da regra do agente).
