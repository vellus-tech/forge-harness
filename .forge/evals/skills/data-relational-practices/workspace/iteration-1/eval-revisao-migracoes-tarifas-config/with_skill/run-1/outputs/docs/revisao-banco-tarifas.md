# Revisão de banco — serviço tarifas-config (pré-deploy de quinta)

Escopo: `services/tarifas-config/migrations/V002__integracao_e_parametros.sql` (sobe com o serviço no ar, tabela `tarifas` com ~40 milhões de linhas) e `services/tarifas-config/src/repositorios/tarifas_repo.ts`. Revisão feita com a skill `data-relational-practices`, protocolo fixo: escopo → rules do projeto → detecção estática (`scripts/scan.sh` + `check-data-governance.sh`) → julgamento manual de cada achado → relatório.

## Veredito

**Não subir a V002 como está.** Há um bloqueio de governança (tabela multi-tenant nova sem RLS) e três operações da migração travam a tabela `tarifas` com o serviço no ar (índice sem `CONCURRENTLY`, troca de tipo com reescrita, `RENAME` in-place). A seção "SQL corrigido" abaixo separa o que é seguro para quinta do que precisa virar uma sequência expand → migrate → contract em deploys futuros.

## Achados, um por regra do catálogo (`references/antipatterns.md`)

