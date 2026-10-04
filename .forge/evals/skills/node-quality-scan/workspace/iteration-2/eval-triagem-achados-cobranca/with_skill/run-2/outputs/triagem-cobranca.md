# Triagem do scan de qualidade: servico-cobranca 2.3.1

## Sumário executivo

Dos cinco achados do `node-quality-scan`, um é defeito real e bloqueia o release: a injeção de SQL em `marcarPaga` (`src/infra/PgCobrancaRepository.ts:13`), porque o `id` vem direto da URL. Os outros quatro são falsos positivos ou decisões de arquitetura deliberadas, e podem ficar como estão. Antes de sexta, há também uma falha de configuração do próprio lint, que não é defeito de código mas faz o gate continuar vermelho.

## Pré-requisito: baseline de lint reprovado

`node-baseline.sh --check` reprovou antes da leitura de código. Faltam `eslint.config.mjs` na raiz e o parser TypeScript (8 arquivos `.ts` sem `@typescript-eslint/parser`). Enquanto isso não for cableado, as regras `forge-quality/*` não rodam, e o gate de lint continua FAIL independentemente do código. Correção: `bash .forge/scripts/node-baseline.sh --apply`, que precisa de dependências de desenvolvimento. Não rodei porque o ambiente desta execução não tem rede. Isso é um item de infraestrutura para o tech lead, não um achado de código.

## Achado por achado

### 1. floating-promise: `src/jobs/lembrete.ts:4`. Não é defeito

O scanner viu `.then(` sem `.catch(` na mesma linha. A cadeia continua na linha 7 com `.catch((err) => log(...))`, então a rejeição é tratada. Ele também cobre erro lançado dentro do callback do `.then`. Deixar como está. Limitação conhecida do scanner com cadeias multilinha, descrita em `references/detection-commands.md`.

### 2. sync-fs-blocking: `src/boot.ts:9`. Não é defeito

`readFileSync` do certificado roda uma vez, no boot, antes de `app.listen`. Não bloqueia requisição nenhuma, porque nenhuma conexão é aceita nesse momento. É a exceção explícita em `clean-code-rules.md`. Deixar como está.

Observação separada, fora do escopo do scan: `boot.ts:11` passa o mesmo arquivo como `cert` e como `key` (`{ cert, key: cert } as never`). Isso só funciona se o PEM contiver chave e certificado juntos. Vale confirmar com o time de infra, e o `as never` esconde a divergência de tipo. Não é achado de release, mas merece uma olhada.

### 3. sql-interpolation: `src/infra/PgCobrancaRepository.ts:13`. Defeito real, bloqueante

`marcarPaga(id)` monta `UPDATE ... WHERE id = '${id}'` com template literal. O `id` vem de `req.params.id` na rota `POST /cobrancas/:id/pagamento` (`src/rotas.ts:6-7`), sem validação nem autenticação visíveis no arquivo. Um `id` com aspas altera a query, e o caminho é alcançável por HTTP. Esse é exatamente o caso que o scanner marca como BLOCKER, e aqui a exceção não se aplica, porque o valor vem de entrada. Corrigir antes do release:

```ts
await this.pool.query("UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = $1", [id]);
```

Vale também um teste de regressão com um `id` contendo aspas, e revisar se a rota tem autenticação, o que está fora do escopo deste arquivo.

### 4. new-pg-client: `src/db/bootstrap.ts:5`. Não é defeito

O arquivo é o bootstrap declarado do banco, com o comentário "Único ponto de criação do pool de conexões do serviço". `new Pool()` aqui é o uso correto. O scanner não reconhece o arquivo pelo caminho, então este é um falso positivo previsível. Deixar como está. Vale confirmar que nenhum outro arquivo instancia `Pool` ou `Client`, o que o scan já indica (só um `FOUND`).

### 5. single-impl-interface: `src/domain/CobrancaRepository.ts`. Não é defeito, mas com ressalva

O comentário no próprio arquivo declara a porta hexagonal: o domínio define `CobrancaRepository` e a infraestrutura implementa. Essa é a exceção legítima descrita na referência. O scanner só contou uma classe com `implements`, e não enxerga o fake de `test/fakes.ts`, que é a segunda implementação estrutural. Deixar como está.

Ressalva: `test/` contém só `fakes.ts`, sem nenhum arquivo de teste que o consuma. Hoje a porta tem uma implementação real e um fake que nenhum teste usa. Não bloqueia o release, mas a justificativa da porta só se sustenta quando os testes de domínio existirem.

## Resumo para o release

| Achado | Veredito | Ação |
|---|---|---|
| floating-promise (lembrete.ts:4) | Falso positivo | Nenhuma |
| sync-fs-blocking (boot.ts:9) | Exceção legítima (boot) | Nenhuma |
| sql-interpolation (PgCobrancaRepository.ts:13) | Defeito real, bloqueante | Parametrizar a query e testar |
| new-pg-client (db/bootstrap.ts:5) | Falso positivo (bootstrap) | Nenhuma |
| single-impl-interface (CobrancaRepository) | Porta hexagonal deliberada | Nenhuma; cobrir com testes depois |
| Baseline de lint | Falha de configuração | `node-baseline.sh --apply` com rede |

Um achado de código bloqueia o release (SQL). Os demais não justificam mudança.
