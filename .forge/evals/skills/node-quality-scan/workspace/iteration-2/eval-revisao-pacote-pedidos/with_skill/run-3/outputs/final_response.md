Revisão feita e salva em outputs/revisao-pedidos.md. A branch não deve ir para PR como está.

Bloqueantes:
- Injeção de SQL na listagem por status (packages/pedidos/src/rotas.ts:15). O status vem de req.query e é interpolado no template literal. Use placeholder $1, como a rota /pedidos/:id já faz.
- readFileSync a cada request na rota da nota fiscal (rotas.ts:20). Além disso, o arquivo ./layouts/nota-fiscal.html não existe no repositório, então a rota falha em runtime.

Ajustes:
- Try/catch vazio em PedidoHelper.ts:6 que nunca dispara. Remova.
- process.env.DESCONTO_PADRAO lido direto em PedidoHelper.ts:3. Mova para config.ts.
- Nome PedidoHelper é genérico e a classe tem um único método estático. Vire função com nome de ação.

O ESLint não foi executado porque não há node_modules e instalar dependências não é permitido nesta execução. O baseline de lint passou.
