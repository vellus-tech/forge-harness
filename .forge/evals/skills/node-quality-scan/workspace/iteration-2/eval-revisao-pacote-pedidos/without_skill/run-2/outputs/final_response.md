Revisão feita e salva em outputs/revisao-pedidos.md. Veredito: não abra a PR nesta forma.

Bloqueantes:
1. SQL injection em GET /pedidos: o status da query string é interpolado no SQL. Use parâmetro bind ($1) e valide status contra a lista de valores válidos.
2. A rota de nota fiscal lê layouts/nota-fiscal.html, que não está versionado no repositório. Em outros ambientes dá ENOENT.
3. As duas rotas são async sem try/catch. No Express 4 isso deixa a requisição pendurada e gera unhandledRejection.
4. O id da URL vai para o HTML da nota sem validação nem escape.

Importantes: catch vazio em PedidoHelper.renderNota (contraria a regra de código do projeto); DESCONTO_PADRAO lido de process.env sem validação (vira NaN); GET /pedidos sem LIMIT; autorização ausente nas rotas novas (confirmar com a regra de authz).

Não há testes em packages/pedidos. Não rodei tsc, eslint nem testes, porque não há dependências instaladas e a rede está proibida nesta execução.
