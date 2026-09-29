# Plano — estorno parcial em payments-api

## Escopo

Adicionar suporte a estorno parcial de pagamentos: coluna `refunded_amount_cents` na tabela `payments` e endpoint `POST /payments/:id/refunds` que registra o estorno feito pelo merchant autenticado via header `x-merchant-id`. Este documento é só o plano — nada foi implementado.

## Stack observada no repositório

Node.js + TypeScript (ESM, `type: module`), Fastify 4 como framework HTTP, `pg` como driver Postgres cru (sem ORM), Zod para validação de schema, `node-pg-migrate` para migrations SQL versionadas em `migrations/`, Vitest para testes, pnpm como gerenciador de pacotes. O endpoint existente (`GET /payments/:id`) já mostra o padrão a seguir: Zod parseia params, a query usa `merchant_id` como filtro de posse vindo do header `x-merchant-id`, e 404 quando o recurso não pertence ao merchant do header.

## Rules do projeto que este plano segue

- **`domain/money-as-cents.md`**: todo valor monetário é inteiro em centavos, nunca `decimal`/`float`. Coluna nova é `BIGINT NOT NULL`, e no TypeScript o campo é `number` inteiro (ou `bigint` se o valor puder exceder `Number.MAX_SAFE_INTEGER`, o que não é o caso esperado aqui). Nomenclatura AP: sufixo `_cents` no banco (já é a convenção do projeto: `amount_cents`), e o mesmo padrão vale para `refunded_amount_cents`.
- **`conventions/database-naming.md`**: identificadores em `snake_case` no Postgres. `refunded_amount_cents` já respeita isso; tabela nova de estornos (se optarmos por uma, ver alternativa abaixo) seguiria plural (`refunds`) com PK `refund_id` e FK `payment_id`.
- **`data/schema-evolution.md`**: a alteração é *expand* pura — adicionar coluna nullable/DEFAULT 0 sem remover nada, sem quebra de compatibilidade. Migration precisa ser idempotente e declarar estratégia de rollback (down migration que remove a coluna). Não há necessidade de backfill em lote porque a tabela não tem estornos históricos a migrar (dado não observado no fixture, mas seria confirmado antes de rodar em produção real).
- **`architecture/api-and-contracts.md`**: endpoint deve responder com corpo de erro padrão (`error`, `code`, `correlationId`) em falhas, validação de input com Zod antes de qualquer efeito colateral, e nomenclatura kebab-case nos recursos (`/payments/:id/refunds` já está correto). O projeto ainda não usa prefixo de versão (`/api/v1/...`) no endpoint existente — o plano mantém consistência com o padrão atual (`/payments/:id`) em vez de introduzir versionamento isolado só para este endpoint; isso deveria ser levantado como decisão de arquitetura mais ampla, fora do escopo desta task.
- **`domain/audit-immutability.md`**: um estorno é um evento financeiro relevante para auditoria. Recomendo registrar cada estorno como linha *append-only* numa tabela `refunds` (não só um contador mutável em `payments.refunded_amount_cents`), com trigger de imutabilidade (`BEFORE UPDATE OR DELETE` lançando exceção) e REVOKE de UPDATE/DELETE para o role de aplicação. A coluna `refunded_amount_cents` em `payments` funciona como saldo agregado (derivado, atualizado só por INSERT em `refunds` dentro da mesma transação), nunca como a fonte de verdade do histórico.
- **`testing/tdd.md`**: ciclo Red-Green-Refactor obrigatório. Testes unitários para a validação de regra de negócio (estorno não pode exceder saldo disponível) e testes de integração para o fluxo HTTP completo (feliz, 404 por merchant errado, 422 por valor inválido/excedente).
- **`conventions/no-ai-attribution.md`** e **`conventions/conventional-commits.md`**: quando a implementação for feita de fato, commits sem atribuição de IA e no formato Conventional Commits — não se aplica a este plano em si, mas fica registrado para a fase de implementação.

## Desenho proposto

### 1. Migration (`migrations/<timestamp>-create-refunds.sql`)

```sql
-- Up Migration
ALTER TABLE payments
  ADD COLUMN refunded_amount_cents BIGINT NOT NULL DEFAULT 0;

ALTER TABLE payments
  ADD CONSTRAINT payments_refunded_amount_cents_check
  CHECK (refunded_amount_cents >= 0 AND refunded_amount_cents <= amount_cents);

CREATE TABLE refunds (
  refund_id uuid PRIMARY KEY,
  payment_id uuid NOT NULL REFERENCES payments(id),
  merchant_id uuid NOT NULL,
  amount_cents BIGINT NOT NULL CHECK (amount_cents > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_refunds_payment_id ON refunds(payment_id);

CREATE OR REPLACE FUNCTION prevent_immutable_table_modification()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Tabela imutável: operação % proibida em %.%', TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_refunds_immutable
BEFORE UPDATE OR DELETE OR TRUNCATE ON refunds
FOR EACH STATEMENT EXECUTE FUNCTION prevent_immutable_table_modification();

REVOKE UPDATE, DELETE, TRUNCATE ON refunds FROM app;

-- Down Migration
DROP TRIGGER IF EXISTS trg_refunds_immutable ON refunds;
DROP TABLE IF EXISTS refunds;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_refunded_amount_cents_check;
ALTER TABLE payments DROP COLUMN IF EXISTS refunded_amount_cents;
```

