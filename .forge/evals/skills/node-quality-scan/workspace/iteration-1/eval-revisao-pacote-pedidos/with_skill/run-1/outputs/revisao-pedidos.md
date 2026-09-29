# Revisão de qualidade — packages/pedidos (branch feat/listagem-pedidos)

Escopo: diff `main...feat/listagem-pedidos`, restrito a `packages/pedidos` (listagem por status em `rotas.ts` e a rota de nota fiscal, junto com o novo `PedidoHelper.ts`). Nenhum outro pacote do monorepo foi tocado nesta branch, então a revisão não saiu de `packages/pedidos`.

## Baseline de lint

`bash .forge/scripts/node-baseline.sh --root packages/pedidos --check` reprovou: falta `eslint.config.mjs` na raiz do repositório, então nenhuma das regras `forge-quality/*` (no-direct-console, no-direct-data-access, max-lines) está cableada no lint deste monorepo. Isso significa que os dois achados abaixo não foram pegos por AST porque a camada que os pegaria nem está instalada — vale abrir uma tarefa separada para rodar `--apply` e materializar o baseline, fora do escopo desta PR.

## Achados do scanner (packages/pedidos)

Rodado `scripts/scan.sh --root packages/pedidos`: 5 `FOUND` em 11 regras, cada um julgado abaixo por arquivo:linha.

**sql-interpolation [BLOCKER] — `src/rotas.ts:15`.** A nova rota `GET /pedidos` monta a query com o `status` da query string interpolado direto no template literal: `` `SELECT * FROM pedidos WHERE status = '${status}' ORDER BY criado_em DESC` ``. É injeção de SQL — o valor vem de entrada do usuário (`req.query.status`) sem nenhum tratamento, e não há exceção legítima para valor de entrada. Contraste: a rota logo acima, `GET /pedidos/:id`, já usa parâmetro posicional (`$1`) corretamente — o padrão certo já existe no mesmo arquivo. Correção: `pool.query("SELECT * FROM pedidos WHERE status = $1 ORDER BY criado_em DESC", [status])`.

**sync-fs-blocking [BLOCKER] — `src/rotas.ts:20`.** A rota `GET /pedidos/:id/nota` chama `readFileSync("./layouts/nota-fiscal.html", "utf8")` dentro do handler HTTP, não em bootstrap. Isso bloqueia o event loop inteiro a cada request — sob carga concorrente, todo outro request da API espera essa leitura de disco terminar, não só quem pediu a nota. Correção: `readFile` assíncrono (ou, melhor, carregar o layout uma vez no boot e manter em memória, já que o conteúdo é estático).

**empty-catch [HIGH] — `src/PedidoHelper.ts:6`.** `catch {}` sem corpo engole qualquer erro do `.replace()` em cadeia e retorna o layout original silenciosamente — sem log, sem `cause`, sem comentário explicando por que é seguro ignorar. Não há exceção legítima aqui (a regra exige comentário explícito para o caso raro em que vazio é aceitável; este não tem). Correção: relançar preservando a causa, ou ao menos logar antes do fallback.

**process-env-direct [MEDIUM] — `src/PedidoHelper.ts:3`.** `process.env.DESCONTO_PADRAO` é lido direto dentro do helper, fora de `config.ts` — que já existe no pacote e é exatamente o módulo central de config (`databaseUrl`, `port`). A exceção do scanner cobre arquivos `config.*`/`env.*`; `PedidoHelper.ts` não é um deles. Correção: mover `DESCONTO_PADRAO` para `config.ts` e injetar o valor já validado.

**generic-name [MEDIUM] — `src/PedidoHelper.ts:1`.** `PedidoHelper` não nomeia responsabilidade — hoje faz uma coisa (renderizar nota), mas o nome convida a virar ímã para qualquer coisa relacionada a pedido que não tenha lugar óbvio. Sugestão: `NotaFiscalRenderer` ou `formatarNotaFiscal` como função solta, já que só há um método estático.

## O que ficou de fora do scanner e foi lido no diff

`PedidoHelper.renderNota` não valida se `layout` contém os placeholders `{{id}}`/`{{desconto}}` antes de substituir — se o arquivo de layout mudar de formato, a função retorna o HTML sem nenhum dos dois campos preenchidos, silenciosamente (agravado pelo `catch {}` acima). Não é um dos achados do scanner, mas é o tipo de invariante ausente que a skill deixa para leitura humana.

## Antes de abrir a PR

Os dois `BLOCKER` (injeção de SQL e leitura síncrona bloqueante) bloqueiam o merge por si — não são estilo, são bug de segurança e de disponibilidade sob carga. Resolva-os primeiro; os três `MEDIUM/HIGH` restantes valem a correção na mesma PR já que estão nos mesmos dois arquivos pequenos que ela introduziu.
