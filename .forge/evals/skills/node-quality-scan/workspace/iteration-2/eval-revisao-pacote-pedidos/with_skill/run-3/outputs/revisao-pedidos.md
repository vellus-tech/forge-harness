# Revisão de qualidade — feat/listagem-pedidos (packages/pedidos)

Escopo: commit 28b5797 (feat(pedidos): listagem por status e nota fiscal), arquivos packages/pedidos/src/rotas.ts e packages/pedidos/src/PedidoHelper.ts.

## Resumo

A branch não deve ir para PR como está. Há uma injeção de SQL na listagem por status (BLOCKER), uma leitura síncrona de arquivo por request na rota da nota fiscal (BLOCKER) e um arquivo de layout que não existe no repositório, o que faz a rota falhar em runtime. O restante são ajustes de qualidade em PedidoHelper.ts.

## Verificação executada

- Baseline de lint (node-baseline.sh --check): PASS. A configuração forge-quality/* está presente. As regras no-direct-console e max-lines são warn, não bloqueiam.
- ESLint não foi executado: não há node_modules e a política desta execução proíbe instalar dependências. Os resultados do lint AST ficam por conta da próxima execução com dependências instaladas.
- Scanner node-quality-scan (scripts/scan.sh --root packages/pedidos): 5 achados FOUND, 5 regras OK. Todos os cinco foram lidos no arquivo:linha e nenhum se enquadra na exceção legítima descrita em clean-code-rules.md.

## Achados

1. BLOCKER — SQL injection. packages/pedidos/src/rotas.ts:15. O parâmetro status vem de req.query e é interpolado num template literal passado a pool.query. Correção: `pool.query("SELECT * FROM pedidos WHERE status = $1 ORDER BY criado_em DESC", [status])`. A rota /pedidos/:id, que já existe, faz exatamente isso com placeholder, então a correção também alinha o padrão do arquivo.

2. BLOCKER — bloqueio do event loop. packages/pedidos/src/rotas.ts:20. readFileSync é chamado a cada request. Todo request concorrente espera o disco. Além disso, o caminho "./layouts/nota-fiscal.html" é relativo ao cwd do processo e o diretório layouts/ não existe no repositório (verificado). Em runtime a rota dá erro de arquivo não encontrado e, no Express 4, a promise rejeitada não é tratada pela rota. Correção: carregar o layout uma vez no boot (readFile assíncrono ou leitura síncrona fora do caminho do request, com cache), resolver o caminho a partir do módulo e confirmar se o arquivo deve ser versionado no pacote ou vem de outro lugar.

3. HIGH — catch vazio sem função. packages/pedidos/src/PedidoHelper.ts:6. `try { ... } catch {}` engole qualquer erro. Na prática o bloco nunca lança: String.prototype.replace com string não lança exceção para entradas de tipo string. O try/catch é código morto que ainda esconde falhas futuras. Correção: remover o try/catch.

4. MEDIUM — process.env lido direto. packages/pedidos/src/PedidoHelper.ts:3. DESCONTO_PADRAO é lido fora do módulo de configuração, sem validação no boot. Correção: adicionar descontoPadrao em packages/pedidos/src/config.ts (com Number e validação) e receber o valor por parâmetro ou importar config.

5. MEDIUM — nome genérico. packages/pedidos/src/PedidoHelper.ts:1. "Helper" não nomeia responsabilidade, e a classe tem só um método estático. Correção: uma função exportada com nome que descreva a ação, por exemplo renderNotaFiscal, em um módulo de nota fiscal. Renomear export é mudança de contrato, mas o único consumidor está no próprio diff.

## Observações adicionais (fora do scanner)

- PedidoHelper.ts:5. `replace("{{id}}", id)` trata `$&` e padrões semelhantes no texto de substituição. O id vem da URL. Use uma função como segundo argumento (`() => id`) para inserir o valor literalmente.
- rotas.ts:14-17. `String(req.query.status ?? "aberto")` aceita array (?status=a&status=b vira "a,b"). A parametrização do item 1 resolve o risco de SQL, mas vale validar o status contra os valores conhecidos.
- As rotas são async sem tratamento de erro. Isso é padrão pré-existente no arquivo (/pedidos/:id), mas as duas rotas novas o repetem. Fica como dívida, fora do escopo desta mudança.

## Recomendação

Corrigir os itens 1 e 2 antes da PR, pois são bloqueantes. Os itens 3 a 5 podem entrar na mesma PR por serem pequenos. Depois de corrigir, rodar ESLint com as dependências instaladas e um teste da rota de listagem com status contendo aspas, para comprovar que a injeção não passa.