Observação: `REVOKE ... FROM app` pressupõe que exista um role `app` distinto do role de migration (dono do schema); se o projeto real não tiver essa separação de roles hoje, isso é um pré-requisito a validar antes de aplicar — não invento a existência do role sem confirmar no ambiente alvo.

### 2. Rota (`src/routes/payments.ts`)

Adicionar handler `POST /payments/:id/refunds`:

1. Validar `:id` (uuid) com Zod, igual ao endpoint existente.
2. Ler `x-merchant-id` do header e validar formato (uuid) — hoje o endpoint GET nem valida isso, é uma lacuna que o novo endpoint não deveria repetir.
3. Validar body com Zod: `{ amount_cents: z.number().int().positive() }`.
4. Dentro de uma transação (`BEGIN`/`COMMIT`):
   a. `SELECT id, amount_cents, refunded_amount_cents, merchant_id FROM payments WHERE id = $1 FOR UPDATE` — lock de linha para evitar race condition entre estornos concorrentes.
   b. Se não encontrado ou `merchant_id` não bate com o header: `404 { error: "not_found" }` (mesmo padrão do GET, mantendo o merchant errado indistinguível de inexistente, por segurança).
   c. Se `amount_cents` do body > (`amount_cents` - `refunded_amount_cents`): `422 { error: "saldo insuficiente para estorno", code: "REFUND_EXCEEDS_BALANCE", correlationId }`.
   d. `INSERT INTO refunds (refund_id, payment_id, merchant_id, amount_cents) VALUES (gen_random_uuid(), $1, $2, $3)`.
   e. `UPDATE payments SET refunded_amount_cents = refunded_amount_cents + $1 WHERE id = $2`.
5. Responder `201` com o registro do estorno criado (`refund_id`, `payment_id`, `amount_cents`, `created_at`).
6. Erros de validação do Zod (400) e erros inesperados (500) seguem o formato padrão de erro do projeto (`error`, `code`, `correlationId`) — hoje o GET não segue esse contrato integralmente; o novo endpoint deveria, e isso pode motivar um ajuste futuro no GET também (fora do escopo desta task, registrar como débito).

### 3. Testes (`test/payments.test.ts` e novo `test/refunds.test.ts`)

TDD: escrever os testes antes do código de produção.

- Unitário/lógica pura: função de cálculo de saldo disponível (`amount_cents - refunded_amount_cents`) e regra de "não excede saldo" isolada como função testável sem banco.
- Integração HTTP (via `app.inject()` do Fastify, sem subir servidor real):
  - Estorno parcial válido → 201, `refunded_amount_cents` atualizado.
  - Estorno que excede saldo → 422.
  - `x-merchant-id` de outro merchant → 404.
  - `amount_cents` não positivo ou ausente → 400.
  - Dois estornos concorrentes que juntos excedem o saldo → o segundo falha (exercita o lock `FOR UPDATE`).
- Os testes de integração precisam de um Postgres real (ou Testcontainers) — ver seção de verificação abaixo sobre o que dá para provar nesta máquina.

## Verificação — o que dá para provar nesta máquina

Esta máquina não tem Postgres local nem Docker disponíveis, então nada que dependa de banco real pode ser executado nem comprovado aqui. Divido o que é verificável do que não é:

**Verificável sem banco:**
- `tsc -p .` (typecheck) sobre o código novo, incluindo os tipos de request/response do novo handler.
- `eslint .` sobre os arquivos alterados.
- Testes unitários puros (cálculo de saldo, validação Zod) rodando via `vitest run` — não tocam `pool`/Postgres, só a lógica de domínio isolada em função pura.
- Revisão estática da migration SQL (sintaxe, convenção de nomes, presença de down migration) — não prova que ela roda, só que está bem formada.

**Não verificável nesta máquina, exige Postgres/Docker (ou ambiente CI com serviço de banco):**
- Rodar a migration de fato (`pnpm migrate`) e confirmar que a coluna e a tabela `refunds` são criadas corretamente.
- Testes de integração que batem em `pool.query` real: caminho feliz, 404 por merchant, 422 por saldo insuficiente, race condition do `FOR UPDATE`.
- Confirmar que o trigger de imutabilidade de fato bloqueia `UPDATE`/`DELETE` em `refunds` (só um teste contra Postgres real prova isso — mockar a query não verifica o trigger).
- Teste de carga/concorrência real dos dois estornos simultâneos.

**Recomendação prática:** antes de considerar a implementação pronta, rodar a suíte de integração num ambiente com Postgres (CI do projeto, ou Docker localmente em outra máquina) — sem isso, os itens do segundo grupo continuam como "implementado mas não comprovado", e a linha de auditoria e a regra de saldo insuficiente são justamente os pontos de maior risco financeiro, então não deveriam ser dados como concluídos só pela leitura do código.