| Regra | Severidade | Local | Achado |
|---|---|---|---|
| R-03 — migração bloqueante | alto | V002:3 | `CREATE INDEX idx_tarifas_vigencia` sem `CONCURRENTLY` toma lock que bloqueia escrita em `tarifas` (~40M linhas) durante a criação. |
| R-03 — migração bloqueante | alto | V002:4 | `RENAME COLUMN linha_id TO id_linha` in-place quebra a versão do serviço que ainda está lendo/escrevendo `linha_id` durante o rollout (deploy com serviço no ar = duas versões coexistindo). |
| R-03 — migração bloqueante | alto | V002:5 | `ALTER COLUMN taxa_desconto_percentual TYPE numeric(7,4)` muda escala do `NUMERIC` — no PostgreSQL isso reescreve a tabela inteira sob `ACCESS EXCLUSIVE LOCK` (ao contrário de aumento de tamanho de `varchar`, que é metadata-only); em 40M linhas é indisponibilidade, não lentidão. |
| R-03 — migração bloqueante | alto | V002:2,6,7 | `ADD COLUMN` + `UPDATE ... WHERE valor_integracao IS NULL` (varre as 40M linhas numa transação só) + `SET NOT NULL` sem `VALIDATE CONSTRAINT` prévio: o `UPDATE` em massa gera lock de linha, bloat e WAL enormes, e o `SET NOT NULL` faz um segundo full scan sob lock forte. Evitável: ver SQL corrigido. |
| R-21 — migração sem `lock_timeout` | aviso (trato como bloqueante aqui) | V002 (arquivo inteiro) | A V001 abre com `SET lock_timeout = '5s'`; a V002 não tem nenhum `SET lock_timeout`/`statement_timeout`. Numa tabela quente, um `ALTER TABLE` que espera lock indefinidamente enfileira todo o tráfego atrás dele — é a diferença entre a migração falhar rápido (com `lock_timeout`) e a aplicação cair (sem ele). |
| R-20 — tabela multi-tenant sem RLS | **bloqueante (`data-governance.md`)** | V002:9-16 | `parametros_operador` tem `tenant_id uuid NOT NULL` e nenhum `ENABLE ROW LEVEL SECURITY`. `rules/data/data-governance.md` e `rules/data/data-config-sql.md` tornam RLS obrigatório em toda tabela multi-tenant de domínio no PostgreSQL; ausência sem exceção formal (ADR ou registro de exceção) é "conflito bloqueante" — a rule é explícita nesse termo. `tarifas` (V001) já segue o padrão certo (`ENABLE` + `FORCE ROW LEVEL SECURITY` + `CREATE POLICY`); `parametros_operador` não repete o padrão. |
| R-19 — coluna monetária fora do padrão de centavos | aviso, mas é a rule da casa | V002:2 | `valor_integracao numeric(10,2)`. `rules/domain/money-as-cents.md` §4 exige `BIGINT NOT NULL` na menor unidade, nunca `NUMERIC`/`DECIMAL`; a skill estende essa regra a qualquer `*.sql`, em qualquer stack (decisão H-03(a) do dono, sem mudar o `applies_to` da rule). `tarifas.valor_tarifa_em_centavos` (V001) já segue o padrão certo — a V002 diverge dele na mesma tabela. Não é falso-positivo: é um valor monetário (nome "valor_integracao"), diferente de `fator_tarifa`/`taxa_desconto_percentual`, que são fator e percentual, não dinheiro, e ficam de fora com razão. |
| R-04 — tipos problemáticos | aviso | V002:10,15 | `id serial PRIMARY KEY` (preferir `bigint GENERATED ALWAYS AS IDENTITY`, como a própria `tarifas` já faz); `atualizado_em timestamp` sem fuso (preferir `timestamptz`, como `vigente_desde` em `tarifas`). |
| naming (`database-naming.md`) | — | V002:4 | O rename vai na direção errada mesmo ignorando o custo operacional: a convenção do projeto para FK é `{tabela_referenciada_singular}_id` (sufixo), isto é, `linha_id` já está correto; `id_linha` é quem viola a convenção. Recomendação: não fazer esse rename. |
| R-01 — FK sem índice (fora do scanner, revisão manual) | candidato | V002:12 | `operador_id bigint NOT NULL REFERENCES operadores (id)` sem índice próprio. Como a tabela é nova (sem tráfego ainda), não é um risco de deploy, mas falta o índice antes de `parametros_operador` crescer — mesmo raciocínio do R-01 (o Postgres indexa a PK referenciada, não a FK). |
| R-12 — estado de sessão com pool | **alto (achado de segurança, não só de estilo)** | `tarifas_repo.ts:9` | `client.query("SELECT set_config('app.tenant_id', $1, false)", [tenantId])` com `false` grava o GUC no nível de **sessão**, não de transação; o método `listar()` devolve a conexão ao pool (`client.release()`) sem resetar esse estado. Como o `pg.Pool` reutiliza conexões físicas entre requisições, a próxima chamada a `listar()` com outro `tenantId` pode herdar a conexão que ainda carrega o `app.tenant_id` do tenant anterior até chamar `set_config` de novo — e se qualquer outro código do processo pegar essa conexão do pool antes de setar o tenant (erro, código futuro, outra rota), a RLS filtra pelo tenant errado. Isso é exatamente o cenário que `data-config-sql.md` e `data-governance.md` querem evitar com RLS + defesa em profundidade: aqui a camada do banco fica exposta a vazamento cross-tenant por um detalhe de pool, não de RLS ausente. Não depende de estar atrás de PgBouncer em modo transaction — vale para qualquer pool que reutiliza conexão, node-postgres incluído. |
| R-06 — OFFSET profundo | aviso | `tarifas_repo.ts:11` | Paginação por `OFFSET $2` sobre `ORDER BY vigente_desde DESC`: página funda fica lenta e pode repetir/pular linha com escrita concorrente. Não é bloqueante para quinta (a V002 não muda esse método), mas é dívida a registrar. |
| R-14 — `SELECT *` em código | aviso | `tarifas_repo.ts:11` | `SELECT *` acopla o código a todas as colunas de `tarifas`; a V002 adiciona `valor_integracao` e (se o rename for descartado, como recomendado) não quebra o mapeamento — mas cada coluna nova volta a trafegar sem necessidade. |
| Gate de design (`schema-evolution.md`) | processo | V002 (arquivo) | A rule exige que toda task com migration declare engine, impacto leitura/escrita, compatibilidade, estratégia de rollback e dados históricos afetados. Não há esse registro para a V002 — sinalizando aqui porque é pré-condição formal para subir a migração, não só qualidade do SQL. |

## SQL corrigido

### Seguro para o deploy de quinta (expand-only, sem reescrita de tabela)

```sql
-- V002: expand-only. Sem RENAME, sem ALTER TYPE, sem UPDATE em massa — nada que reescreva
-- ou bloqueie tarifas (~40M linhas) sob o serviço no ar.
SET lock_timeout = '5s';
SET statement_timeout = '30s';

-- Coluna nova com DEFAULT constante: metadata-only desde o PostgreSQL 11 (não reescreve a
-- tabela nem varre as 40M linhas — troca a UPDATE em massa da V002 original).
ALTER TABLE tarifas
  ADD COLUMN valor_integracao_em_centavos bigint NOT NULL DEFAULT 0;

COMMIT;

-- CREATE INDEX CONCURRENTLY não roda dentro de transação: precisa ser o próprio statement de
-- uma migração isolada (ou o runner de migração precisa suportar non-transactional step).
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tarifas_vigencia ON tarifas (vigente_desde);
```

