Triagem feita e salva em outputs/triagem-cobranca.md. Nenhum código foi alterado.

Dos cinco achados, só um é defeito de verdade e precisa entrar no release de sexta: a query de `marcarPaga` em `src/infra/PgCobrancaRepository.ts:13` interpola o `id` por template literal, e esse `id` vem direto de `POST /cobrancas/:id/pagamento` sem validação. Isso é injeção de SQL alcançável pela rota. A correção é usar `$1` como já faz `buscar`, com teste cobrindo aspas no `id`.

Os outros quatro podem ficar como estão. O `readFileSync` em `boot.ts` roda uma vez antes do `listen`, então é bootstrap legítimo. O `new Pool()` em `db/bootstrap.ts` é o ponto único declarado de criação do pool. O `.then` em `lembrete.ts` tem `.catch` na linha seguinte, e o scanner não atravessa linhas. A interface `CobrancaRepository` é a porta do domínio, com fake de teste como segunda implementação. Nesses três casos o problema é do scanner, não do código.

Dois pontos fora dos cinco achados. O baseline de lint reprova porque não há `eslint.config.mjs` com as regras `forge-quality/*`; isso pede um change próprio com `node-baseline.sh --apply`, que não rodei porque escreve configuração. E em `boot.ts` a linha `{ cert, key: cert }` usa o mesmo arquivo para certificado e chave, além do `as never` que esconde o tipo; vale conferir o PEM real. Também `agendarLembrete` não é chamada em lugar nenhum do repositório.

Não rodei os testes, porque não há `node_modules` e instalar exige rede.
