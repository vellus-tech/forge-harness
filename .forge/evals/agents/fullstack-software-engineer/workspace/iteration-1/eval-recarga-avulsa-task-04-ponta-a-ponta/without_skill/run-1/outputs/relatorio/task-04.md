# Relatório — TASK-04: recarga avulsa ponta a ponta

## O que foi implementado

**Contrato (`contracts/openapi/api-recarga.yaml`)** — adicionado `POST /recargas`: header `Idempotency-Key` (UUID) obrigatório, corpo `{ cartaoId, valorCentavos }` com `valorCentavos` entre 100 e 50000, resposta `201` na criação e `200` no reenvio com a mesma chave, erros no shape `{ code, message }` já usado pelo `GET`.

**Migration (`services/api-recarga/migrations/002_add_idempotency_key.sql`)** — coluna `idempotency_key UUID NOT NULL` com índice único (`idx_recargas_idempotency_key`). A unicidade é garantida pela constraint do banco, não por checagem em memória, conforme DD-002.

**Repositório (`services/api-recarga/src/recargas/repository.ts`)** — novo método `createRecarga`: `INSERT ... ON CONFLICT (idempotency_key) DO NOTHING RETURNING ...`; quando o `INSERT` não retorna linha (chave já usada), busca a recarga existente por `idempotency_key` e devolve `created: false`. Isso evita corrida entre checar-e-inserir.

**Rota (`services/api-recarga/src/recargas/routes.ts`)** — `POST /recargas`: 400 `MISSING_IDEMPOTENCY_KEY` sem o header; validação do corpo via `zod` (400 `INVALID_BODY` fora da faixa 100–50000); `201` quando `created`, `200` quando a chave já existia.

**Cliente do portal (`apps/web/portal-recarga/src/api/client.ts`)** — `criarRecarga({ cartaoId, valorCentavos, idempotencyKey })`, único ponto de chamada HTTP do portal (DD-003), reaproveitando `request()` e `ApiError` já existentes.

**Componente (`apps/web/portal-recarga/src/components/NovaRecargaForm.tsx`)** — formulário controlado com estados `idle | submitting | error | success`; converte o valor digitado (`"10,00"`) para centavos e valida a faixa R$ 1,00–R$ 500,00 no cliente antes de chamar a API; botão e campo ficam desabilitados durante o envio (REQ-04); erro em `role="alert"`, sucesso em `role="status"` (acessível a leitor de tela). A `Idempotency-Key` é gerada uma vez por tentativa de compra (`useRef`) e só é trocada após sucesso — em caso de erro, a mesma chave é reaproveitada no reenvio, para que um retry de rede ou novo clique não crie duas recargas (REQ-03).

## Testes (TDD-first)

Testes escritos antes da implementação correspondente, cobrindo os casos do requirements/design:

- `services/api-recarga/src/recargas/routes.test.ts` — `POST /recargas`: falta de `Idempotency-Key`, `valorCentavos` abaixo de 100 e acima de 50000, criação (`201`) e reenvio com a mesma chave (`200`, sem nova chamada ao repositório).
- `apps/web/portal-recarga/src/components/NovaRecargaForm.test.tsx` — validação client-side fora da faixa, bloqueio do formulário durante o envio + mensagem de sucesso, erro acessível vindo da API, e reaproveitamento da `Idempotency-Key` entre uma tentativa que falha e o reenvio.

Também foi criado `apps/web/portal-recarga/vitest.config.ts` (`environment: "jsdom"`) porque o pacote não tinha configuração de ambiente de teste para componentes React — sem isso os testes de DOM não rodariam sob Vitest.

## Não executado / limitação desta rodada

Por restrição explícita desta tarefa de avaliação, **não rodei `npm install`, `npm test` nem qualquer comando de build/lint** — os testes acima foram escritos seguindo TDD (vermelho esperado antes da implementação, verde depois), mas essa transição não foi observada em execução real, só verificada por leitura atenta do código. Isso é uma lacuna real desta entrega: normalmente eu rodaria a suíte antes de declarar a task concluída.

Também noto, sem alterar (fora do escopo da TASK-04): o pacote `apps/web/portal-recarga` não tem `tsconfig.json` próprio nem `@testing-library/jest-dom`/`@types/react` nas dependências — isso já era assim antes desta mudança (o componente `HistoricoRecargas.tsx` também não tinha teste). Vale um follow-up de infraestrutura de testes do portal.

## Itens do design/requirements cobertos

- REQ-02 (faixa de valor, mensagem clara) — validação client-side e server-side.
- REQ-03 (sem duplicidade em duplo clique/retry) — botão desabilitado durante envio + constraint de unicidade no banco + reaproveitamento da chave em erro.
- REQ-04 (bloqueio durante envio, erro acessível) — `disabled` no formulário, `role="alert"`/`role="status"`.
- DD-001 (centavos, inteiro) — `valorCentavos` como `number` inteiro em todo o fluxo.
- DD-002 (Idempotency-Key, constraint de banco) — índice único na migration, sem checagem em memória.
- DD-003 (client.ts único ponto de chamada) — `criarRecarga` adicionado ao `client.ts` existente.
- DD-004 (contrato antes do código) — OpenAPI atualizado antes da implementação da rota.
