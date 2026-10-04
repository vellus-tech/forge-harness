# Triagem do scan de qualidade: servico-cobranca

## Sumário executivo

O scan `node-quality-scan` reprovou com cinco achados, mas só um é defeito de verdade e precisa entrar no release de sexta: a query de `marcarPaga` monta SQL por interpolação de string com o `id` vindo direto da rota HTTP `POST /cobrancas/:id/pagamento`. Os outros quatro são falsos positivos do scanner ou decisões de arquitetura deliberadas, e podem ficar como estão. Antes disso, o próprio baseline de lint reprova, porque o `eslint.config.mjs` com as regras `forge-quality/*` não está cabeado no repositório; isso não é defeito de runtime, mas significa que a camada de lint não está protegendo o serviço hoje. Nenhum código foi alterado nesta triagem.

## Estado do baseline de lint

O `node-baseline.sh --check` reprovou: não existe `eslint.config.mjs` na raiz, então nenhuma regra `forge-quality/*` entra no lint, e oito arquivos `.ts` não têm parser TypeScript no ESLint. A correção é materializar a baseline com `bash .forge/scripts/node-baseline.sh --apply` num change próprio, e não dentro do hotfix de SQL, para manter o diff pequeno. Esta triagem não rodou `--apply` porque isso escreve configuração no repositório.

## Achado por achado

### 1. sql-interpolation (BLOCKER): defeito real, corrigir antes do release

Local: `src/infra/PgCobrancaRepository.ts:13`, método `marcarPaga`.

O `id` entra na string por template literal: `` `UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = '${id}'` ``. O valor chega de `req.params.id` em `src/rotas.ts:7`, na rota `POST /cobrancas/:id/pagamento`, que não valida formato nem autentica no código lido. Um `id` contendo aspas simples altera a query, e isso é injeção de SQL alcançável pela superfície HTTP. O restante do repositório (`buscar`, linha 8) já usa `$1`, então o desvio é local a esse método.

Correção: trocar por `this.pool.query("UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = $1", [id])`. Vale acrescentar um teste de integração ou unitário que tente um `id` com aspas, e validar o formato do `:id` na rota, já que o `id` das cobranças é string e o contrato dele não está explícito. Também vale verificar se a rota de pagamento tem autenticação na camada de fora do serviço, porque o escopo do dano depende disso.

### 2. sync-fs-blocking (BLOCKER): não é defeito, deixar como está

Local: `src/boot.ts:9`, `readFileSync(config.certPath, "utf8")`.

A chamada roda uma vez, no topo do módulo, antes de `app.listen`, e o próprio comentário registra isso. Nenhum request concorrente existe nesse momento, então o bloqueio do event loop não afeta ninguém. É a exceção de bootstrap descrita em `references/clean-code-rules.md`. Não há motivo para trocar por versão assíncrona.

Há dois pontos vizinhos que não são o achado do scan e merecem leitura separada. A linha 11 passa `{ cert, key: cert }`, ou seja, usa o mesmo arquivo como certificado e como chave privada; isso só funciona se o PEM contiver as duas partes, e vale confirmar com o arquivo real. O `as never` na mesma linha esconde a incompatibilidade de tipos do Fastify e desliga a checagem exatamente onde ela importa.

### 3. new-pg-client (HIGH): não é defeito, deixar como está

Local: `src/db/bootstrap.ts:5`, `new Pool(...)`.

O arquivo é o único ponto de criação do pool, declarado no próprio cabeçalho e importado uma vez por `boot.ts`. A regra existe para pegar `new Pool()` espalhado por request, e aqui isso não acontece. O scanner não reconheceu o arquivo como bootstrap, o que é falso positivo da ferramenta, não do código. Vale ajustar a exceção do scanner para esse caminho. Um detalhe menor: `max: 10` é fixo e não é configurável por ambiente, o que pode virar ajuste de operação, mas não é defeito.

### 4. floating-promise (HIGH): falso positivo, deixar como está

Local: `src/jobs/lembrete.ts:4-7`.

A cadeia tem `.catch((err) => log(...))` na linha 7. O scanner olha uma linha por vez e não viu o `.catch`, que é exatamente a limitação documentada em `detection-commands.md`. O tratamento de erro existe e registra a falha. Há uma observação separada: `agendarLembrete` não é chamada em nenhum ponto de `src/` nem de `test/`, então ou é código morto ou é chamada de fora do repositório. Vale confirmar antes de decidir se a função fica.

### 5. single-impl-interface (MEDIUM): não é defeito, deixar como está

Local: `src/domain/CobrancaRepository.ts`.

A interface é a porta do domínio, declarada pelo domínio, com a implementação em `src/infra/PgCobrancaRepository.ts`. A segunda implementação existe em `test/fakes.ts` (`repoEmMemoria`), que é o fake em memória que o próprio cabeçalho do arquivo menciona. Isso é a fronteira hexagonal deliberada descrita nas exceções da regra. Remover a interface seria o defeito, não mantê-la.

## Recomendação para o release de sexta

Corrigir o item 1 (parametrizar a query e cobrir com teste) e tratar o `id` da rota antes de publicar. Os itens 2 a 5 não bloqueiam o release. Como ação separada, materializar o baseline de lint em um change próprio e ajustar as exceções do scanner para o arquivo de bootstrap e para o padrão de `.catch` em linha seguinte.

## Limites desta triagem

Não rodei `npm test`, porque o projeto não tem `node_modules` e instalar dependências exige rede, que esta execução não permite. A avaliação do item 1 é por leitura do código, sem reproduzir a injeção contra um banco. Não verifiquei a camada de autenticação fora deste repositório.
