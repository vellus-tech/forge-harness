# ADR (rascunho) — Onde e como modelar o ledger de créditos e a ingestão de telemetria

> Status: Rascunho para revisão. Numeração real cabe a `/forge:adr` — este documento é o conteúdo proposto, não foi registrado.

## Contexto

Dois módulos novos, multi-tenant por operadora (`tenant_id`):

1. **Ledger de créditos do cartão transporte** — lançamento de crédito por recarga, débito por embarque, estorno e cálculo de saldo.
2. **Ingestão de telemetria dos validadores** — leituras a cada 5 segundos por equipamento, consultadas por equipamento nas últimas 24 horas.

Proposta original: tudo em PostgreSQL com TimescaleDB, para simplificar.

## Decisão

**Concordo em parte.** PostgreSQL é a escolha certa para o ledger — é dado transacional de negócio com integridade referencial forte e exige auditabilidade forte (`.forge/rules/domain/audit-immutability.md`, `.forge/rules/data/data-config-sql.md`). TimescaleDB (extensão sobre Postgres) também é uma escolha defensável para a telemetria, dado o padrão de escrita em alta frequência e leitura por janela de tempo.

**Discordo de "tudo no mesmo lugar".** Os dois módulos têm perfis de carga incompatíveis o suficiente para justificar isolamento físico, não apenas lógico:

| Dimensão | Ledger | Telemetria |
|---|---|---|
| Padrão de escrita | Baixo volume, alta integridade, uma linha por evento financeiro | Altíssimo volume, append contínuo (1 leitura/5s por equipamento) |
| Vacuum/autovacuum | Tabela pequena, tuning padrão | Tabela gigante, tuning agressivo, compressão obrigatória |
| Retenção | Indefinida/regulatória (auditoria) | Rolling window — provavelmente dias a poucos meses, não indefinida |
| Imutabilidade | Trigger BEFORE UPDATE/DELETE + REVOKE (`audit-immutability.md`) — bloqueia qualquer alteração | **Não pode** ter esse trigger — colide com as políticas de compressão/retenção do Timescale, que fazem DELETE/rewrite de chunk internamente |
| Blast radius de um pico de ingestão | — | Não pode ameaçar a disponibilidade/latência do ledger financeiro |

**Recomendação:** mesmo motor (Postgres), **bancos lógicos separados** (ou no mínimo schemas separados com roles/pools de conexão dedicados) — `ledger_db` (Postgres puro) e `telemetria_db` (Postgres + extensão TimescaleDB). Isso preserva a simplificação operacional que o usuário buscava (uma única tecnologia de banco para o time operar) sem misturar dois perfis de carga e dois regimes de retenção/imutabilidade na mesma tabela/instância.

Isso também segue a matriz de `.forge/rules/data/data-governance.md`: "relacional, integridade referencial forte, config/paramétrico → PostgreSQL" cobre o ledger; a telemetria é alto volume com padrão de acesso por janela de tempo, o que não está listado na matriz genérica do projeto (relacional vs. NoSQL vs. cache) — é um caso de time-series que a matriz atual não cobre explicitamente. Ver "Questão em aberto" abaixo.

## Modelagem — Ledger

Append-only, sem tabela de saldo mutável como fonte de verdade. Cada lançamento é uma linha imutável; saldo é derivado do último `balance_after_cents` (ou de cache transacional, nunca autoritativo).

- `entry_type`: `credit_recarga`, `debit_embarque`, `estorno`, `ajuste`.
- Estorno **não apaga** o débito original — insere uma nova entrada `estorno` com `related_entry_id` apontando para o débito estornado (padrão "VOID entry", conforme anti-pattern documentado em `audit-immutability.md`: nunca `UPDATE`/soft-delete em ledger).
- `idempotency_key` único por tenant — embarque e recarga são eventos que podem ser reenviados (rede instável em validador/terminal); sem chave de idempotência, reprocessamento duplica lançamento.
- `amount_cents BIGINT`, nunca `DECIMAL`/`NUMERIC` (`.forge/rules/domain/money-as-cents.md`); arredondamento (se houver split/taxa) segue NBR 5891 (`.forge/rules/domain/nbr-5891-rounding.md`).
- Isolamento multi-tenant: `tenant_id` + EF Global Query Filter (camada de aplicação) + RLS (camada de banco) — defesa em profundidade obrigatória por `.forge/rules/data/data-config-sql.md`.
- Trigger de imutabilidade (`BEFORE UPDATE OR DELETE OR TRUNCATE`) + `REVOKE UPDATE, DELETE, TRUNCATE ON ledger_entries FROM app` — mesmo padrão de `ledger_entries` documentado em `audit-immutability.md` (a tabela até já tem esse nome-exemplo na rule do projeto).

