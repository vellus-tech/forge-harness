# Revisão de banco — tarifas-config (pré-deploy de quinta)

## Sumário executivo

A migração V002 (`services/tarifas-config/migrations/V002__integracao_e_parametros.sql`) não é segura para subir com o serviço no ar contra uma tabela `tarifas` com ~40 milhões de linhas. Ela mistura, num único arquivo, DDL que bloqueia a tabela inteira (`CREATE INDEX` sem `CONCURRENTLY`, `ALTER COLUMN ... TYPE`, `SET NOT NULL`), um `UPDATE` em massa sem lote, um `RENAME COLUMN` sem período de compatibilidade, e uma `FOREIGN KEY` para uma tabela `operadores` que não existe em nenhuma migração anterior — isso provavelmente faz a migração falhar antes mesmo de chegar nos problemas de lock. Adicionalmente, `tarifas_repo.ts` usa `set_config('app.tenant_id', ...)` em nível de sessão numa conexão de pool sem transação, o que é um padrão conhecido de vazamento de dados entre tenants quando a conexão volta ao pool. Recomendo não subir a V002 como está; abaixo o diagnóstico item a item e o SQL corrigido.

## Migrações

### V001 — ok, referência de estilo

Usa `lock_timeout`, identidade (`GENERATED ALWAYS AS IDENTITY`), RLS com `FORCE ROW LEVEL SECURITY` e índice composto alinhado ao padrão de acesso (`tenant_id, linha_id`). É o padrão que a V002 deveria seguir e não segue.

### V002 — achados, em ordem de severidade

1. **FK para tabela inexistente (bloqueador).** `parametros_operador.operador_id bigint NOT NULL REFERENCES operadores (id)` referencia uma tabela `operadores` que não aparece em V001 nem em V002. Se `operadores` não existir em produção, a migração falha no meio da transação — com `RENAME COLUMN` e `ALTER TYPE` já aplicados antes dela, dependendo de como o runner trata a falha (rollback só funciona se tudo estiver na mesma transação, e `CREATE INDEX CONCURRENTLY`, que é a correção do item 2, não pode rodar dentro de transação). Confirmar se `operadores` existe antes de tudo; se não existir, remover a FK ou criar a tabela numa migração anterior.

2. **`CREATE INDEX` sem `CONCURRENTLY` em tabela de 40M linhas, com o serviço no ar (bloqueador).** `CREATE INDEX idx_tarifas_vigencia ON tarifas (vigente_desde);` sem `CONCURRENTLY` toma lock `SHARE`, que bloqueia todo `INSERT`/`UPDATE`/`DELETE` em `tarifas` pela duração da construção do índice — em 40M linhas isso pode levar minutos, travando o serviço em produção. Precisa de `CREATE INDEX CONCURRENTLY`, que não pode rodar dentro de bloco de transação — então essa migração não pode ser transacional inteira (ou esse statement sai para uma migração própria, não-transacional).

3. **`ALTER COLUMN ... TYPE numeric(7,4)` reescreve a tabela inteira (bloqueador).** Mudar a precisão/escala de `numeric` não é uma alteração metadata-only — força reescrita completa da tabela sob lock `ACCESS EXCLUSIVE`, bloqueando leitura e escrita em `tarifas` durante toda a reescrita. Em 40M linhas, com o serviço no ar numa quinta, isso é indisponibilidade, não manutenção. `numeric(5,2)` → `numeric(7,4)` amplia a escala (2→4 casas decimais), o que também é uma mudança de semântica de dado, não só de tamanho — precisa confirmar se os valores existentes fazem sentido com 4 casas decimais ou se é erro de especificação.

4. **`UPDATE` em massa sem lote (bloqueador de performance/replicação).** `UPDATE tarifas SET valor_integracao = 0 WHERE valor_integracao IS NULL;` roda logo após adicionar a coluna, então atualiza as ~40M linhas de uma vez: gera bloat maciço (cada UPDATE em Postgres é um novo tuple), pressiona WAL/replicação, e mantém locks de linha por uma transação longa. Precisa rodar em lotes (ex.: por faixa de `id`, `LIMIT` + `COMMIT` intermediário), fora da transação da migração de DDL.

