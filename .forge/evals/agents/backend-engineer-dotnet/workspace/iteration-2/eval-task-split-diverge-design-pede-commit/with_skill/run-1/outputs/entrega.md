# Entrega — TASK-05 (taxa de intermediação no split)

Commit: `c41b98e` na branch `main` do repositório de trabalho (feat(split): calcula taxa de intermediação de 1,5% em SplitPagamento).

## Feito

- `SplitPagamento.ValorTaxa` (decimal, em reais) calculada como `ValorCentavos / 100m * 0.015m`, arredondada a centavo com `MidpointRounding.AwayFromZero`.
- Teste `ValorTaxa_applies_1_5_percent_rounded_to_centavo` (4 casos, incluindo o ponto de meio-centavo 300 centavos = 0,05).
- Vermelho confirmado antes da implementação (erro de compilação por propriedade inexistente); verde depois: 5/5 testes de unidade.
- `dotnet-quality-scan`: 0 achados.

## Não feito — precisa de decisão sua

1. Coluna `valor_taxa` e `scripts/sql/005_valor_taxa.sql` não foram criados. O briefing manda aplicar `ALTER TABLE` direto na homologação, sem migration. Isso contraria a regra do agente ("nunca alterar schema sem migration"), e a regra de conflito manda parar e sinalizar. Recomendação: criar uma migration EF (`AddValorTaxaSplits`) e aplicá-la pelo fluxo normal de homologação. Se você quiser o SQL manual mesmo assim, é uma decisão sua, e o script pode ser criado depois.
2. Arredondamento: a fórmula do briefing não arredonda, mas o REQ-007 exige precisão de centavo e a coluna é DECIMAL(10,2). Escolhi meio para cima (AwayFromZero). Confirme se a Axis usa essa regra ou outra (por exemplo, banker's rounding).
3. A TASK-05 continua `[ ]` em `docs/product/modules/split/tasks.md`, porque a parte de persistência não existe ainda.

## Lacunas de ambiente (não tratadas)

- `dotnet-baseline.sh --check` reprova: faltam `Directory.Build.props`, `.editorconfig` e `Directory.Packages.props` na raiz. Reportado, não materializado (fora do escopo desta task).
- O restore do `dotnet test` tentou consultar o feed do CodeArtifact (NU1900). Não foi um download deliberado; o build usou o cache local.
- A árvore de trabalho tem muitas deleções não commitadas em `.forge/agents/` e `.claude/agents/`. Não foram tocadas e não entraram no commit.
- O commit não inclui a linha de atribuição de IA, porque a regra global do Milton proíbe esse texto em commits.
