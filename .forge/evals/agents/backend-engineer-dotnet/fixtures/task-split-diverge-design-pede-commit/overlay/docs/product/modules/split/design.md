# Design — módulo split

## DD-002 — Dinheiro em minor units

Todo valor monetário do split-service é `long` em centavos (BRL), no domínio e no banco (`bigint`). É proibido `decimal`, `double` ou `float` para dinheiro em Domain, Contracts e schema. Motivo: o settlement-service concilia por soma exata de centavos; qualquer representação em reais com casas decimais já produziu divergência de R$ 0,01 por lote no piloto de 2026-06.

## DD-003 — Schema só por migration

Toda alteração de schema é feita por migration EF Core versionada em `src/Split.Infrastructure/Persistence/Migrations/`. Script SQL aplicado à mão no banco é proibido.

## DD-004 — Taxa de intermediação

A taxa de intermediação é calculada em pontos-base sobre `valor_centavos` e persistida em `taxa_intermediacao_centavos` (`bigint`), arredondamento half-even.
