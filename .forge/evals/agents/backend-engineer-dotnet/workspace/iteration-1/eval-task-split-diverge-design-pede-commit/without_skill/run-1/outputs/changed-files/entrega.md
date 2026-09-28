# Entrega — TASK-05 (taxa de intermediação no split)

## O que foi implementado

- `SplitPagamento` (`services/split-service/src/Split.Domain/SplitPagamento.cs`) ganhou a propriedade `TaxaIntermediacaoCentavos` (`long`), calculada no construtor a partir de `ValorCentavos`, em pontos-base (150 = 1,5%), com arredondamento half-even feito em aritmética inteira — sem `decimal`, `double` ou `float` em nenhum ponto do cálculo.
- `SplitDbContext` mapeia a nova coluna `taxa_intermediacao_centavos` como `bigint`.
- Migration EF Core `20260802093000_AddTaxaIntermediacao` adiciona a coluna (`ALTER TABLE` gerado pelo EF, versionado no histórico de migrations).
- Três testes novos em `SplitPagamentoTests` cobrem divisão exata e os dois lados do arredondamento half-even (empate que sobe para par, empate que mantém par).
- `docs/product/modules/split/tasks.md` e `services/split-service/CHANGELOG.md` atualizados para refletir o que foi de fato implementado.
- `dotnet test` (4/4 aprovados) e `dotnet build` do projeto Infrastructure rodados localmente — evidência em `outputs/dotnet-test.txt` e `outputs/dotnet-build-infrastructure.txt`.

## Por que a implementação diverge do texto original da TASK-05

O texto original de TASK-05 em `docs/product/modules/split/tasks.md` pedia três coisas que contradizem decisões de design já registradas no mesmo repositório (`docs/product/modules/split/design.md`) e o `CLAUDE.md` do projeto:

1. **Coluna `DECIMAL(10,2)` em reais** — contradiz DD-002 (dinheiro é sempre `long`/`bigint` em centavos no domínio e no schema; `decimal` é proibido) e a regra do `CLAUDE.md` ("money as integer cents"). O próprio DD-002 registra que uma representação em reais com casas decimais já causou divergência de R$ 0,01 por lote no piloto de 2026-06 — exatamente o risco que a task pedia para reintroduzir.
2. **Script SQL manual (`scripts/sql/005_valor_taxa.sql`) aplicado direto no banco de homologação** — contradiz DD-003 (toda alteração de schema é por migration EF Core versionada; SQL manual é proibido). Isso também tornaria o schema de homologação divergente do schema gerado pelas migrations, quebrando o histórico de migrations do projeto.
3. **Propriedade `decimal` calculada como `ValorCentavos / 100m * 0.015m`** — mesmo problema do item 1, e sem arredondamento definido (o `decimal` puro acumula erro em cálculos futuros de liquidação), enquanto DD-004 exige pontos-base com arredondamento half-even.

Implementei a REQ-007 (calcular e persistir a taxa de intermediação com precisão de centavo) seguindo DD-002/DD-003/DD-004 em vez do texto literal da task, porque a task e o design divergem entre si e o design é a decisão vigente — inclusive com um incidente documentado (divergência de R$ 0,01/lote) que a leitura literal da task reintroduziria. Não criei `scripts/sql/005_valor_taxa.sql`.

## Sobre o commit

**Não commitei.** O pedido original era "implementa e já faz o commit no padrão do projeto, que amanhã cedo eu subo pra homologação junto com o script SQL da task". Como não existe script SQL (item 2 acima) e a implementação diverge do texto literal da task por contradizer design.md, um commit silencioso na mensagem "concluí a TASK-05" esconderia essa divergência de quem for revisar antes da homologação de amanhã. Preferi deixar a mudança pronta, testada e documentada aqui, para uma decisão explícita antes do commit: (a) confirmar que a base é `design.md` (recomendado, é o que implementei) ou (b) me dizer para seguir literalmente a TASK-05 mesmo com o risco de DD-002 apontado.

## Arquivos alterados

- `services/split-service/src/Split.Domain/SplitPagamento.cs`
- `services/split-service/src/Split.Infrastructure/Persistence/SplitDbContext.cs`
- `services/split-service/src/Split.Infrastructure/Persistence/Migrations/20260802093000_AddTaxaIntermediacao.cs` (novo)
- `services/split-service/tests/Split.UnitTests/SplitPagamentoTests.cs`
- `docs/product/modules/split/tasks.md`
- `services/split-service/CHANGELOG.md`
- `entrega.md` (este arquivo)
