# Revisão de qualidade: feat/listagem-pedidos (packages/pedidos)

Escopo: commit 28b5797 sobre a base ba5ab69, alterando `packages/pedidos/src/rotas.ts` (+13) e criando `packages/pedidos/src/PedidoHelper.ts` (+9). Nenhum teste foi executado, pois o pacote não tem testes versionados e não há rede para instalar dependências.

## Resumo executivo

A branch não deve ir para PR como está. Há uma injeção de SQL explorável na listagem por status, um XSS refletido na rota da nota fiscal e uma rota que tende a derrubar a requisição por falta de tratamento de erro em handler assíncrono. Os achados abaixo são fatos verificados no código, com a severidade proposta.

## Achados

### 1. Crítico: injeção de SQL em GET /pedidos

Em `rotas.ts`, o parâmetro `status` vindo de `req.query` é interpolado diretamente na string SQL: `WHERE status = '${status}'`. Um valor como `x' OR '1'='1` lista todos os pedidos, e um payload de UNION ou de `; DROP` tem alcance maior dependendo das permissões do usuário do banco. A correção é parametrizar, por exemplo `pool.query("SELECT * FROM pedidos WHERE status = $1 ORDER BY criado_em DESC", [status])`. Também vale validar `status` contra o conjunto de valores válidos (enum) e recusar o restante com 400, em vez de aceitar texto livre.

### 2. Alto: XSS refletido na rota /pedidos/:id/nota

`req.params.id` é inserido no HTML sem escape e a resposta sai com `Content-Type: text/html` (padrão do `res.send` com string). Uma URL como `/pedidos/<script>alert(1)</script>/nota` executa script no navegador de quem abrir o link. A correção mínima é escapar `&`, `<`, `>`, `"` e `'` antes da substituição e validar que `id` tem o formato esperado (por exemplo, numérico ou UUID), respondendo 400 caso contrário.

### 3. Alto: o `replace` com string interpreta padrões especiais

`String.prototype.replace` com string como substituto interpreta `$&`, `$'`, `` $` `` e `$$`. Verifiquei com Node: `"a{{id}}b".replace("{{id}}", "x$&y")` resulta em `ax{{id}}yb`. Ou seja, um `id` contendo `$&` corrompe o documento, e combinado com o item 2 amplia a superfície. Usar função de substituição (`replace(..., () => valor)`) elimina o problema. Vale também notar que `replace` com string substitui só a primeira ocorrência, então um layout com dois `{{id}}` sai parcialmente preenchido.

### 4. Alto: arquivo de layout inexistente no repositório e caminho relativo ao cwd

`readFileSync("./layouts/nota-fiscal.html")` depende do diretório de trabalho do processo. No repositório não existe nenhum arquivo `layouts/nota-fiscal.html` versionado (verificado com `git ls-files`). Se o arquivo não estiver no deploy, o `readFileSync` lança dentro de um handler `async`. Com Express 4, a rejeição não chega ao error handler e a requisição fica pendurada sem resposta, com `UnhandledPromiseRejection` no processo. A correção é resolver o caminho a partir do próprio módulo (com `import.meta.url` ou `new URL(..., import.meta.url)`), carregar o template uma vez na inicialização e tratar a falha com `try/catch` que responda 500.

### 5. Médio: tratamento de erro ausente nas rotas assíncronas

Nenhuma das três rotas tem `try/catch` nem há error handler no pacote. A rota `/pedidos/:id` já tinha esse padrão antes da branch, mas as duas novas o repetem. Com Express 4, qualquer falha do pool de banco também deixa a requisição pendurada. Recomendo um wrapper `asyncHandler` ou um middleware de erro, aplicado às três rotas, em um commit separado para não misturar com a feature.

### 6. Médio: o try/catch de PedidoHelper.renderNota não faz nada

O bloco `try { ... } catch {}` seguido de `return layout` engole qualquer erro e devolve o template sem substituição, sem log e sem sinal ao chamador. Os métodos `replace` com strings não lançam exceção nesse uso, então o `catch` é código morto que esconde falhas futuras. Deve ser removido. A falha real (arquivo ausente) já é tratada no item 4, no ponto em que ela ocorre.

### 7. Baixo: DESCONTO_PADRAO sem validação

`Number(process.env.DESCONTO_PADRAO ?? 0)` vira `NaN` se a variável tiver texto ou estiver vazia, e o documento sairia com o literal `NaN` como desconto. Também há inconsistência de estilo: `config.ts` centraliza as variáveis de ambiente e o helper lê `process.env` diretamente. Sugiro mover o valor para `config.ts` com validação na subida do processo, falhando cedo se for inválido.

### 8. Baixo: GET /pedidos sem paginação e com SELECT *

A listagem devolve todas as colunas e todos os pedidos do status, sem `LIMIT` nem paginação. Com volume real de pedidos isso vira resposta grande e consulta cara. Recomendo `LIMIT`/`OFFSET` ou cursor por `criado_em`, e a seleção explícita das colunas que o cliente usa. Também vale um índice em `(status, criado_em)`, se ainda não existir.

### 9. Baixo: default silencioso do status

Se o parâmetro não vier, a rota assume `aberto` sem informar o cliente. Isso pode ser intencional, mas deve estar documentado no contrato da API.

### 10. Ausência de testes

As duas rotas novas e o helper entram sem nenhum teste. Pelo menos: uma requisição com status inválido ou com payload de injeção, uma com `id` contendo HTML e `$&`, e um teste do caminho de falha do arquivo de layout. Os testes devem existir antes da PR, conforme a regra de TDD do projeto.

## O que está bem

A separação do helper de renderização em uma classe própria facilita o teste unitário, e a ordem das rotas (`/pedidos/:id` e `/pedidos/:id/nota`) não causa conflito, pois o parâmetro do Express não casa barras. O commit é pequeno e focado no pacote pedido.

## Ordem sugerida de correção antes da PR

1. Parametrizar o status e validar o enum (item 1).
2. Validar e escapar o `id`, usar substituição por função e trocar para `replaceAll` ou regex global (itens 2 e 3).
3. Corrigir o caminho do layout, carregar na inicialização e tratar erro (itens 4 e 6).
4. Adicionar tratamento de erro assíncrono (item 5).
5. Cobrir com testes (item 10).

Os itens 7 a 9 podem ficar para depois da PR, com registro no ledger se o projeto usar um.
