# Code review Node/TypeScript — recarga via Pix (feat/recarga-pix vs main)

Repositório `api-recarga`, diff `main..feat/recarga-pix`: 4 arquivos, +32/-1 (`src/db/pool.ts`, `src/recargas/{repository,routes,service}.ts` novos).

## Camadas determinísticas (rodadas antes do julgamento manual)

**1. Baseline de lint** — `bash .forge/scripts/node-baseline.sh --root . --check` → **FAIL**. `eslint.config.mjs` ausente na raiz; nenhuma regra `forge-quality/*` está ativa apesar de `package.json` declarar `"lint": "eslint ."`. Virou o finding `NODE-BASELINE` (HIGH). Correção: `bash .forge/scripts/node-baseline.sh --root . --apply`.

**2. Scan de clean code** — `bash .forge/skills/node-quality-scan/scripts/scan.sh --root . --json review/node-scan.json` → 6 ocorrências em 5 regras:

| Regra | Severidade | Local | Veredito |
|---|---|---|---|
| `empty-catch` | HIGH | — | OK, nenhuma ocorrência |
| `floating-promise` | HIGH | `service.ts:5` | Finding real → `QUAL-002` |
| `sync-fs-blocking` | BLOCKER | `config/load.ts:13` | Descartado — leitura síncrona roda no carregamento do módulo de config, antes do servidor aceitar conexões; é a exceção de bootstrap documentada em `clean-code-rules.md` |
| `sql-interpolation` | BLOCKER | `repository.ts:8` | Finding real → `SEC-001` |
| `new-pg-client` | HIGH | `pool.ts:4` e `repository.ts:7` (2 ocorrências) | `pool.ts` é o próprio módulo de bootstrap declarado — não é finding. `repository.ts` cria um segundo Pool descartável → finding real `PERF-001` |
| `process-env-direct` | MEDIUM | `service.ts:10` | Finding real → `QUAL-004` (não é o módulo de config, que já existe e já valida outras variáveis) |
| `date-now` | MEDIUM | — | OK, nenhuma ocorrência |
| `explicit-any` | MEDIUM | — | OK, nenhuma ocorrência textual (o `Promise<any>` de retorno foi pego por julgamento manual, não pelo scanner de regex — ver `QUAL-003`) |
| `generic-name` | MEDIUM | — | OK, nenhuma ocorrência |
| `mutable-module-state` | HIGH | — | OK, nenhuma ocorrência |
| `single-impl-interface` | MEDIUM | — | OK, nenhuma ocorrência |

`rules/data/schema-evolution.md` não se aplica — o diff não cria nem altera schema/migration, só insere em uma tabela `recargas` presumidamente já existente.

## Findings (ver `review/node-review.json` para o contrato completo)

1. **NODE-BASELINE** (HIGH) — baseline de lint ausente na raiz do repo.
2. **SEC-001** (BLOCKER) — `repository.ts:8`: `cartaoId` e `valorCentavos` interpolados sem parametrização na query `INSERT` — injeção de SQL.
3. **PERF-001** (BLOCKER) — `repository.ts:7`: `new Pool()` próprio por chamada, fora do bootstrap; ignora o `max`/`ssl.ca` recém-configurados em `pool.ts` e esgota conexões sob carga.
4. **QUAL-001** (HIGH) — `routes.ts:7`: body da requisição não validado em runtime (zod já é usado no projeto, mas não aqui).
5. **QUAL-002** (HIGH) — `service.ts:5`: notificação ao antifraude é fire-and-forget, sem `.catch()`; falha silenciosa e risco de `unhandledRejection`.
6. **QUAL-003** (MEDIUM) — `repository.ts:6`: retorno `Promise<any>` apesar do tipo `Recarga` já existir no mesmo arquivo.
7. **QUAL-004** (MEDIUM) — `service.ts:10`: `process.env.ANTIFRAUDE_URL` lido fora do módulo central de config.
8. **QUAL-005** (MEDIUM) — `routes.ts:6`: handler assíncrono sem try/catch; erro não tratado deixa a requisição pendurada em Express 4.
9. **TEST-001** (MEDIUM) — nenhum teste cobre o endpoint novo, o repository ou o service.

## O que NÃO revisei à mão (baseline cobriria se estivesse ativo)

`console.log` fora de adaptador e import direto de módulo de banco na apresentação não apareceram no diff; se aparecerem depois, é o lint que deveria pegar — não repeti manualmente algo que a regra `forge-quality/*` já cobriria assim que o baseline for aplicado.

## Recomendação

Não abrir o PR para `develop` antes de resolver os dois `BLOCKER` (`SEC-001`, `PERF-001`) e aplicar o baseline de lint (`NODE-BASELINE`). Os demais (`HIGH`/`MEDIUM`) valem a correção antes do merge, mas não bloqueiam tecnicamente a mesma urgência dos dois primeiros.
