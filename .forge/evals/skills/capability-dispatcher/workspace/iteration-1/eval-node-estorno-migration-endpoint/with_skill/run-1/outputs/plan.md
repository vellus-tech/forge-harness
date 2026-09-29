# Plano de implementação — estorno parcial em `payments-api`

## Escopo

Adicionar suporte a estorno parcial de um pagamento: uma coluna que acumula o valor já estornado na tabela `payments` e um endpoint `POST /payments/:id/refunds` que registra o estorno feito pelo merchant identificado no header `x-merchant-id`. Este documento é só o plano — nada foi implementado ainda, conforme pedido.

## Stack e convenções aplicáveis (capability pack `backend-node-postgres`)

O projeto já declara `capabilities.active: [backend-node-postgres]` em `.forge/forge.yaml`, então segui o protocolo do `capability-dispatcher`: li apenas o `PROFILE.md` desse pack (não os demais packs do catálogo, que não se aplicam a esta área) e as rules transversais que ele aponta para trabalho com migration e endpoint — `rules/data/schema-evolution.md` e `rules/testing/change-test-contract.md`. A stack observada no `package.json` e no código existente (`src/routes/payments.ts`, `src/db/client.ts`) é Fastify + `pg` (client `Pool` cru, sem ORM) + `zod` para validação de borda + `vitest` para testes + `node-pg-migrate` para migrations SQL — o plano segue esse padrão já estabelecido em vez de introduzir ORM, framework de validação ou runner de teste novos, como o pack manda ("prefira o padrão existente"; "nunca substitua o package manager do projeto").

O pack também aponta o `node-baseline.sh` como primeira camada de enforcement (ESLint com as regras `forge-quality/*`). Não encontrei um `eslint.config.*` já materializado na raiz de `work/` — isso é um pré-requisito do pack que este plano registra como pendência de infraestrutura, não algo que a task de código deva resolver por conta própria (ver seção de verificação).

## Divergência registrada (protocolo do dispatcher, item 4)

A rule `rules/architecture/api-and-contracts.md` exige que toda API seja versionada (`/api/v1/...`). O código existente (`GET /payments/:id`) **não** segue isso — não há prefixo de versão em nenhuma rota atual. Por brownfield, o código existente é a fonte de maior precedência sobre a rule nesta implementação pontual: o novo endpoint segue o padrão vigente sem prefixo (`POST /payments/:id/refunds`), sem refatorar as rotas existentes para introduzir versionamento por conta própria. Registro a divergência aqui e sugiro abrir um item de ledger separado para decidir se `payments-api` adota `/api/v1/` — decisão de arquitetura que não cabe dentro desta mudança pontual.

## Modelagem de dados

Duas peças, ambas na fase **expand** do fluxo de `schema-evolution.md` (adicionar sem remover nada do caminho antigo):

1. **Coluna `refunded_amount_cents` em `payments`** — exatamente o que foi pedido: `BIGINT NOT NULL DEFAULT 0`, seguindo `domain/money-as-cents.md` (inteiro em centavos, nunca `DECIMAL`/`NUMERIC`) e o sufixo `_cents` de `conventions/database-naming.md`. É o saldo acumulado, útil para checar rapidamente quanto já foi estornado sem somar uma tabela de eventos a cada request.

2. **Tabela `payment_refunds`** (proposta além do pedido explícito, com trade-off explicado abaixo) — um registro por evento de estorno: `id uuid PRIMARY KEY`, `payment_id uuid NOT NULL REFERENCES payments(id)`, `merchant_id uuid NOT NULL`, `amount_cents BIGINT NOT NULL`, `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`. Nomenclatura em `snake_case`, chave estrangeira `fk_payment_refunds_payments`, índice `idx_payment_refunds_payment_id`.

**Por que a tabela extra e não só a coluna:** `refunded_amount_cents` sozinha é um contador mutável — não há trilha de quando, quanto e por qual requisição cada estorno aconteceu, e `rules/architecture/security-and-compliance.md` exige "audit trail completo de ações sensíveis (quem, quando, o quê)" para dados de pagamento, com `domain/audit-immutability.md` pedindo append-only via REVOKE + trigger para tabelas de auditoria/ledger. Um estorno é dinheiro saindo — é exatamente o tipo de evento que essa rule cobre. **Alternativa descartada:** só a coluna, sem tabela de eventos, que é mais simples e atende ao pedido literal, mas deixa a auditoria dependendo de logs de aplicação (não imutáveis, não é a "última linha de defesa" que a rule exige). Escolhi propor a tabela porque o custo de implementação é baixo (uma migration a mais) e o risco de não ter trilha auditável em fluxo de dinheiro é alto; a decisão final de aplicar o REVOKE+trigger completo de `audit-immutability.md` (que é mais pesado — função `prevent_immutable_table_modification`, revogar UPDATE/DELETE do role `app`) fica sinalizada como pergunta em aberto para quem aprovar o design, não decidida unilateralmente aqui.

**Migration (expand, idempotente):**

```sql
-- Up
ALTER TABLE payments ADD COLUMN IF NOT EXISTS refunded_amount_cents BIGINT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS payment_refunds (
  id uuid PRIMARY KEY,
  payment_id uuid NOT NULL REFERENCES payments(id),
  merchant_id uuid NOT NULL,
  amount_cents BIGINT NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_payment_refunds_payment_id ON payment_refunds(payment_id);

-- Down
DROP TABLE IF EXISTS payment_refunds;
ALTER TABLE payments DROP COLUMN IF EXISTS refunded_amount_cents;
```

