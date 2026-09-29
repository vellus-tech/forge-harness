# Parecer de revisão analítica — projeto dbt `analytics/` (recargas e snapshot de passageiro)

Escopo revisado: `analytics/dbt_project.yml`, `analytics/models/sources.yml`, `analytics/models/staging/stg_recargas.sql`, `analytics/models/marts/fct_recargas.sql`, `analytics/snapshots/snap_passageiro.yml`. Nenhum arquivo foi alterado — a aplicação das correções é do task-coder.

## 1. Bloqueante — `fct_recargas` ignora a camada de staging e lê direto da fonte

`analytics/models/marts/fct_recargas.sql` é:

```sql
{{ config(materialized='table') }}

select * from {{ source('app', 'recargas') }}
```

O mart lê `source('app', 'recargas')` em vez de `ref('stg_recargas')`. Isso quebra a arquitetura staging → marts do próprio projeto (a staging existe, faz o cast de `valor` para `numeric(12,2)` e renomeia `id` para `recarga_id`, mas nada disso chega ao mart) e tem três efeitos concretos: (a) `fct_recargas` expõe colunas cruas da fonte (`id`, `valor` sem cast) em vez do contrato de `stg_recargas`; (b) qualquer transformação futura em `stg_recargas` (dedup, cast, enriquecimento) não se propaga para o mart, que é presumivelmente o que times de BI consultam; (c) `fct_recargas` sendo `materialized='table'` recompila full-refresh a cada `dbt run` fazendo full scan da tabela fonte, em vez de ler a staging incremental já materializada — desperdício de custo/tempo que cresce com o volume de recargas.

**Correção sugerida:**

```sql
{{ config(materialized='table') }}

select
    recarga_id,
    tenant_id,
    cartao_id,
    operadora_id,
    valor_reais,
    criado_em
from {{ ref('stg_recargas') }}
```

## 2. Bloqueante — watermark incremental de `stg_recargas` é global, não por tenant, e perde registros atrasados de outros tenants

`analytics/models/staging/stg_recargas.sql`:

```sql
{% if is_incremental() %}
where criado_em > (select max(criado_em) from {{ this }})
{% endif %}
```

O modelo é multi-tenant (`tenant_id` é coluna do grão), mas o corte incremental usa um único `max(criado_em)` global, computado sobre todos os tenants misturados. Se o tenant A grava recargas com menor latência que o tenant B, o cursor global avança com base no tenant A; quando uma recarga do tenant B chega depois, com `criado_em` anterior ao máximo global (mas nunca antes vista), a condição `criado_em > max_global` a exclui permanentemente — a linha nunca mais entra no incremental, silenciosamente. Isso é uma perda de dado financeiro (recarga que não aparece em `fct_recargas`), não apenas atraso.

Um segundo problema correlato: o modelo não define `unique_key`, então a estratégia incremental padrão é `append`. Combinado com o corte por igualdade estrita (`>`), qualquer reprocessamento ou corrida de dois runs sobrepostos pode duplicar linhas — sem `unique_key`/`merge` não há proteção de idempotência.

**Correção sugerida** (buffer de segurança + merge idempotente; alternativa por-tenant é mais precisa mas mais cara):

```sql
{{ config(
    materialized='incremental',
    unique_key='recarga_id',
    incremental_strategy='merge'
) }}

select
    id as recarga_id,
    tenant_id,
    cartao_id,
    operadora_id,
    cast(valor as numeric(12,2)) as valor_reais,
    criado_em
from {{ source('app', 'recargas') }}
{% if is_incremental() %}
-- buffer de 30 min sobre o watermark global para absorver atraso entre tenants;
-- o merge por recarga_id garante que o reprocessamento não duplique linhas
where criado_em > (
    select coalesce(dateadd('minute', -30, max(criado_em)), '1900-01-01'::timestamp)
    from {{ this }}
)
{% endif %}
```

