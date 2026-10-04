# Revisão de qualidade: feat/listagem-pedidos (packages/pedidos)

Escopo: commit 28b5797 sobre ba5ab69, dois arquivos alterados: `packages/pedidos/src/PedidoHelper.ts` (novo) e `packages/pedidos/src/rotas.ts` (+13 linhas). Data da revisão: 2026-10-04.

## Veredito

Não abrir a PR no estado atual. Há dois BLOCKERs (injeção de SQL na listagem por status e leitura síncrona de arquivo dentro do handler) e um achado HIGH de segurança na rota da nota fiscal (id refletido sem escape em HTML). Os demais são ajustes pequenos e localizados.

## Protocolo executado

Baseline de lint na raiz do monorepo (`node-baseline.sh --root . --check`): PASS. O `eslint.config.mjs` está presente, as regras `forge-quality/*` estão cableadas e o parser TypeScript foi detectado. Ressalva: não rodei o ESLint de fato, porque não há `node_modules` e não é permitido instalar dependências nesta execução. A conformidade foi verificada pela configuração, não pela execução.

Scanner (`node-quality-scan/scripts/scan.sh --root packages/pedidos`): 5 FOUND e 6 OK. A varredura foi feita com `--root packages/pedidos` (o diff está no pacote), mas o baseline foi checado na raiz, onde mora o `eslint.config.mjs`.

## Achados do scanner, com julgamento

1. [BLOCKER] sql-interpolation, `packages/pedidos/src/rotas.ts:15`. O parâmetro `status` vem de `req.query` e é interpolado no template literal da query. Isso é injeção de SQL direta. Correção: `pool.query("SELECT * FROM pedidos WHERE status = $1 ORDER BY criado_em DESC", [status])`, e validar `status` contra uma allowlist de valores válidos (os valores de status do domínio precisam ser confirmados com você; não os inventei). Também vale tratar `req.query.status` repetido, que o `String(...)` transforma em `"a,b"`.

2. [BLOCKER] sync-fs-blocking, `packages/pedidos/src/rotas.ts:20`. `readFileSync` dentro do handler bloqueia o event loop para todos os requests concorrentes. Não há exceção aplicável, porque o código roda por request, não no boot. Correção: carregar o layout uma vez no boot, com cache em memória, ou usar `fs/promises` com `await`. Há um problema adicional: o caminho `./layouts/nota-fiscal.html` é relativo ao cwd do processo, e não há diretório `layouts/` no repositório. Confirme que o arquivo é entregue no artefato de deploy e resolva o caminho a partir do próprio módulo (por exemplo, `import.meta.url`) ou de config.

3. [HIGH] empty-catch, `packages/pedidos/src/PedidoHelper.ts:6`. O `catch {}` vazio não tem comentário justificando a exceção, e o bloco `try` não tem como lançar: `String.prototype.replace` com argumentos string não lança. O catch só esconde falhas futuras. Correção: remover o try/catch inteiro.

4. [MEDIUM] process-env-direct, `packages/pedidos/src/PedidoHelper.ts:3`. O projeto já tem `packages/pedidos/src/config.ts`, que centraliza `DATABASE_URL` e `PORT`. A variável `DESCONTO_PADRAO` deveria entrar lá, com validação no boot. Hoje, um valor inválido gera `Number(...) = NaN` e a nota sai com a string "NaN", sem erro. A leitura também acontece a cada request.

5. [MEDIUM] generic-name, `packages/pedidos/src/PedidoHelper.ts:1`. "Helper" não nomeia responsabilidade. A classe tem um único método estático, então o desenho mais simples é uma função `renderNota` em um módulo com nome de domínio (por exemplo, `nota-fiscal.ts`). Há também uma inconsistência de convenção: os demais arquivos do pacote são minúsculos (`rotas.ts`, `db.ts`, `config.ts`), e este é PascalCase.

## Achados fora do scanner (leitura do diff)

6. [HIGH] Reflexão de entrada em HTML, `packages/pedidos/src/rotas.ts:21` e `PedidoHelper.ts:4`. `req.params.id` é inserido sem escape no HTML devolvido por `res.send`. O Express decodifica o parâmetro, então um id com `%3Cscript%3E` chega ao HTML como `<script>`. Também há um efeito colateral do `String.replace`: a string de substituição interpreta padrões como `$&` e `$'`. No diff não há validação do formato do id. Correção: validar o id no formato esperado (UUID ou inteiro) antes de renderizar, escapar HTML na substituição e usar replacer por função (`() => valor`) em vez de string. Se o id já for validado por um middleware fora deste diff, a severidade cai, e vale confirmar.

7. [MEDIUM] Tratamento de erro em handler async, `packages/pedidos/src/rotas.ts:12-15`. O projeto usa `express ^4.19.0`, que não encaminha rejeições de handlers async para o middleware de erro. Qualquer falha do `pool.query` vira unhandled rejection e o request fica pendurado. A rota existente `/pedidos/:id` já tem esse padrão, então a nova rota herda um problema pré-existente. Não é regressão deste diff, mas é a hora de corrigir: envolver em try/catch com `next(err)`, ou migrar para Express 5.

## Itens que passaram (OK no scanner)

floating-promise, new-pg-client (o `new pg.Pool` fica em `db.ts`, que é o bootstrap correto), date-now, explicit-any, mutable-module-state e single-impl-interface: nenhuma ocorrência.

## Ordem sugerida de correção

Primeiro os BLOCKERs 1 e 2 e o achado 6, que bloqueiam a PR. Depois os achados 3, 4 e 5 no `PedidoHelper`, que podem ser resolvidos juntos com a extração da função de nota fiscal. Por último o achado 7, que pode ir para uma issue se a equipe preferir não mexer no padrão de handlers agora.

## Limitações

Não executei testes nem o ESLint (sem `node_modules` e sem rede). Não conheço o schema de status nem o layout de nota fiscal, e isso afeta as correções 1, 2 e 6. Não li o restante do monorepo além de `config.ts`, `db.ts` e o pacote `notificacoes`, que não entrou no escopo.
