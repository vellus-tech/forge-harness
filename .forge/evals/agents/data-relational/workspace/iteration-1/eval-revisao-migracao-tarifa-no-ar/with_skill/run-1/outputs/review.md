# Revisão — services/tarifacao/db/migrations/V031__tarifa_por_linha.sql

Agente: `data-relational` (protocolo `.forge/agents/data/data-relational.md` + skill `data-relational-practices`).

## Veredito

Bloqueante. A migração não pode ir para o pipeline como está: dois dos três statements travam ou quebram a aplicação com a versão atual ainda no ar, e a tabela nova nasce sem o isolamento multi-tenant obrigatório. Abaixo, cada achado com o id do catálogo, evidência (`arquivo:linha`) e a correção.

## O que foi verificado

- **Rules e ADRs do projeto:** `.forge/rules/data/schema-evolution.md` (expand/migrate/contract), `.forge/rules/data/data-governance.md` (RLS obrigatório em tabela multi-tenant de domínio em PostgreSQL), `.forge/rules/domain/money-as-cents.md` (dinheiro em `BIGINT`, estendida pela decisão H-03(a) do dono a qualquer `*.sql`, não só a `backend-dotnet`/`frontend-react`/`android-kotlin` do `applies_to` original), `.forge/rules/conventions/database-naming.md` (sufixo `_cents`, `idx_{table}_{cols}`). Sem ADR do repositório sobre este change; nenhum conflito relevante entre rule e ADR — a tabela é paramétrica (tarifa por linha), que `data-governance.md` já atribui ao PostgreSQL, então não há bloco `CONFLITO` a devolver aqui.
- **Dado sensível:** `bash .forge/scripts/check-data-governance.sh --path services/tarifacao/db/migrations` devolveu `FAIL data-governance/universo-vazio` — o verificador só lê `.go/.kt/.ts/.rego/.py/.md`, não `.sql`, então isto é "não verificado por ele", não aprovação. Nenhum campo do diff é PAN ou PII (uuid de tenant, valor, data, FK) — verificado por leitura, não pelo script.
- **Varredura:** `bash .forge/skills/data-relational-practices/scripts/scan.sh --root services/tarifacao/db/migrations` (executado contra o arquivo em `work/`, já que o fixture remove `.forge/skills` do alvo para não contaminar o baseline) — achados abaixo, cada um lido e confirmado contra o SQL antes de entrar nesta lista.

## Achados

### 1. R-03 + R-21 (alto) — migração bloqueante sem `lock_timeout`, rodando com a app antiga no ar

`V031__tarifa_por_linha.sql:10` e `:12`:
```sql
ALTER TABLE linha RENAME COLUMN codigo TO codigo_linha;
CREATE INDEX idx_viagem_validador_id ON viagem (validador_id);
```
- **`RENAME COLUMN` in-place:** o README do serviço diz que a migração roda no pipeline com a versão anterior da aplicação ainda atendendo. Essa versão ainda faz `SELECT`/`INSERT` em `linha.codigo`; o rename quebra esse código no instante em que a migração aplica, não é só uma questão de lock — é incompatibilidade de contrato durante o deploy. `schema-evolution.md` exige expand → migrate → contract: renomear é fase de *contract*, só depois que a versão nova (que já lê `codigo_linha`) estiver no ar e a antiga aposentada.
- **`CREATE INDEX` sem `CONCURRENTLY`:** `viagem` tem ~60 milhões de linhas (README). Sem `CONCURRENTLY`, o `CREATE INDEX` toma `SHARE` lock na tabela e bloqueia todo `INSERT`/`UPDATE`/`DELETE` pelo tempo de construção do índice — em 60M linhas, isso é minutos com a aplicação (antiga e nova) travada na tabela mais quente do serviço.
- **Sem `lock_timeout` na sessão:** nem V031 nem qualquer `SET` prévio no script definem `lock_timeout` (V030 definia `'5s'` no topo; V031 não repete). Sem isso, se qualquer transação da app antiga segurar um lock competente, a migração fica enfileirada indefinidamente e, pior, enfileira atrás de si todo o tráfego que viria depois dela na mesma fila de lock.

### 2. R-20 — `tarifa_parametro` multi-tenant sem RLS

`V031__tarifa_por_linha.sql:2-8`: a tabela tem `tenant_id uuid NOT NULL` mas não tem `ENABLE ROW LEVEL SECURITY`, `FORCE ROW LEVEL SECURITY` nem `CREATE POLICY`. `data-governance.md` é taxativa: toda tabela multi-tenant de domínio em PostgreSQL tem RLS obrigatório, dispensa só por exceção formal documentada (não há uma aqui). Isto é bloqueante por padrão no catálogo do agente, não um "nice to have".

