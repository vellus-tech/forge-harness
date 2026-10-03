# Revisão Node/TS — feat/tarifa-integracao (contra main)

Escopo: os 5 arquivos que a branch muda em relação à main — `src/tarifas/aplicacao/cotar-integracao.ts`, `src/tarifas/aplicacao/cotar-integracao.test.ts`, `src/tarifas/dominio/tarifa-repository.ts`, `src/tarifas/dominio/tarifa.ts`, `src/tarifas/infra/pg-tarifa-repository.ts`. `src/legacy/relatorio-helper.ts` já existia na main e não faz parte deste diff — os achados do scanner nele (any explícito, nome genérico, estado mutável em módulo) são pré-existentes e ficam fora desta revisão, registrados só para não esconder que o scanner os viu.

## Camada 1 — baseline de lint (`node-baseline.sh --check`)

FAIL. `eslint.config.mjs` existe, registra o plugin `forge-quality/*` e cobre `no-direct-console`, `no-direct-data-access` e o parser TypeScript corretamente. O único ponto reprovado é `forge-quality/max-lines` declarado `"error"` — que é a decisão errada de severidade (ledger LDG-0061/LDG-0130: tamanho de arquivo é sinal, não portão), não falta de configuração. Isso vira o finding `MEDIUM` abaixo, não `HIGH`.

## Camada 2 — scan de clean code (`node-quality-scan/scripts/scan.sh`)

7 achados no repositório inteiro; nenhum recai sobre um arquivo tocado pela branch, com uma exceção que julguei:

| Regra | Severidade | Ocorrências | Dentro do diff? | Veredito |
|---|---|---|---|---|
| empty-catch | HIGH | 1 (`src/legacy/relatorio-helper.ts:6`) | Não | Fora de escopo — arquivo pré-existente |
| floating-promise | HIGH | 1 (`src/tarifas/infra/pg-tarifa-repository.ts:11`) | Sim | Não é defeito — a promise é `return`ada para quem chama (`buscarVigente` retorna a cadeia, `cotarIntegracao` dá `await`); é exatamente a exceção legítima documentada em clean-code-rules.md |
| sync-fs-blocking | BLOCKER | 0 | — | OK |
| sql-interpolation | BLOCKER | 0 | — | OK — a query em `pg-tarifa-repository.ts` usa `$1`/`$2` parametrizado |
| new-pg-client | HIGH | 0 | — | OK |
| process-env-direct | MEDIUM | 0 | — | OK |
| date-now | MEDIUM | 0 | — | OK |
| explicit-any | MEDIUM | 2 (`src/legacy/relatorio-helper.ts:2,11`) | Não | Fora de escopo |
| generic-name | MEDIUM | 1 (`src/legacy/relatorio-helper.ts:1`) | Não | Fora de escopo |
| mutable-module-state | HIGH | 1 (`src/legacy/relatorio-helper.ts:11`) | Não | Fora de escopo |
| single-impl-interface | MEDIUM | 1 (`TarifaRepository`) | Sim | Não é defeito — é a exceção documentada: porta de arquitetura hexagonal deliberada (domínio declara, `PgTarifaRepository` implementa em produção, `repoFake` no teste é a segunda implementação) |

## Julgamento manual (o que só o revisor faz)

- **HIGH — teste sem asserção real** (`cotar-integracao.test.ts:14`): o único teste do caminho novo chama `cotarIntegracao` e depois faz `expect(true).toBe(true)`, sem ler o retorno. A regra de negócio da branch — 25% de desconto no segundo embarque dentro de 120 minutos — não tem nenhuma cobertura que falharia se `calcularIntegracao` estivesse errada. Também não há caso cobrindo o embarque fora da janela de 120 minutos (sem desconto).
- **LOW — erro genérico sem contexto** (`cotar-integracao.ts:6`): `throw new Error("tarifa vigente não encontrada")` não diz qual linha (`linhaA`/`linhaB`) nem em que instante — dificulta diagnóstico em produção.
- Validação runtime na borda: fora de escopo — a branch só toca aplicação/domínio/infra, o handler HTTP que valida payload externo não está neste diff.
- ORM/query não vaza para domínio: OK — `tarifa.ts` e `tarifa-repository.ts` (domínio) não importam `pg`; só `pg-tarifa-repository.ts` (infra) o faz, e a interface (`TarifaRepository`) é a porta correta entre as camadas.
- `Pool`/`Client` fora de bootstrap: OK — `PgTarifaRepository` recebe o `Pool` por injeção no construtor, não instancia um.
- Log de PAN/CPF/senha/token: não aplicável — nenhum dado desse tipo trafega neste diff.
- `schema-evolution.md` (mudança de Postgres): não se aplica — a branch não altera schema, só consulta uma tabela já existente (`tarifas`).

## Resumo

3 findings: 1 `MEDIUM` (baseline — severidade errada de `max-lines`), 1 `HIGH` (teste sem asserção real) e 1 `LOW` (erro sem contexto). `floating-promise` e `single-impl-interface`, apesar de sinalizados pelo scanner em arquivos do diff, são as exceções legítimas documentadas e não viram finding. Achados do scanner em `src/legacy/relatorio-helper.ts` são pré-existentes na main e ficam fora desta revisão.