5. **`SET NOT NULL` sem `CHECK ... NOT VALID` prévio (bloqueador).** `ALTER COLUMN valor_integracao SET NOT NULL` direto faz um scan completo da tabela sob lock que bloqueia escrita, para validar a constraint. O padrão seguro é: `ADD CONSTRAINT ... CHECK (valor_integracao IS NOT NULL) NOT VALID` (não bloqueia), depois `VALIDATE CONSTRAINT` (bloqueia bem menos, só leitura consistente sem lock exclusivo prolongado), e só then promover para `SET NOT NULL` (que em Postgres 12+ reconhece a CHECK validada e pula o re-scan).

6. **`RENAME COLUMN linha_id TO id_linha` sem janela de compatibilidade (alto risco operacional).** O rename em si é instantâneo (metadata-only), mas quebra qualquer consumidor — aplicação, relatório, job — que referencie a coluna pelo nome antigo, no exato momento do deploy, com potencial de vários serviços/instâncias rodando código antigo simultaneamente ao novo schema (deploy rolling). O repositório revisado (`tarifas_repo.ts`) usa `SELECT *`, então não quebra nesse arquivo, mas não há visibilidade sobre outros consumidores (jobs de relatório, BI, outros serviços) — a revisão não pode garantir que não há mais ninguém lendo essa coluna pelo nome antigo. Padrão seguro é expand/contract: manter as duas colunas por um ciclo de deploy (coluna nova + trigger ou view de compatibilidade, ou dual-read na aplicação), e só remover a antiga depois que todo consumidor estiver na nova.

7. **Falta `lock_timeout`/`statement_timeout` na V002.** V001 declara `SET lock_timeout = '5s';` no topo; V002 não declara nada. Numa tabela quente, um `ALTER`/`CREATE INDEX` que fica esperando lock sem timeout pode empilhar outras queries atrás dele (lock queueing), derrubando o serviço mesmo que o DDL em si seja rápido. Todo statement de DDL contra tabela viva precisa de `lock_timeout` curto e re-tentativa, não só a migração antiga.

8. **Inconsistência de tipos e convenções na tabela nova.** `parametros_operador` usa `id serial PRIMARY KEY` (padrão antigo) em vez de `GENERATED ALWAYS AS IDENTITY` como em V001; usa `timestamp` (sem timezone) em `atualizado_em` enquanto `tarifas.vigente_desde` é `timestamptz` — mistura de convenção que tende a gerar bug de fuso horário mais cedo ou mais tarde.

9. **Tabela nova sem RLS.** `parametros_operador` tem `tenant_id uuid NOT NULL` mas não tem `ENABLE ROW LEVEL SECURITY`/policy, ao contrário de `tarifas`. Isso é uma lacuna de isolamento multi-tenant: sem RLS, qualquer código que esqueça o filtro por `tenant_id` vaza dados entre operadoras.

10. **Sem índice de suporte para `parametros_operador`.** Não há índice em `(tenant_id, operador_id)` nem `UNIQUE (tenant_id, operador_id, chave)` — sem a unique, nada impede duplicar a mesma chave de parâmetro para o mesmo operador/tenant; sem o índice composto, buscas por operador em produção vão fazer sequential scan à medida que a tabela cresce.

11. **Índice novo em `tarifas` não casa com o padrão de acesso.** `idx_tarifas_vigencia` é só em `(vigente_desde)`, mas a única consulta revisada (`tarifas_repo.ts`) sempre filtra por tenant (via RLS) e ordena por `vigente_desde DESC`. Um índice em `(tenant_id, vigente_desde DESC)` serve essa consulta de ponta a ponta; o índice de coluna única não ajuda o filtro por tenant e ainda assim toma o custo de bloqueio do item 2.

## Código de acesso a dados (`src/repositorios/tarifas_repo.ts`)

12. **`set_config('app.tenant_id', $1, false)` em conexão de pool, fora de transação (severidade alta — risco de vazamento entre tenants).** O terceiro argumento `false` faz o `set_config` valer para a sessão inteira (a conexão física), não só para a transação corrente. O método pega uma conexão do `Pool`, seta o tenant, roda a query e devolve a conexão (`client.release()`) sem resetar `app.tenant_id`. Se qualquer outro caminho de código pegar essa mesma conexão reciclada do pool e rodar uma query sem primeiro chamar `set_config` de novo (um bug de omissão, um método futuro, um retry), a RLS vai filtrar pelo `tenant_id` do uso anterior — potencial vazamento cross-tenant. O padrão seguro em Postgres com pool é usar `set_config(..., true)` (escopo de transação) dentro de um `BEGIN`/`COMMIT` explícito, ou então dar `RESET app.tenant_id` (ou `DISCARD ALL`) no `finally` antes de `client.release()`.

