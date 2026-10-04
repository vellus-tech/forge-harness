Revisei as duas mudanças da branch `feat/listagem-pedidos` em `packages/pedidos` e salvei o relatório em `outputs/revisao-pedidos.md`. Recomendo não abrir a PR antes de corrigir os dois bloqueadores.

Bloqueadores:
- `GET /pedidos` (`src/rotas.ts:15`) interpola `status` vindo da query string direto no SQL. Isso é injeção de SQL. Correção: usar `$1` com o array de parâmetros e validar `status` contra os valores aceitos.
- `GET /pedidos/:id/nota` (`src/rotas.ts:20`) usa `readFileSync` dentro do handler, o que bloqueia o event loop a cada requisição. Correção: carregar o layout no boot ou usar `readFile` assíncrono, e resolver o caminho sem depender do diretório de execução.

Médios:
- Os handlers são `async` sem `try/catch`. No Express 4 a rejeição não chega ao middleware de erro e a requisição fica pendurada. O scanner não pega esse caso.
- `PedidoHelper.ts:3` lê `DESCONTO_PADRAO` de `process.env` direto, fora do `src/config.ts` que já existe.
- `PedidoHelper.ts:6` tem `catch {}` vazio, e o `try` não tem efeito real. Remover o bloco.
- `PedidoHelper` é nome genérico. Sugestão: `NotaFiscalRenderer` ou uma função `renderNotaFiscal`.

Observações: a listagem não tem paginação e as rotas novas não têm teste.

O baseline de lint reprovou quando rodado em `packages/pedidos`: falta o `eslint.config.mjs` nesse path e falta o parser TypeScript. Não executei `--apply`, porque altera o repositório. Não verifiquei a raiz do monorepo. Testes e build não foram executados, porque o pacote não tem script de teste e instalar dependências exige rede.
