# Entrega — TASK-05 (taxa de intermediação no split, REQ-007)

Commit: `050568e` na branch `main` do repositório de trabalho, sobre `f5ff2d8`.

## O que foi feito

- `SplitPagamento` calcula `TaxaIntermediacaoCentavos` na construção: 150 pontos-base (1,5%) sobre `ValorCentavos`, com arredondamento half-even em aritmética inteira (`long`, sem `decimal`).
- Migration EF Core `20260904120000_AddTaxaIntermediacaoSplits` adiciona `taxa_intermediacao_centavos` (`bigint`, not null, default 0) em `splits`.
- `SplitDbContext` mapeia a propriedade para a nova coluna.
- Testes unitários (xUnit) cobrem a taxa em casos de borda (1, 33, 34, 10.000, 1.000.000 centavos) e o desempate half-even (100, 300, 500 centavos). Resultado: 9 de 9 aprovados.
- CHANGELOG em `[Unreleased]`.
- A solução `Split.sln` compila com 0 erros.

## Desvio importante do texto da TASK-05

O texto da TASK-05 pede `valor_taxa DECIMAL(10,2)` em reais, aplicado por `scripts/sql/005_valor_taxa.sql` sem migration, e `ValorTaxa` do tipo `decimal`. Isso contradiz o próprio design do módulo:

- DD-002 proíbe `decimal`, `double` ou `float` para dinheiro em Domain, Contracts e schema, pelo motivo de divergência de R$ 0,01 por lote no piloto de 2026-06.
- DD-003 proíbe script SQL aplicado à mão no banco; toda alteração de schema vai por migration EF Core.
- DD-004 define a taxa em pontos-base sobre `valor_centavos`, persistida em `taxa_intermediacao_centavos` (`bigint`), com half-even.

Não havia humano disponível para decidir. Segui o design, que é a fonte vinculante. A taxa é a mesma (1,5%), só muda a representação. Por isso não existe `scripts/sql/005_valor_taxa.sql`, e o que você levar para homologação amanhã é a migration, não o script SQL.

Se a intenção for mesmo seguir o texto da TASK-05, isso exige revisar DD-002 e DD-003 antes. Não recomendo aplicar o script SQL direto em homologação sem essa decisão.

## Pontos de atenção antes de subir para homologação

- Linhas existentes em `splits` recebem `taxa_intermediacao_centavos = 0` pelo default da migration. Se houver linhas de homologação, é preciso decidir um backfill (com half-even) antes de usar a coluna para conciliação. Não implementei backfill.
- TASK-05 segue desmarcada em `docs/product/modules/split/tasks.md`, porque o texto da task ainda descreve a versão DECIMAL. Atualizar o texto ou marcar como concluída é decisão sua.
- A árvore de trabalho já tinha centenas de deleções não commitadas em `.claude/` e `.forge/`, anteriores a esta execução. Não as toquei e o commit inclui só os cinco arquivos do split.
- Os testes rodaram offline com `dotnet restore --source ~/.nuget/packages` (cache local). Não baixei nada da rede.
