Triagem salva em `outputs/triagem-cobranca.md`. Nenhum código foi alterado.

Um achado bloqueia o release: a injeção de SQL em `src/infra/PgCobrancaRepository.ts:13`. O `id` vem direto de `req.params.id` na rota `POST /cobrancas/:id/pagamento`, e a query é montada com template literal. A correção é parametrizar com `$1`.

Os outros quatro podem ficar como estão. `lembrete.ts:4` tem `.catch` na linha 7, então é falso positivo. `boot.ts:9` lê o certificado uma vez antes do `listen`, que é exceção legítima. `db/bootstrap.ts:5` é o bootstrap declarado do pool. A interface `CobrancaRepository` é porta hexagonal deliberada, com ressalva: nenhum teste consome `test/fakes.ts` ainda.

Antes de sexta, o baseline de lint também precisa ser corrigido: falta `eslint.config.mjs` e o parser TypeScript. Isso exige `node-baseline.sh --apply` com rede, que não estava disponível nesta execução.
