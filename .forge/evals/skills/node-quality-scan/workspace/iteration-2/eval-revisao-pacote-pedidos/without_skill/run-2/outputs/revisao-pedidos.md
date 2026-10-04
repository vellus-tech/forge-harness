# Revisão de qualidade: feat/listagem-pedidos (packages/pedidos)

Escopo: diff `main...feat/listagem-pedidos`, commit `28b5797 feat(pedidos): listagem por status e nota fiscal`. Dois arquivos alterados: `packages/pedidos/src/rotas.ts` (+13) e `packages/pedidos/src/PedidoHelper.ts` (novo, +9). Nenhuma alteração fora de `packages/pedidos`.

## Veredito

Não abrir a PR nesta forma. Há uma injeção de SQL explorável na listagem por status, uma rota de nota fiscal que não funciona no repositório como está (o arquivo de layout não existe), e erros engolidos ou não tratados nas duas rotas novas. Os itens 1 a 3 são bloqueantes.

## Fatos

- `GET /pedidos` (rotas.ts) monta a query com interpolação de template: `WHERE status = '${status}'`, onde `status` vem direto de `req.query.status`. Não há parâmetro bind nem validação de domínio.
- `GET /pedidos/:id/nota` lê `./layouts/nota-fiscal.html` com `readFileSync`. Esse arquivo não existe no repositório (`git ls-files` não lista nenhum `layouts/`) e não está no `.gitignore`. Caminho relativo ao cwd do processo.
- As duas rotas são `async` sem `try/catch`. O Express 4 (`^4.19.0`) não encaminha rejeições de handlers assíncronos para o middleware de erro: a requisição fica pendurada e a rejeição vira `unhandledRejection`, que derruba o processo no Node 15 ou superior. Vale para falha de banco e para o `ENOENT` acima.
- `PedidoHelper.renderNota` envolve o `replace` em `try {} catch {}` vazio. `String.prototype.replace` com string não lança, então o `try` não protege nada e o `catch` apenas esconde qualquer erro futuro. Contraria a regra de tratamento de erro do projeto (`.forge/rules/conventions/code-style.md` §6: proibido `catch` vazio).
- `id` vem de `req.params.id` sem validação e é inserido no HTML devolvido por `res.send(...)` (content-type `text/html`). Um id com marcação HTML é refletido na resposta.
- Não há nenhum arquivo de teste em `packages/pedidos` (`git ls-files`). A regra `.forge/rules/testing/tdd.md` exige Vermelho, Verde, Refactor para todo código do harness e, por analogia, para o código da loja; as duas rotas e o helper entraram sem teste.
- `GET /pedidos` retorna `SELECT *` sem `LIMIT` nem paginação.

## Achados

### Bloqueantes

1. **SQL injection em `GET /pedidos`** (`rotas.ts`, rota `/pedidos`). Exemplo: `?status=x' OR '1'='1` retorna todos os pedidos; `?status='; DROP TABLE pedidos; --` depende do driver aceitar múltiplas instruções (o `pg` aceita). Correção: `pool.query("SELECT * FROM pedidos WHERE status = $1 ORDER BY criado_em DESC", [status])`, com validação prévia de `status` contra o conjunto de valores válidos (lista fechada, retorno 400 para valor fora dela). Alternativa descartada: escapar a string manualmente, frágil e fora do padrão do driver.

2. **Rota de nota fiscal quebrada no repositório** (`rotas.ts`, rota `/pedidos/:id/nota`). O layout `layouts/nota-fiscal.html` não está versionado. Em qualquer ambiente que não o do autor, a rota dá `ENOENT`, cai na rejeição não tratada do item 3 e deixa a requisição pendurada. Correção: versionar o layout ou mover para um módulo carregado com `import` ou com caminho resolvido a partir de `import.meta.url`, e tratar a ausência como erro explícito.

