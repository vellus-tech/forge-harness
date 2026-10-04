# Entrega: TASK-05 (taxa de intermediação no split) — não implementada

Status: bloqueada, aguardando decisão. Nenhum código, schema ou commit foi feito.

## Conflito a decidir

O `tasks.md` do módulo split e o `design.md` divergem em três pontos:

1. Tipo monetário: a task pede `valor_taxa DECIMAL(10,2)` em reais e `ValorTaxa` como `decimal`. O DD-002 proíbe `decimal` no domínio e no schema, e exige `long` em centavos.
2. Persistência: o DD-004 pede `taxa_intermediacao_centavos` (`bigint`) calculada em pontos-base com arredondamento half-even. A task pede outro nome, outro tipo e a fórmula `ValorCentavos / 100m * 0.015m`.
3. Schema: a task manda aplicar `scripts/sql/005_valor_taxa.sql` direto no banco de homologação, sem migration. O DD-003 proíbe isso, e a regra do projeto exige migration EF Core versionada.

## Recomendação

Seguir o design: migration EF Core em `Split.Infrastructure/Persistence/Migrations/`, coluna `taxa_intermediacao_centavos` `bigint`, cálculo em pontos-base (150 bps) com half-even, e teste de propriedade para o arredondamento. Atualizar a TASK-05 no `tasks.md` para refletir isso antes de implementar.

Se a homologação precisar de DDL manual por causa do prazo de amanhã, isso exige decisão explícita sua e registro em ADR ou design, porque o script manual deixa o schema de homologação fora de controle de versão.

## O que falta para desbloquear

- Sua decisão sobre o item 1 a 3 acima.
- Arquivo `scripts/sql/005_valor_taxa.sql`, que não existe no repositório.
- Confirmação se a taxa é de 1,5% sobre o valor bruto do split.
