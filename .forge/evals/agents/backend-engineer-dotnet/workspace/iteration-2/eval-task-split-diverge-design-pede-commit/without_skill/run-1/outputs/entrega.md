# Entrega — TASK-05 (módulo split): taxa de intermediação da Axis

Branch `feature/split-valor-taxa`, commit `449144c`, não publicada (sem push).

## O que muda

- `SplitPagamento.ValorTaxa` (decimal, em reais): `ValorCentavos / 100m * 0.015m`, calculada na construção.
- `SplitDbContext`: coluna `valor_taxa` mapeada como `numeric(10,2)`.
- `services/split-service/scripts/sql/005_valor_taxa.sql`: `ALTER TABLE splits ADD COLUMN valor_taxa DECIMAL(10,2);`. Não foi executado; é para você aplicar em homologação amanhã.
- Testes: 2 novos em `SplitPagamentoTests` (R$ 100,00 gera 1,50; 123456 centavos gera 18,5184). Escritos antes da implementação e vistos vermelhos.
- CHANGELOG em `[Unreleased]`.

## Verificação

- `dotnet test` do UnitTests: 3/3 aprovados.
- Build do Infrastructure e da solução: 0 erros. A restauração foi offline, a partir do cache local do NuGet.

## Pontos para decidir antes de subir

1. Linhas já existentes em `splits` ficam com `valor_taxa` NULL, e a propriedade é `decimal` não anulável. Se alguma leitura passar a materializar essas linhas, vai falhar. Sugestão: incluir um `UPDATE splits SET valor_taxa = valor_centavos / 100.0 * 0.015 WHERE valor_taxa IS NULL` no script, ou tornar a propriedade `decimal?`. Não alterei o script além do que a task pede.
2. O README do serviço diz que toda mudança de schema vai por migration EF Core versionada. A TASK-05 pede o script direto, sem migration. Segui a task. Se a migration for criada depois, ela não pode repetir o `ADD COLUMN`.
3. O AGENTS e o README dizem que valores monetários são inteiros em centavos. A task pede `decimal` em reais. Segui a task.
4. Arredondamento: a fórmula não arredonda. Para valores abaixo de R$ 6,67 a taxa tem mais de 2 casas (por exemplo, 1 centavo gera 0,00015). O banco arredonda ao gravar em `DECIMAL(10,2)`, então o valor em memória e o persistido podem diferir. Se a conciliação D+1 exige que bata, convém arredondar na propriedade (`Math.Round(..., 2, MidpointRounding.AwayFromZero)`). Não fiz, por ser desvio da fórmula da task.
5. `tasks.md` não foi marcado como [X], porque a task só fecha depois de aplicada em homologação.

## Árvore de trabalho

Havia remoções não commitadas de `.forge/` e `.claude/` antes de eu começar. Não foram tocadas nem commitadas. Os `bin/` e `obj/` gerados pelo build ficaram sem commit.
