# Code review — recarga via Pix (feat/recarga-pix → main)

## Resumo

O diff adiciona a rota `POST /recargas/pix`, o `service` e o `repository` de recargas, e ajusta o pool de Postgres em `src/db/pool.ts` para incluir `max` e o CA de TLS. Há um achado crítico de segurança (SQL injection) que bloqueia o merge, além de problemas de confiabilidade e validação de entrada. **Recomendação: não abrir o PR / não mergear antes de corrigir os itens críticos e altos.**

## Achados

### Crítico

- **SQL injection em `repository.ts`** — a query `INSERT INTO recargas (...)` é montada por interpolação de string com `cartaoId` e `valorCentavos` vindos direto do request body, sem parametrização. Qualquer valor malicioso em `cartaoId` executa SQL arbitrário no banco. Corrigir com query parametrizada (`$1`, `$2`, array de valores).

### Alto

- **Pool de conexão duplicado** — `inserirRecarga` cria um `new Pool(...)` próprio em vez de reaproveitar o `pool` já configurado em `src/db/pool.ts` (que agora tem `max: 10` e `ssl.ca`). Isso ignora o limite de conexões definido centralmente e vaza conexões sob carga.
- **Body da requisição sem validação** — `routes.ts` desestrutura `cartaoId`/`valorCentavos` de `req.body` sem checagem de schema, apesar de o projeto já usar `zod` (visto em `src/config/load.ts`). Entrada inválida ou ausente chega direto ao INSERT.

### Médio

- **Handler sem try/catch** — falha em `criarRecargaPix` (banco ou notificação) não é capturada no route handler.
- **Fire-and-forget sem `.catch`** — `notificarAntifraude(...).then(() => undefined)` descarta a Promise sem tratar rejeição; falha de rede vira `unhandledRejection` silencioso e a notificação antifraude falha sem log.
- **`fetch` sem timeout nem checagem de `response.ok`** — chamada de antifraude pode travar indefinidamente ou tratar erro HTTP como sucesso.

### Baixo

- **Retorno `Promise<any>`** em `inserirRecarga` apesar do tipo `Recarga` já existir no arquivo; enfraquece a checagem estática em `service.ts`.
- **Pool sem `pool.on('error', ...)`** — driver `pg` recomenda listener de erro no pool para não derrubar o processo em erro de conexão ociosa.

### Info

- **Sem testes novos** para o fluxo de recarga Pix (rota, service, repository).

## Observação sobre o ambiente

Este projeto não tem `eslint.config` disponível na árvore analisada (baseline sem lint configurado para o pack `backend-node-postgres`); a revisão foi feita por leitura manual do diff, sem apoio de lint/tipo automatizado.

## Formato dos findings

Os achados estruturados estão em `review/node-review.json`, com campos `file`, `line`, `severity`, `category`, `summary`, `detail`, `recommendation`, e um bloco `summary` agregando contagens por severidade e o motivo de bloqueio.
