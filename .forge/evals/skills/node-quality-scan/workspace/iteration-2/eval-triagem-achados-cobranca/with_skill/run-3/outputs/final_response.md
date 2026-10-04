Triagem gravada em `outputs/triagem-cobranca.md`. Nenhum código foi alterado.

Antes de tudo: o baseline de lint do serviço está ausente (sem `eslint.config.mjs` e sem parser TypeScript), então as regras `forge-quality/*` não rodam aqui. A correção é `node-baseline.sh --apply`, que depende de instalar dependências, então ficou para depois.

Achado por achado:

1. Interpolação de SQL em `marcarPaga` (`src/infra/PgCobrancaRepository.ts:13`): defeito real e bloqueia o release. O `id` vem de `req.params.id` sem validação, então é injeção de SQL. A correção é usar `$1` com `[id]`, igual ao `buscar`, mais um teste de regressão.
2. `readFileSync` em `src/boot.ts:9`: não é defeito. Roda uma vez no boot, antes de o servidor aceitar conexões. Ponto à parte: `cert` é usado também como `key`, e o `as never` esconde isso.
3. `new Pool()` em `src/db/bootstrap.ts:5`: não é defeito. É o módulo de bootstrap declarado, e o pool é único.
4. `.then` em `src/jobs/lembrete.ts:4`: falso positivo. Há um `.catch` na linha 7 que o scanner não viu por a cadeia ter várias linhas.
5. Interface `CobrancaRepository`: não é defeito. É a porta do domínio, e a segunda implementação é o fake de teste, como o próprio arquivo declara.

Para o release, só o item 1 é bloqueante. Fora do scan, vale decidir se `marcarPaga` deve checar existência e status `aberta` (hoje responde 204 para id inexistente e marca cancelada como paga), e os testes não cobrem repositório nem rotas. Não rodei `npm test` nem typecheck porque não há `node_modules` e a rede está proibida.