Ver `schema-ledger.sql` para o DDL completo.

## Modelagem — Telemetria

Hypertable Timescale particionada por tempo (`reading_at`), com `tenant_id` e `equipment_id` como colunas de segmentação de compressão e como prefixo do índice — o padrão de consulta declarado é "por equipamento, últimas 24h".

- Chunk interval inicial sugerido: **1 hora** — mas isso depende do volume real (ver questão em aberto sobre quantidade de validadores/tenant). Chunk pequeno demais gera overhead de metadados; chunk grande demais atrasa a compressão.
- Política de compressão: comprimir chunks mais antigos que a janela quente de consulta (24h) — ex. `add_compression_policy(..., INTERVAL '2 hours')` como ponto de partida conservador, a ajustar.
- Política de retenção: **não posso definir sem saber a exigência regulatória/contratual de retenção de telemetria de validador** — diferente do ledger, não tenho uma rule do projeto cobrindo isso. Ver questão em aberto.
- RLS: `.forge/rules/data/data-config-sql.md` torna RLS obrigatório para "tabelas multi-tenant de domínio" em Postgres, sem exceção explícita para hypertables. Telemetria é dado de domínio multi-tenant, então a regra se aplica — **mas** RLS sobre hypertable comprimida tem interações pouco documentadas (policy é avaliada por chunk; comportamento com chunks comprimidos precisa ser validado em spike antes de assumir que funciona igual a uma tabela normal). Incluí a policy no DDL, mas isso é uma suposição a verificar, não um fato.
- Sem trigger de imutabilidade — telemetria bruta de validador não é ledger/auditoria regulatória no mesmo sentido de `audit-immutability.md`; aplicar o mesmo mecanismo bloquearia a própria compressão/retenção do Timescale. Se houver exigência regulatória de imutabilidade também para telemetria, isso muda a decisão e precisa virar uma rule própria — não assumi isso porque não foi dito.

Ver `schema-telemetria.sql` para o DDL completo.

## Questões em aberto (não posso decidir sozinho com o que foi dito)

1. **Volumetria real**: quantos validadores por operadora, e quantas operadoras? Isso dimensiona chunk interval, política de compressão/retenção e decide se uma única instância Timescale aguenta todos os tenants ou se é preciso sharding por tenant maior.
2. **Retenção de telemetria**: por quanto tempo a leitura bruta precisa ficar acessível além das 24h de consulta operacional? Auditoria/compliance de mobilidade pode exigir retenção maior — isso é uma decisão de negócio/regulatória, não técnica.
3. **RLS em hypertable comprimida**: validar em spike antes de confiar nisso em produção; não é uma garantia documentada do Timescale que eu possa afirmar sem testar.
4. **Payload da leitura**: usei `JSONB` genérico em `telemetry_readings.metric_payload` por não conhecer o schema exato do dado do validador. Se os campos forem estáveis (ex.: sempre os mesmos 5 contadores), colunas tipadas são melhores para compressão e para índices por métrica — troque o `JSONB` por colunas reais assim que o formato estiver definido (ver `.forge/rules/data/schema-evolution.md` para o fluxo expand/migrate/contract dessa troca).
5. Isso precisa virar um ADR de verdade (`/forge:adr`) — as rules do projeto já apontam "ADR a criar — sem equivalente aprovado no catálogo atual" tanto para `money-as-cents.md` quanto para a escolha de Postgres como banco relacional; este rascunho cobre ambos os módulos e pode ser a base desse ADR.