`IF NOT EXISTS`/`IF EXISTS` tornam a migration reexecutável, como `schema-evolution.md` exige. Não há dado histórico afetado (coluna nova com default 0, tabela nova vazia), então não há backfill nesta migration.

## Endpoint `POST /payments/:id/refunds`

- **Validação de borda (zod):** `id` como `uuid` no path (igual ao `GET` existente); corpo `{ amount_cents: number }` com `amount_cents` inteiro positivo (`z.number().int().positive()`) — nunca `decimal`/`float`, conforme `domain/money-as-cents.md`. `x-merchant-id` obrigatório no header, mesmo padrão do `GET /payments/:id` atual.
- **Ownership / IDOR:** busca o pagamento filtrando por `id AND merchant_id = $2` na mesma query (replicando o padrão já usado em `GET /payments/:id` — não vazar existência do recurso a outro merchant). Se não encontrar, `404 { error, code: "not_found", correlationId }`, exatamente como a rota existente já faz — não `403`, para não confirmar a um merchant que o pagamento existe e pertence a outro. Isso cobre o teste positivo/negativo de autorização por ownership que `change-test-contract.md` exige para "endpoint com recurso do usuário/tenant".
- **Regra de negócio:** o estorno não pode fazer `refunded_amount_cents` (após a operação) ultrapassar `amount_cents` do pagamento — senão `422 { error, code: "refund_exceeds_amount", correlationId }`. Erro de validação/regra de negócio não deve ter efeito colateral algum (nada persiste), conforme `api-and-contracts.md`.
- **Concorrência:** a leitura do pagamento e a atualização do saldo + inserção do evento acontecem em uma única transação SQL com `SELECT ... FOR UPDATE` na linha de `payments`, para dois estornos concorrentes no mesmo pagamento não ultrapassarem o limite por corrida (`check`/`UPDATE` sem lock é uma race condition clássica em saldo).
- **Resposta de sucesso:** `201` com o registro do estorno criado (`id`, `payment_id`, `amount_cents`, `created_at`) e o novo `refunded_amount_cents` do pagamento.
- **Erros:** seguem a estrutura padrão de `api-and-contracts.md` — `{ error, code: "SNAKE_UPPER_OU_snake", correlationId }`, sem stack trace exposto.

## Testes (contrato mínimo, `change-test-contract.md`)

Aplicáveis a esta mudança:

- **Persistência/migration:** teste de integração contra Postgres real, exercitando a migration no caminho de teste. **Pendente** — ver seção de verificação.
- **Endpoint com recurso do tenant:** teste positivo (merchant dono estorna com sucesso) e teste negativo de ownership (merchant B tentando estornar pagamento de merchant A recebe 404, não vaza existência). **Pendente de banco real** para rodar de ponta a ponta; a lógica de seleção da query pode ser revisada estaticamente.
- **Lógica de domínio/aplicação:** invariante "estorno acumulado nunca ultrapassa o valor original" é uma propriedade pura o suficiente para TDD/PBT se a checagem for extraída para uma função sem I/O (`calcularSaldoEstornavel(amountCents, refundedAmountCents, novoEstornoCents)`); esse teste **não depende de banco** e pode rodar nesta máquina.
- Mocks só substituem fronteira que o teste não controla (aqui, nada externo além do próprio Postgres) — não vou mockar o `pg.Pool` para fingir um teste de integração; se a infraestrutura não estiver disponível, o teste de integração fica registrado como pendente, nunca como aprovado por um mock que não prova nada.

## Verificação — o que dá para provar nesta máquina (sem Postgres local, sem Docker)

**Provável agora:**
- `tsc -p .` (typecheck) sobre o código novo e a extração da função pura de saldo.
- `vitest run` para os testes unitários da função `calcularSaldoEstornavel` (positivo, exatamente no limite, e negativo além do limite) e para a validação zod do corpo do request (amount_cents ausente, zero, negativo, não-inteiro).
- Leitura estática da migration SQL (sintaxe, idempotência via `IF NOT EXISTS`/`IF EXISTS`, convenção de nomenclatura) — não é execução, é revisão.
- `bash .forge/scripts/node-baseline.sh --check` para confirmar se o `eslint.config.mjs` do pack está materializado antes de escrever código (hoje não está, então isso reprova até ser aplicado).

**Não provável agora, fica como evidência pendente declarada (nunca "aprovado"):**
- Rodar a migration de fato contra um Postgres (`node-pg-migrate up`) — precisa de instância real.
- Teste de integração do endpoint completo (INSERT/UPDATE reais, `SELECT ... FOR UPDATE`, comportamento sob concorrência).
- Teste do trigger de imutabilidade em `payment_refunds`, caso a decisão de design confirme aplicar `audit-immutability.md` — exige Postgres real (o próprio rule pede Testcontainers).
- Teste de ownership de ponta a ponta via HTTP real (Fastify `inject` ainda roda sem rede, mas depende do `pool` conectado a um banco).

## Questões em aberto para quem aprovar o design

1. Aplicar o REVOKE + trigger de `audit-immutability.md` em `payment_refunds` agora, ou tratar como hardening futuro? O plano acima cria a tabela mas não inclui o trigger — decisão de escopo, não técnica.
2. `payments-api` deveria adotar `/api/v1/` agora, aproveitando a mudança, ou manter a divergência registrada acima e tratar versionamento em item de ledger separado?
3. Endpoint aceita estorno em qualquer status de pagamento ou só em `status = 'succeeded'`? O fixture não define a máquina de estados de `status`; o plano assume que a validação de status elegível para estorno é regra de negócio a confirmar antes da implementação, não algo a inferir.