13. **Paginação por `OFFSET` em tabela de 40M linhas.** `LIMIT $1 OFFSET $2` degrada linearmente com o offset — páginas profundas exigem escanear e descartar todas as linhas anteriores. Para uma tabela dessa escala, prefira paginação por cursor/keyset (`WHERE vigente_desde < $ultimo_valor ORDER BY vigente_desde DESC LIMIT $n`), que usa o índice sem esse custo.

14. **`SELECT *`.** Retorna todas as colunas, incluindo futuras adições, sem controle do payload — funciona hoje mas acopla o contrato da API a qualquer coluna que a tabela ganhar. Sugiro listar colunas explicitamente, principalmente porque a V002 está renomeando `linha_id` para `id_linha` — com `SELECT *`, o nome da chave no objeto de retorno muda silenciosamente para quem consome o resultado.

15. **Ausência de filtro explícito por `tenant_id` na query.** O isolamento depende inteiramente da RLS/GUC de sessão. Como defesa em profundidade — e para não depender só do item 12 estar correto — vale adicionar `WHERE tenant_id = $tenant_id` explícito na query além da RLS.

## O que mudar antes do deploy de quinta

- Confirmar a existência de `operadores` (item 1) antes de qualquer outra coisa — sem isso a migração nem aplica.
- Separar V002 em migrações menores e com controle de lock: uma para `ADD COLUMN` + `CREATE INDEX CONCURRENTLY` (fora de transação), uma para o backfill em lote do `valor_integracao`, uma para `ADD CONSTRAINT ... NOT VALID` + `VALIDATE CONSTRAINT` + `SET NOT NULL`, e a criação de `parametros_operador` separada do resto.
- Adiar o `RENAME COLUMN` para uma migração isolada, só depois de confirmar (grep/observability) que nenhum consumidor além de `tarifas_repo.ts` lê `linha_id` pelo nome, ou aplicar expand/contract.
- Trocar `numeric(5,2)` → `numeric(7,4)` por uma decisão explícita e testada (reescreve a tabela toda; se for só ampliar a escala e não houver necessidade real de 4 casas, considerar não mexer).
- Adicionar `lock_timeout`/`statement_timeout` em todo statement de DDL contra `tarifas`.
- Adicionar RLS + policy em `parametros_operador`, `UNIQUE (tenant_id, operador_id, chave)` e índice de suporte.
- Corrigir `tarifas_repo.ts` para escopar `app.tenant_id` por transação (`set_config(..., true)` dentro de `BEGIN`/`COMMIT`) e considerar paginação por cursor.

## SQL corrigido

A V002 original vira quatro migrações, cada uma com seu próprio raio de bloqueio, mais a correção do código de acesso. `operadores` é tratada como pré-condição a confirmar antes de tudo — se não existir, criar antes ou remover a FK do item 4.

### V002a — coluna nova e índice concorrente (sem transação; `CREATE INDEX CONCURRENTLY` não roda dentro de `BEGIN`)

```sql
-- V002a: aplicado fora de transação (o runner de migração precisa marcar este arquivo como non-transactional).
SET lock_timeout = '5s';
SET statement_timeout = '30s';

ALTER TABLE tarifas ADD COLUMN IF NOT EXISTS valor_integracao numeric(10,2);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tarifas_tenant_vigencia
  ON tarifas (tenant_id, vigente_desde DESC);
```

### V002b — backfill em lote (script de manutenção, não migração transacional única)

```sql
-- V002b: rodar fora do runner de migração, em lotes, com pausa entre lotes para aliviar replicação/WAL.
-- Exemplo de laço (pseudo-SQL, adaptar para o runner/CLI do time):
DO $$
DECLARE
  linhas_afetadas int;
BEGIN
  LOOP
    UPDATE tarifas
    SET valor_integracao = 0
    WHERE id IN (
      SELECT id FROM tarifas
      WHERE valor_integracao IS NULL
      LIMIT 5000
      FOR UPDATE SKIP LOCKED
    );
    GET DIAGNOSTICS linhas_afetadas = ROW_COUNT;
    EXIT WHEN linhas_afetadas = 0;
    COMMIT;
    PERFORM pg_sleep(0.2);
  END LOOP;
END $$;
```

