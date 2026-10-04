Triagem salva em <RUN>/outputs/triagem-cobranca.md. Nenhum código foi alterado.

Dos cinco achados, só um é defeito de verdade e deve entrar antes da sexta: a query de `marcarPaga` em `src/infra/PgCobrancaRepository.ts` (linha 13) interpola o `id` vindo da URL direto no SQL. Isso é injeção de SQL, e um id como `x' OR '1'='1` marca todas as cobranças como pagas. A correção é usar `$1` com `[id]`, como já faz `buscar`, e o teste deve reproduzir a injeção antes da correção (red-first).

Os outros quatro podem ficar como estão. O pool do pg é um singleton intencional, e o `readFileSync` roda uma vez no boot. A interface `CobrancaRepository` tem duas implementações reais, a de produção e a em memória dos testes. O `.then` de `lembrete.ts` tem `.catch` e não é defeito funcional, mas a função não retorna a promise e parece não ser chamada por nenhum código de `src`, o que vale confirmar com o time.

Dois pontos fora do scan. O mesmo PEM é passado como `cert` e `key` em `boot.ts`, com cast `as never`, o que só funciona se o arquivo tiver chave e certificado juntos. Também, `marcarPaga` não verifica status, então uma cobrança cancelada pode virar paga; essa regra de transição precisa de decisão do time antes de codificar.

Não rodei testes, porque o projeto não tem `node_modules` e instalar exige rede.
