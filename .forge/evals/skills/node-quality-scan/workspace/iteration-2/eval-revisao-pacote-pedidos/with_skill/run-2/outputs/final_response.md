Revisão feita e salva em `outputs/revisao-pedidos.md` (caminho dentro da execução). Não recomendo abrir a PR no estado atual.

Dois BLOCKERs: a listagem por status em `packages/pedidos/src/rotas.ts:15` interpola `status` direto no SQL (injeção de SQL), e `readFileSync` no handler da nota fiscal (`rotas.ts:20`) bloqueia o event loop; o caminho `./layouts/nota-fiscal.html` também não existe no repositório.

Um HIGH de leitura: o `id` da rota da nota vai para o HTML sem escape, então um id com `<script>` vira HTML executável. Há ainda um `catch {}` vazio em `PedidoHelper.ts:6` que não tem o que capturar, e a variável `DESCONTO_PADRAO` deveria passar pelo `config.ts` do pacote.

O baseline de lint da raiz passou. Não executei ESLint nem testes, porque não há `node_modules` e a instalação de dependências não é permitida nesta execução.