### V002c — `NOT NULL` sem scan bloqueante, e correção de tipo isolada

```sql
-- V002c: CHECK NOT VALID não bloqueia; VALIDATE CONSTRAINT bloqueia bem menos que SET NOT NULL direto.
SET lock_timeout = '5s';

ALTER TABLE tarifas
  ADD CONSTRAINT valor_integracao_not_null CHECK (valor_integracao IS NOT NULL) NOT VALID;

ALTER TABLE tarifas VALIDATE CONSTRAINT valor_integracao_not_null;

ALTER TABLE tarifas ALTER COLUMN valor_integracao SET NOT NULL;
ALTER TABLE tarifas DROP CONSTRAINT valor_integracao_not_null;

-- Mudança de escala de taxa_desconto_percentual reescreve a tabela inteira (40M linhas).
-- Decisão de negócio pendente (ver achado 3) — separar em janela de manutenção própria,
-- não misturar com o resto do deploy de quinta:
-- ALTER TABLE tarifas ALTER COLUMN taxa_desconto_percentual TYPE numeric(7,4);
```

### V002d — tabela nova, com RLS e índice de suporte

```sql
SET lock_timeout = '5s';

-- Pré-condição: confirmar que a tabela "operadores" já existe em produção antes de aplicar.
CREATE TABLE parametros_operador (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  operador_id bigint NOT NULL REFERENCES operadores (id),
  chave text NOT NULL,
  valor_parametro jsonb NOT NULL,
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, operador_id, chave)
);

CREATE INDEX idx_parametros_operador_tenant_operador
  ON parametros_operador (tenant_id, operador_id);

ALTER TABLE parametros_operador ENABLE ROW LEVEL SECURITY;
ALTER TABLE parametros_operador FORCE ROW LEVEL SECURITY;
CREATE POLICY parametros_operador_por_tenant ON parametros_operador
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

### V002e — migração isolada e posterior, só depois de confirmar que nenhum consumidor lê `linha_id` pelo nome

```sql
SET lock_timeout = '5s';
ALTER TABLE tarifas RENAME COLUMN linha_id TO id_linha;
-- Repetir para qualquer índice/constraint que ainda cite linha_id no nome, se aplicável.
```

### Correção de `src/repositorios/tarifas_repo.ts` (diagnóstico, não aplicada — arquivo não foi tocado)

```ts
import { Pool } from 'pg';

export class TarifasRepositorio {
  constructor(private readonly pool: Pool) {}

  async listar(tenantId: string, limite: number, cursorVigenciaDesde?: string) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      // Escopo de TRANSAÇÃO (true), não de sessão: reseta sozinho no COMMIT/ROLLBACK,
      // então a conexão devolvida ao pool nunca carrega o tenant_id de um uso anterior.
      await client.query("SELECT set_config('app.tenant_id', $1, true)", [tenantId]);
      const r = await client.query(
        `SELECT id, tenant_id, id_linha, valor_tarifa_em_centavos, fator_tarifa,
                taxa_desconto_percentual, valor_integracao, vigente_desde
         FROM tarifas
         WHERE tenant_id = $1
           AND ($2::timestamptz IS NULL OR vigente_desde < $2)
         ORDER BY vigente_desde DESC
         LIMIT $3`,
        [tenantId, cursorVigenciaDesde ?? null, limite],
      );
      await client.query('COMMIT');
      return r.rows;
    } catch (erro) {
      await client.query('ROLLBACK');
      throw erro;
    } finally {
      client.release();
    }
  }
}
```

Mudanças no repositório: `set_config` com `true` (escopo de transação, fecha o risco de vazamento entre tenants do item 12); filtro explícito `WHERE tenant_id = $1` como defesa em profundidade além da RLS (item 15); paginação por cursor em vez de `OFFSET` (item 13); colunas explícitas em vez de `SELECT *`, já refletindo `id_linha` pós-rename (itens 6 e 14).