### 3. R-19 + `money-as-cents.md` (H-03(a)) + `database-naming.md` — dinheiro em `NUMERIC`

`V031__tarifa_por_linha.sql:6`: `valor_tarifa NUMERIC(10,2) NOT NULL`. A rule manda `BIGINT NOT NULL` na menor unidade para todo valor monetário; pela decisão H-03(a) do dono (2026-09-26) essa recomendação vale em qualquer `*.sql`, não só nas stacks do `applies_to` original da rule (backend-dotnet/frontend-react/android-kotlin) — sinalizando isso porque é uma extensão da skill, não uma mudança no `applies_to` da rule. `database-naming.md` reforça: valor monetário leva sufixo `_cents` (aqui, `_em_centavos` seguindo o padrão em português do restante do schema). Corrigir para `valor_tarifa_em_centavos BIGINT NOT NULL`.

### 4. R-04 (aviso) — tipos problemáticos

`V031__tarifa_por_linha.sql:3` (`id serial PRIMARY KEY`) e `:7` (`vigente_desde timestamp NOT NULL`):
- `serial` é `integer` (4 bytes, teto ~2,1 bilhões) e foge do padrão que o próprio V030 já usa (`bigint GENERATED ALWAYS AS IDENTITY`) — inconsistente e mais frágil a longo prazo numa tabela de parâmetro que tende a crescer com o tempo (uma linha por linha de ônibus por vigência).
- `timestamp` sem fuso perde a informação de timezone; o padrão do serviço (V030) é `timestamptz` em toda coluna de tempo.

### 5. R-01 (achado por revisão, não pelo `scan.sh` — detecção é `runtime`/heurística no catálogo) — FK sem índice

`tarifa_parametro.linha_id bigint NOT NULL REFERENCES linha(id)` não tem índice próprio (só entra no índice composto que a correção abaixo adiciona). Sem índice, qualquer `DELETE`/`UPDATE` em `linha` faria o PostgreSQL varrer `tarifa_parametro` inteira para checar a FK, e toda consulta "tarifas da linha X" faria sequential scan. Corrigido pelo índice composto `(tenant_id, linha_id)` da seção seguinte, que cobre o prefixo da FK e segue a convenção da casa (`tenant_id` na frente do índice composto).

## Versão corrigida

A correção do item 1 (rename bloqueante) exige separar o script em três migrações — `CREATE INDEX CONCURRENTLY` não pode rodar dentro de uma transação, e misturar isso com `CREATE TABLE`/RLS/policy (que devem ser atômicos) no mesmo script quebraria a atomicidade dessas últimas. Ficam nos arquivos abaixo, em `outputs/`:

- `V031__tarifa_parametro.sql` — tabela nova (RLS completo, FK indexada, dinheiro em centavos, timestamptz, identity), transacional normal porque a tabela nasce vazia e não compete por lock com tráfego existente.
- `V032__viagem_index_validador_concurrently.sql` — o índice em `viagem`, via `CREATE INDEX CONCURRENTLY` fora de transação (`-- flyway:executeInTransaction=false`, suportado pelo Flyway community desde a v7) e com `lock_timeout` explícito.
- `V033__linha_codigo_linha_expand.sql` — fase *expand* do rename: adiciona `codigo_linha`, faz backfill (seguro em lote único porque `linha` tem só alguns milhares de linhas, não 60M) e mantém `codigo` intocada. A fase *contract* (parar de escrever em `codigo`, então `DROP COLUMN codigo` ou renomear) fica para uma migração futura, só depois que a versão nova da aplicação — que passa a ler/escrever `codigo_linha` — estiver 100% no ar e a versão antiga aposentada; isso é decisão de rollout da aplicação, fora do escopo desta migração, e cabe a quem aplica (`task-coder`/agente de engenharia) coordenar com o deploy.

Quem aplica estas correções na árvore é o agente de engenharia ou o `task-coder` — este agente é consultivo e não escreve na árvore (uma árvore, um escritor).

## Pendência que não me cabe resolver

Manter `linha.codigo` e `linha.codigo_linha` sincronizadas entre o expand e o contract (dupla escrita na aplicação, ou trigger) é decisão de quem implementa o rollout da aplicação nova — mencionado aqui como requisito da migração segura, mas a escolha do mecanismo não é deste agente.