3. **Erros não tratados nas rotas novas** (`rotas.ts`, as duas rotas). Sem `try/catch`, qualquer falha de banco ou de I/O vira rejeição não tratada. Correção mínima: `try/catch` que chama `next(err)` em cada handler, ou envolver os handlers com um wrapper de async. A rota de nota também deve devolver 404 quando o pedido não existe, porque hoje devolve HTML com o id reflexado mesmo sem pedido.

4. **Reflexão de HTML a partir do id** (`PedidoHelper.ts` e `rotas.ts`). Um `id` com marcação é inserido na nota e devolvido como `text/html`. Correção: validar `id` como número ou UUID conforme o modelo de dados (400 se não casar) e, se a nota precisar exibir texto livre, escapar HTML antes do `replace`. Observação: `replace` com string interpreta padrões especiais como `$&` e `$1` no argumento de substituição; o escape do `id` resolve isso também.

### Importantes

5. **`catch {}` vazio em `PedidoHelper.renderNota`.** Remover o `try/catch`. Não há operação ali que lance. Se um dia lançar, o erro deve subir.

6. **`DESCONTO_PADRAO` lido por chamada e convertido com `Number`.** Valor inválido vira `NaN` e aparece como `NaN` na nota sem aviso. Correção: ler em `config.ts` (que já centraliza variáveis de ambiente) com validação na inicialização, em vez de `process.env` dentro do helper. Isso também segue o padrão existente do projeto.

7. **`GET /pedidos` sem limite.** Uma consulta por status pode devolver a tabela inteira. Adicionar `LIMIT`/paginação (`limit` e `cursor` ou `offset`) antes de ir para produção.

8. **Autorização ausente nas duas rotas.** A rota existente `/pedidos/:id` também não tem, então o padrão é pré-existente. As rotas novas expõem listagem completa e nota fiscal (dados fiscais de cliente). Antes da PR, confirmar com a regra de autorização do projeto (`.forge/rules/architecture/authz-pdp-pep.md` e `pii-pci-classification.md`) se a nota fiscal exige checagem de dono do pedido.

### Menores

9. **Nome do arquivo `PedidoHelper.ts`.** Os demais arquivos de `src/` usam minúsculas (`config.ts`, `db.ts`, `rotas.ts`). Conferir a convenção de nomes de arquivo antes de aprovar; se for classe, o padrão é um arquivo por classe, mas o nome não segue o restante do pacote.

10. **Helper estático de uma linha.** `PedidoHelper` tem um único método estático sem estado. Uma função exportada (`renderNota`) é mais simples e testável sem instanciar nada. Não é bloqueante.

11. **Mistura de `readFileSync` com handler assíncrono.** Em rota de alta frequência, leitura síncrona de arquivo bloqueia o event loop. Cachear o layout na inicialização do módulo resolve, junto com o item 2.

12. **Nenhum teste.** Para as duas rotas, o mínimo é um teste de contrato: status válido filtra, status inválido retorna 400, injeção não altera o resultado, nota de pedido inexistente retorna 404. Não foi possível executar testes nesta revisão (sem dependências instaladas e sem rede).

## O que ficou de fora

- Não há `package.json` na raiz com scripts de test, lint ou typecheck que possam ser executados sem instalar dependências. `tsc` e `eslint` não foram rodados.
- Não foi verificado o comportamento real do banco nem o do `pg` com múltiplas instruções; a afirmação sobre `DROP TABLE` é conservadora e depende do driver. A injeção por `OR '1'='1'` basta para classificar o achado como bloqueante.
- Não foi avaliado o modelo de dados da tabela `pedidos` (não está no pacote).

## Ordem sugerida de correção

1. Parametrizar a query e validar `status` (item 1).
2. Tratar erros nas duas rotas e retornar 404 para pedido inexistente (itens 3 e 4).
3. Versionar ou resolver o layout e validar `id` (item 2 e item 4).
4. Remover o `catch` vazio e mover `DESCONTO_PADRAO` para `config.ts` (itens 5 e 6).
5. Escrever os testes de contrato antes das correções, em vermelho primeiro (item 12).
6. Decidir autorização e paginação (itens 7 e 8) antes da PR.
