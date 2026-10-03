# Revisão de qualidade — packages/pedidos (branch feat/listagem-pedidos)

Escopo revisado: diff do commit `7c8f77b` contra `0541b78`, arquivos `packages/pedidos/src/rotas.ts` (rotas `GET /pedidos` e `GET /pedidos/:id/nota` adicionadas) e `packages/pedidos/src/PedidoHelper.ts` (novo).

## Bloqueadores (corrigir antes de abrir a PR)

1. **Injeção de SQL em `GET /pedidos`** (`rotas.ts:15`). O parâmetro `status` vem de `req.query.status` e é interpolado diretamente na string SQL (` ...status = '${status}'... `) em vez de usar parâmetro posicional como a rota vizinha já faz (`$1`). Qualquer valor como `' OR '1'='1` ou `'; DROP TABLE pedidos; --` é executado literalmente contra o banco. Corrigir para `pool.query("SELECT * FROM pedidos WHERE status = $1 ORDER BY criado_em DESC", [status])`.

2. **XSS refletido em `GET /pedidos/:id/nota`** (`rotas.ts:19-22` + `PedidoHelper.renderNota`). `req.params.id` é inserido sem escape num template HTML (`layout.replace("{{id}}", id)`) e devolvido via `res.send(...)`, que o Express serve como `text/html`. Um id como `<script>...</script>` é refletido e executado no navegador de quem abrir o link. É preciso sanitizar/escapar `id` antes de inserir no HTML (ex.: `escapeHtml`) ou validar que `id` corresponde a um formato esperado (UUID/numérico) antes de sequer consultar o layout.

3. **Erro engolido silenciosamente em `PedidoHelper.renderNota`** (`PedidoHelper.ts:4-7`). O `catch {}` vazio descarta qualquer exceção do `replace` (praticamente nunca lança, então o bloco é morto) e ainda mascara bugs futuros sem log. Remover o try/catch (não há nada ali que realmente lance) ou, se a intenção era proteger contra layout malformado, logar o erro antes do fallback.

## Importantes (não bloqueiam, mas merecem atenção nesta PR ou logo em seguida)

4. **Rotas assíncronas sem tratamento de erro.** Nenhuma das três rotas tem try/catch nem usa um middleware de erro. Se `pool.query` rejeitar (conexão caiu, coluna inexistente, timeout), o Express 4 não captura a rejeição da promise automaticamente — vira unhandled rejection e pode derrubar o processo, ou o cliente recebe o handler de erro genérico do Express sem controle do formato. Recomendo envolver os handlers com try/catch + `res.status(500).json(...)` ou plugar `express-async-errors`/error middleware central.

5. **`readFileSync` síncrono a cada request** (`rotas.ts:20`). Lê o arquivo `./layouts/nota-fiscal.html` do disco de forma bloqueante em toda chamada a `/pedidos/:id/nota`, o que serializa o event loop sob carga. Como o layout não muda por request, dá para carregar uma vez no boot (ou cachear em memória) e só reler se precisar de hot-reload.

6. **`GET /pedidos/:id` retorna 200 com corpo `null` quando o pedido não existe** (`rotas.ts:8-11`, código pré-existente mas relevante ao contexto da nova listagem). Para uma API RESTful, o esperado é `404` quando o recurso não é encontrado; o consumo dessa API pelo novo endpoint de nota fiscal (que não valida existência do pedido antes de gerar a nota) herda essa ambiguidade.

7. **`GET /pedidos` sem paginação/limite** (`rotas.ts:13-17`). Lista todos os pedidos de um status sem `LIMIT`/`OFFSET`, o que pode devolver payloads muito grandes conforme a tabela cresce. Vale já nascer com paginação, mesmo que simples.

## Observações menores

8. **Pool do `pg` sem handler de erro** (`db.ts`, arquivo não tocado neste diff mas exercitado pelas novas rotas). `pool.on('error', ...)` não está registrado; erros em clients ociosos do pool disparam `error` não tratado no processo. Vale registrar um handler mínimo já que este pacote passou a ter mais tráfego de queries.
9. **`config.databaseUrl` cai para string vazia se `DATABASE_URL` não estiver setado** (`config.ts`, também pré-existente). Falha silenciosa: melhor validar no boot e abortar com mensagem clara em vez de deixar o `pg.Pool` falhar de forma obscura na primeira query.
10. Faltam testes para as duas rotas novas e para `PedidoHelper.renderNota` — não localizei nenhum arquivo de teste em `packages/pedidos`. Dado que a rota de listagem monta SQL dinâmico e a de nota mexe com HTML, esse é exatamente o tipo de mudança que pede teste (inclusive um teste que comprovaria o bug de SQL injection do item 1).

## Resumo

O pacote `pedidos` ganhou duas rotas novas nesta branch; a listagem por status introduz uma injeção de SQL exploitável e a rota de nota fiscal introduz um XSS refletido — ambos devem ser corrigidos antes do merge. Os demais pontos (tratamento de erro assíncrono, leitura de arquivo síncrona, paginação, pool sem handler de erro, ausência de testes) são de qualidade/robustez e podem virar itens de acompanhamento se não houver tempo de resolver tudo nesta PR, mas os dois primeiros bloqueiam.
