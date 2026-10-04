# Revisão de qualidade — feat/listagem-pedidos (commit 28b5797)

Escopo: diff de `ba5ab69..28b5797` em `packages/pedidos` (2 arquivos, +22 linhas): `src/rotas.ts` e `src/PedidoHelper.ts` (novo). Árvore de trabalho limpa.

## Resumo

Não recomendo abrir a PR no estado atual. Há uma injeção de SQL na listagem por status e uma injeção de HTML na rota da nota fiscal, ambas exploráveis por qualquer requisição. Além disso, a rota da nota aponta para um arquivo de layout que não existe no repositório, então ela não funciona. Os demais pontos são de robustez e de consistência com o restante do pacote.

## Bloqueantes

1. Injeção de SQL em `GET /pedidos` (`src/rotas.ts`, linha 15). O valor de `req.query.status` é interpolado direto na string da query: `WHERE status = '${status}'`. Um `status` como `x' OR '1'='1` lista todos os pedidos, e payloads mais elaborados alcançam o restante do banco. Correção: query parametrizada (`WHERE status = $1`, com `[status]`) e validação do `status` contra o conjunto de valores válidos (enum ou lista fechada), rejeitando o resto com 400.

2. Injeção de HTML na rota da nota (`GET /pedidos/:id/nota`, e `PedidoHelper.renderNota`). O `id` vai para o HTML sem escape, e a resposta sai com `res.send` como `text/html`. Um `id` com `<script>` executa no navegador de quem abre a nota. Além disso, `String.prototype.replace` com string interpreta padrões especiais como `$&` e `$'` no valor de substituição, então o `id` vindo da URL também pode alterar o conteúdo de forma inesperada. Correção: validar `id` como inteiro (ou UUID, conforme o modelo) antes de usar, e escapar ao renderizar, ou usar um engine de template que escape por padrão.

3. Layout inexistente. A rota lê `./layouts/nota-fiscal.html`, mas esse arquivo não está versionado (`git ls-files` não lista nada com `layout` ou `nota`). Toda chamada cai no `readFileSync`, que lança exceção. Como o handler é `async` e não há tratamento de erro, a requisição fica pendurada (ver item 4). Além disso o caminho é relativo ao cwd do processo, então depende de onde o serviço é iniciado. Correção: versionar o layout e resolver o caminho a partir de `import.meta.url` ou de uma configuração em `config.ts`.

## Importantes

4. Tratamento de erro ausente nas rotas async. Com Express 4 (`^4.19.0`), uma exceção ou promise rejeitada dentro de handler `async` não é capturada pelo framework. O `pool.query` que falhar (banco fora do ar, por exemplo) deixa a requisição sem resposta e gera rejeição não tratada. A rota existente `/pedidos/:id` já tem esse problema, e as duas novas copiaram o padrão. Correção: `try/catch` com `res.status(500)` ou um wrapper de handler async, ou um middleware de erro.

5. `try/catch` vazio em `renderNota` (`PedidoHelper.ts`). O `catch {}` engole qualquer erro e devolve o layout sem substituição, o que esconde falhas. O bloco `try` também não tem risco real de exceção, porque `replace` com strings não lança. O bloco é código morto que mascara problemas. Correção: remover o `try/catch`.

6. Configuração fora do lugar. `DESCONTO_PADRAO` é lido direto de `process.env` dentro do helper, enquanto o pacote já centraliza variáveis de ambiente em `src/config.ts`. Além disso, `Number("abc")` vira `NaN` e o HTML sai com `NaN` sem aviso. Correção: adicionar a variável em `config.ts` com validação na inicialização, e falhar cedo se o valor não for numérico. Antes de implementar, confirmar a unidade do desconto (percentual ou valor em centavos): a regra do projeto diz que dinheiro é inteiro em centavos, e a implementação atual não deixa isso explícito.

7. Listagem sem paginação. `GET /pedidos` retorna todos os pedidos do status sem `LIMIT` ou `OFFSET`. Com o crescimento da tabela, a resposta e o custo da query crescem sem limite. Correção: paginação por cursor ou por `limit` com teto máximo.

8. Autorização não visível no diff. As duas rotas novas expõem dados de pedidos e notas fiscais sem nenhum middleware de autenticação ou autorização nas rotas. Pode ser que o controle esteja na frente do serviço (gateway), mas isso não aparece neste pacote. Vale confirmar antes da PR, porque a rota de nota fiscal contém dados fiscais.

## Menores

9. Testes. Nenhum teste foi adicionado para as duas rotas e o `package.json` do pacote não tem script de teste. Pelo fluxo de testes do projeto, o código novo deveria chegar com cobertura, idealmente começando pelo teste que reproduz a injeção de SQL.

10. Convenção de nomes. O arquivo `PedidoHelper.ts` usa PascalCase, enquanto `db.ts`, `config.ts` e `rotas.ts` usam minúsculas. O `packages/notificacoes` tem `EmailManager.ts`, então o repositório também não é uniforme. Escolher um padrão e aplicar. Os identificadores em português (`pedidos`, `rotas`, `listagem`) seguem o código existente, mas o `AGENTS.md` pede identificadores em inglês; vale decidir se isso é regra ou se o código atual é a exceção aceita.

11. `PedidoHelper` como classe só com `static` é um padrão pouco idiomático em TypeScript. Uma função exportada resolve o mesmo caso com menos cerimônia. É preferência de estilo, sem impacto funcional.

## Verificação

Não executei typecheck, lint nem testes. Não há `node_modules` instalado e a política desta execução proíbe baixar dependências. Os achados acima vêm da leitura do diff e do código, não de execução. O `eslint.config.mjs` da raiz tem regras `forge-quality/*`, que deveriam ser rodadas quando as dependências estiverem instaladas.

## Ordem sugerida de correção

Primeiro os três bloqueantes, depois o tratamento de erro (item 4), com teste de regressão para a injeção de SQL. Os itens 6 a 11 podem ir numa segunda passada, antes ou depois da PR, conforme o time preferir.