```sql
-- Nova tabela: RLS obrigatório desde o nascimento (mesmo padrão de V001/tarifas), bigint
-- identity em vez de serial, timestamptz em vez de timestamp, índice na FK nova.
SET lock_timeout = '5s';

CREATE TABLE parametros_operador (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  operador_id bigint NOT NULL REFERENCES operadores (id),
  chave text NOT NULL,
  valor_parametro jsonb NOT NULL,
  atualizado_em timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_parametros_operador_tenant_id ON parametros_operador (tenant_id);
CREATE INDEX idx_parametros_operador_operador_id ON parametros_operador (operador_id);

ALTER TABLE parametros_operador ENABLE ROW LEVEL SECURITY;
ALTER TABLE parametros_operador FORCE ROW LEVEL SECURITY;
CREATE POLICY parametros_operador_por_tenant ON parametros_operador
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

### Fora do escopo de quinta — expand → migrate → contract em deploys futuros

O rename e a troca de tipo da V002 original precisam de mais de um deploy cada; não cabem numa migração só sem indisponibilidade. Não incluí como SQL pronto porque a fase de "migrate" (backfill em lotes + dual-write) depende de quem consome `linha_id` e `taxa_desconto_percentual` hoje, informação que este escopo (um serviço) não tem — é o item a levantar com quem mantém os consumidores antes de agendar.

- **Rename `linha_id`:** recomendo não fazer. `linha_id` já segue `database-naming.md` (`{tabela_referenciada_singular}_id`); `id_linha` seria a violação, não a correção. Se o motivo do rename for outro (não documentado na V002), precisa virar requirement explícito antes de qualquer SQL.
- **Troca de tipo `taxa_desconto_percentual numeric(5,2) → numeric(7,4)`:** expand (coluna nova `taxa_desconto_percentual_v2 numeric(7,4)`) → migrate (backfill em lotes idempotentes + dual-write na aplicação) → contract (drop da coluna antiga, rename da nova) em migrações e deploys separados, só depois que todo leitor/escritor estiver na versão nova — conforme `rules/data/schema-evolution.md`.

## Correção no acesso a dados (`tarifas_repo.ts`)

```typescript
import { Pool } from 'pg';

export class TarifasRepositorio {
  constructor(private readonly pool: Pool) {}

  async listar(tenantId: string, limite: number, offset: number) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      // set_config(..., true) grava o GUC só até o COMMIT: a conexão devolvida ao pool sai
      // limpa, sem tenant_id de sessão vazando para a próxima requisição que a reutilizar.
      await client.query("SELECT set_config('app.tenant_id', $1, true)", [tenantId]);
      const r = await client.query(
        `SELECT id, tenant_id, linha_id, valor_tarifa_em_centavos, fator_tarifa,
                taxa_desconto_percentual, vigente_desde
         FROM tarifas
         ORDER BY vigente_desde DESC, id DESC
         LIMIT $1 OFFSET $2`,
        [limite, offset],
      );
      await client.query('COMMIT');
      return r.rows;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }
}
```

Mudanças: `set_config(..., true)` em vez de `false` (fecha o vazamento de tenant entre requisições descrito no achado R-12 acima) dentro de uma transação explícita; colunas nomeadas em vez de `SELECT *` (R-14). Mantive a paginação por `OFFSET` porque a V002 não mexe nela e trocar para keyset muda a assinatura do método (contrato com quem chama) — registro como débito (R-06), não como bloqueio de quinta.

## Resumo do que muda antes do deploy

1. Bloquear a V002 como está — não subir com RENAME, ALTER TYPE nem o UPDATE em massa.
2. Trocar a V002 pela versão expand-only acima (`valor_integracao_em_centavos` com `DEFAULT` constante + `CREATE INDEX CONCURRENTLY` fora de transação).
3. Adicionar RLS (`ENABLE` + `FORCE` + `CREATE POLICY`) e os dois índices em `parametros_operador` antes de criar a tabela — isso é bloqueio de governança, não sugestão.
4. Corrigir `tarifas_repo.ts`: `set_config(..., true)` dentro de transação, e projeção de colunas em vez de `SELECT *`.
5. Registrar rename e troca de tipo como trabalho futuro com plano expand → migrate → contract, coordenado com os consumidores de `linha_id`/`taxa_desconto_percentual` fora deste serviço.
6. Preencher o gate de `schema-evolution.md` (engine, impacto, compatibilidade, rollback, dados históricos, evidência de teste) na task antes de agendar a migração revisada.
