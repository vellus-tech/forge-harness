Revisei o diff de feat/listagem-pedidos (28b5797 sobre ba5ab69, só em packages/pedidos) e salvei o relatório em outputs/revisao-pedidos.md. Não recomendo abrir a PR ainda.

Três bloqueantes. Primeiro, a listagem em GET /pedidos interpola o status direto no SQL, então há injeção de SQL; a correção é usar query parametrizada e validar o status contra uma lista fechada. Segundo, a rota de nota fiscal insere o id sem escape no HTML, o que permite XSS, e o String.replace também interpreta padrões especiais do valor. Terceiro, a rota lê ./layouts/nota-fiscal.html, que não está versionado no repositório, então a rota não funciona e depende do cwd do processo.

Importantes: as rotas async não têm tratamento de erro no Express 4, então uma falha do banco deixa a requisição pendurada (a rota existente já tem esse problema); o try/catch vazio em renderNota esconde erros; DESCONTO_PADRAO é lido fora do config.ts e aceita NaN sem aviso; e a listagem não tem paginação. Também vale confirmar onde está a autorização, porque as rotas novas não têm nenhum middleware no diff.

Não rodei typecheck, lint nem testes, porque não há node_modules e a política desta execução proíbe instalar dependências. Não alterei nenhum arquivo do projeto nem fiz commit.
