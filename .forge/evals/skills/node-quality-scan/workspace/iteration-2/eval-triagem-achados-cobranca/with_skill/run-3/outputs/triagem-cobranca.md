# Triagem do scan de qualidade: servico-cobranca

Escopo: `src/` e `test/` do serviço (package `servico-cobranca` 2.3.1). Nenhum código foi alterado.

## Estado do lint antes do scan

O baseline de lint está ausente: `eslint.config.mjs` não existe na raiz, então nenhuma regra `forge-quality/*` roda neste serviço. Além disso, o parser TypeScript não está configurado (o espree padrão não lê sintaxe TS). Isso significa que as três regras AST (`no-direct-console`, `no-direct-data-access`, `max-lines`) não estão cobrindo o código. A correção é `bash .forge/scripts/node-baseline.sh --apply`, que precisa de instalação de dependências e por isso não foi executada nesta rodada (rede proibida).

## Veredito por achado

### 1. sql-interpolation: DEFEITO REAL, corrigir antes do release

`src/infra/PgCobrancaRepository.ts:13` monta a query com template literal: `` `UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = '${id}'` ``. O `id` vem direto de `req.params.id` em `src/rotas.ts:7`, sem validação. Uma chamada a `POST /cobrancas/x'%20OR%20'1'='1/pagamento` (ou payload equivalente) altera linhas arbitrárias. Não há exceção legítima para valor vindo de entrada. Correção: `this.pool.query("UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = $1", [id])`, que é o mesmo padrão já usado em `buscar`. Custo: uma linha. Vale também um teste de regressão com id malicioso, e checar se a rota deve validar o formato do id.

### 2. sync-fs-blocking: NÃO é defeito, deixar como está

`src/boot.ts:9` usa `readFileSync` no topo do módulo, executado uma única vez antes de `app.listen`. Isso é exatamente a exceção legítima descrita em `references/clean-code-rules.md` (bootstrap que roda antes de o servidor aceitar conexões). Bloquear o event loop nesse ponto não afeta request nenhum. Ponto de atenção que não é do scanner: a mesma variável `cert` é usada como `cert` e como `key` (`boot.ts:11`), o que só funciona se o `.pem` contiver certificado e chave juntos. A conversão `as never` esconde a incompatibilidade de tipos das opções do Fastify. Vale documentar esse formato de arquivo ou separar as duas variáveis, mas não é o achado.

### 3. new-pg-client: NÃO é defeito, deixar como está

`src/db/bootstrap.ts:5` é o único `new Pool()` do serviço e o próprio arquivo se declara como ponto único de criação do pool (comentário na linha 1). A regra existe para pegar pools criados por request; aqui o pool é único e importado uma vez. Exceção legítima.

### 4. floating-promise em lembrete.ts: FALSO POSITIVO, deixar como está

`src/jobs/lembrete.ts:4-7` tem `.then(...)` seguido de `.catch(...)` na linha 7. A cadeia atravessa três linhas e o scanner, que é regex sobre texto, só viu a primeira. O `.catch` pega também erros lançados dentro do `.then`, então a rejeição não fica sem handler. O scanner documenta essa limitação em `detection-commands.md`. Não há mudança a fazer. Se quiser, a cadeia pode virar `async/await` com `try`, mas isso é estilo, não defeito.

### 5. single-impl-interface (CobrancaRepository): NÃO é defeito, deixar como está

`src/domain/CobrancaRepository.ts` é uma porta do domínio. O próprio arquivo declara isso (linha 1-2): o domínio declara, a infraestrutura implementa (`PgCobrancaRepository`), e nos testes entra um fake (`test/fakes.ts`). A segunda "implementação" é o teste, que é a exceção descrita para porta hexagonal. A ressalva é que o fake não usa `implements`, então a checagem de contrato depende do TypeScript na chamada, o que ainda funciona porque `repoEmMemoria` é passado onde a porta é esperada. Não justifica mudança para o release.

## Resumo para o release

Um achado é defeito e bloqueia o release: a injeção de SQL em `marcarPaga`. Os outros quatro são falsos positivos ou exceções legítimas. O FAIL do scan, portanto, é de um único achado real, e a correção cabe em uma linha mais um teste.

## Observações fora do scan (leitura do diff)

- `marcarPaga` não verifica se a cobrança existe nem se está `aberta`. A rota responde 204 mesmo para id inexistente, e uma cobrança `cancelada` pode ser marcada como paga. É invariante de domínio, que o scanner não vê. Vale decidir antes do release se é regra de negócio desejada.
- `test/` tem só `fakes.ts`, sem testes de `PgCobrancaRepository`, de `rotas.ts` nem de `lembrete.ts`. Nenhuma das correções acima tem teste de regressão hoje.
- `config.ts` tem `TLS_CERT_PATH` com default `./certs/dev.pem`. Em produção a variável precisa ser definida explicitamente; vale confirmar no deploy.
- Não foi possível rodar `npm test` nem typecheck: não há `node_modules` e instalar dependência exige rede, proibida nesta execução.