Se a defasagem entre tenants puder superar o buffer, o corte correto é por tenant (`where criado_em > (select max(criado_em) from {{ this }} t where t.tenant_id = source_tbl.tenant_id)`), mas isso exige um alias na fonte e é mais custoso — decisão de trade-off a confirmar com o time de dados conforme o SLA de atraso aceitável.

## 3. Relevante — ausência total de testes (`schema.yml`)

Não há `schema.yml`/`.yml` de testes para nenhum modelo. Para uma tabela multi-tenant de recargas financeiras, no mínimo faltam: `not_null` + `unique` em `recarga_id`; `not_null` em `tenant_id` (isolamento multi-tenant é garantia de segurança, não só de qualidade); `not_null` em `valor_reais` e um teste de aceitação (`>= 0`, ou o range de negócio); `relationships` de `fct_recargas.cartao_id`/`operadora_id` para as respectivas dimensões, se existirem. O mesmo vale para `snap_passageiro` (`unique_key` = `passageiro_id` já é a chave da snapshot, mas testar `not_null` em `passageiro_id` na fonte evita snapshot quebrada).

## 4. Ponto de atenção — dinheiro representado em reais decimais, não em centavos inteiros

`cast(valor as numeric(12,2)) as valor_reais` guarda o valor monetário como decimal de duas casas. `numeric` não é ponto flutuante, então não há erro de arredondamento binário imediato, mas concatenar `numeric(12,2)` por múltiplas camadas de `sum`/`join`/conversão de moeda ao longo do pipeline analítico tende a acumular arredondamento e a exigir cuidado extra em toda agregação. Para dados de pagamento, o padrão mais seguro é manter o valor como inteiro em centavos (`valor_centavos`) ao longo de todo o pipeline analítico e converter para reais só na camada de apresentação/BI. Não é bloqueante, mas vale alinhar com o padrão do restante da plataforma antes do merge.

## 5. Ponto de atenção — fontes sem monitoramento de freshness

`analytics/models/sources.yml` declara `recargas` e `passageiros` sem `loaded_at_field`/`freshness`. Como `fct_recargas` depende de carga incremental contínua, um atraso silencioso na ingestão da fonte não é detectado por `dbt source freshness`. Sugestão: adicionar `loaded_at_field: criado_em` e um `freshness` (`warn_after`/`error_after`) em `recargas`.

## 6. Menor — `snap_passageiro` não inclui `tenant_id` em `check_cols`

Se `tenant_id` de um passageiro puder mudar (ex.: correção de cadastro entre tenants), a mudança não gera nova versão na snapshot porque `check_cols` só lista `[nome, email, telefone, categoria_tarifaria]`. Se `tenant_id` for imutável por design, não é um problema — vale confirmar a premissa com o time de dados; se não for imutável, incluir `tenant_id` em `check_cols`.

## Resumo priorizado

| # | Severidade | Item | Arquivo |
|---|---|---|---|
| 1 | Bloqueante | Mart lê da fonte, não da staging | `models/marts/fct_recargas.sql` |
| 2 | Bloqueante | Watermark incremental global perde recargas atrasadas de outros tenants + sem `unique_key`/merge | `models/staging/stg_recargas.sql` |
| 3 | Relevante | Sem testes de schema (unicidade, not-null, isolamento de tenant) | todo o projeto |
| 4 | Atenção | Valor monetário em reais decimais, não centavos inteiros | `models/staging/stg_recargas.sql` |
| 5 | Atenção | Sem freshness check nas sources | `models/sources.yml` |
| 6 | Menor | `check_cols` da snapshot pode não cobrir mudança de `tenant_id` | `snapshots/snap_passageiro.yml` |

Itens 1 e 2 devem bloquear o merge — são perda/inconsistência de dado financeiro, não só estilo. Itens 3–6 podem virar follow-up se o prazo do PR for curto, desde que registrados.
