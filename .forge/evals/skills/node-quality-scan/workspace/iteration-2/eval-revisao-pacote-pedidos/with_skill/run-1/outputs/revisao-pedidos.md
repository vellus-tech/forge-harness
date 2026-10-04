# Revisão de qualidade: feat/listagem-pedidos (packages/pedidos)

## Resumo executivo

A branch adiciona a listagem de pedidos por status (`GET /pedidos`), a rota da nota fiscal (`GET /pedidos/:id/nota`) e a classe `PedidoHelper`. Antes da PR, há dois bloqueadores: injeção de SQL na listagem e leitura síncrona de arquivo dentro de handler de requisição. Também há problemas médios de config fora do módulo central, erro engolido em silêncio e nome genérico. Recomendação: não abrir a PR sem corrigir os dois bloqueadores.

## Fatos

Escopo revisado: os dois arquivos alterados em `packages/pedidos/src/` (`rotas.ts` e `PedidoHelper.ts`), contra `main`.

Baseline de lint: `node-baseline.sh --root packages/pedidos --check` reprovou. O `eslint.config.mjs` não foi encontrado nesse path, faltou o parser TypeScript (espree não parseia sintaxe TS) e o baseline de lint está ausente. A verificação foi feita só nesse path; o `eslint.config.mjs` existe na raiz do monorepo e não foi conferido na raiz. Nenhum `--apply` foi executado, porque isso altera o repositório e não faz parte do pedido.

Scanner `node-quality-scan` (5 achados, cada um julgado abaixo):

| Regra | Severidade | Local | Situação |
|---|---|---|---|
| sql-interpolation | BLOCKER | `src/rotas.ts:15` | Confirmado |
| sync-fs-blocking | BLOCKER | `src/rotas.ts:20` | Confirmado |
| process-env-direct | MEDIUM | `src/PedidoHelper.ts:3` | Confirmado |
| empty-catch | HIGH | `src/PedidoHelper.ts:6` | Confirmado |
| generic-name | MEDIUM | `src/PedidoHelper.ts:1` | Confirmado |
| floating-promise | HIGH | n/a | OK, sem ocorrência |
| new-pg-client | HIGH | n/a | OK, sem ocorrência |
| date-now | MEDIUM | n/a | OK, sem ocorrência |
| explicit-any | MEDIUM | n/a | OK, sem ocorrência |
| mutable-module-state | HIGH | n/a | OK, sem ocorrência |
| single-impl-interface | MEDIUM | n/a | OK, sem ocorrência |

## Achados

### 1. BLOCKER: injeção de SQL em `GET /pedidos` (`src/rotas.ts:14-15`)

O parâmetro `status` vem de `req.query` e entra no SQL por template literal. Qualquer cliente consegue alterar a query. Além disso, `String(req.query.status)` aceita arrays do Express e os transforma em texto, então o valor não é validado de nenhuma forma.

Correção: usar placeholder do driver, `pool.query("SELECT * FROM pedidos WHERE status = $1 ORDER BY criado_em DESC", [status])`. Vale também validar `status` contra o conjunto de valores aceitos (enum), porque o filtro hoje aceita qualquer texto.

### 2. BLOCKER: leitura síncrona de arquivo no handler (`src/rotas.ts:20`)

`readFileSync` bloqueia o event loop a cada requisição de nota fiscal. Todo request concorrente espera a leitura de disco. O caminho `./layouts/nota-fiscal.html` também depende do diretório de execução do processo, o que quebra quando o serviço sobe de outro diretório.

Correção: carregar o layout uma vez no boot, com `readFileSync` fora do handler, ou usar `readFile` de `node:fs/promises` com `await`. Para o caminho, resolver a partir do próprio módulo ou colocar em `config.ts`.

### 3. ALTO (não coberto pelo scanner): handlers async sem tratamento de erro

Os três handlers de `rotas.ts` são `async` e nenhum tem `try/catch`. No Express 4, que é a versão declarada em `package.json`, uma promise rejeitada não é repassada ao middleware de erro. A requisição fica pendurada e o rejection vira aviso de processo. O `floating-promise` passou porque procura `.then()` sem `.catch()`, e este caso não usa `.then()`. Correção: envolver os handlers com um wrapper que chama `next(err)`, ou tratar o erro dentro de cada rota.

### 4. MÉDIO: config fora do módulo central (`src/PedidoHelper.ts:3`)

`DESCONTO_PADRAO` é lido direto de `process.env`, enquanto o pacote já tem `src/config.ts` como ponto central. Correção: adicionar `descontoPadrao` em `config.ts` e importar de lá. Isso também torna a variável validada no boot.

### 5. MÉDIO: `catch {}` vazio (`src/PedidoHelper.ts:4-6`)

O bloco `try` não tem efeito prático, porque `String.prototype.replace` com strings não lança exceção. O `catch` vazio, porém, devolveria o layout sem substituição sem nenhum registro, se alguma exceção surgisse. Correção: remover o `try/catch`. Se for mantido, o erro precisa ser registrado ou repassado.

### 6. MÉDIO: nome genérico (`src/PedidoHelper.ts:1`)

`PedidoHelper` não diz o que a classe faz. Como a classe só renderiza a nota fiscal, o nome mais honesto é algo como `NotaFiscalRenderer` ou uma função `renderNotaFiscal` em `nota-fiscal.ts`. Identificadores ficam em inglês, conforme `AGENTS.md`.

### 7. Observações sem severidade definida

- `GET /pedidos` não tem paginação. Com a tabela crescendo, a resposta fica sem limite.
- Não há teste para as duas rotas novas nem para a renderização da nota.

## Recomendação

Corrigir os itens 1 e 2 antes de abrir a PR. Os itens 3 a 6 podem entrar na mesma PR por serem pequenos. O item 7 pode ficar para uma PR seguinte, desde que registrado no ledger.

## Verificação

Revisão feita por leitura do diff e do código completo dos arquivos de `packages/pedidos/src/`, mais o scanner determinístico. Testes e build não foram executados, porque o pacote não tem script de teste no `package.json` e instalar dependências exigiria rede, o que está fora desta execução.
