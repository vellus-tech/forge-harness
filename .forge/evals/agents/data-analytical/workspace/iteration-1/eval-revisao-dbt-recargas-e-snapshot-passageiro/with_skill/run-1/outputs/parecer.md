# Parecer — revisão analítica do PR em `analytics/` (recargas de cartão + cadastro de passageiros)

Especialista: `data-analytical` (consultivo — não escreve na árvore; quem aplica é o `task-coder`).
Escopo: `analytics/models/staging/stg_recargas.sql`, `analytics/models/marts/fct_recargas.sql`, `analytics/models/sources.yml`, `analytics/snapshots/snap_passageiro.yml`, `analytics/dbt_project.yml`.

## Veredito

Não recomendo o merge no estado atual. Há um antipattern do catálogo em cada um dos quatro arquivos de modelo/snapshot, mais uma violação de rule de domínio (money-as-cents) no `stg_recargas.sql`. Nenhum é conflito rule × ADR — todos são desvio direto do padrão do projeto — então não há bloco `CONFLITO`, apenas achados a corrigir.

## Achados (ordenados por severidade)

### 1. [BLOQUEANTE] Valor monetário fora do padrão — `stg_recargas.sql:8`
```sql
cast(valor as numeric(12,2)) as valor_reais,
```
`domain/money-as-cents.md` exige inteiro na menor unidade em todo código de domínio, inclusive warehouse (reforçado no protocolo do `data-analytical`, passo 2). `numeric(12,2)` é ponto fixo decimal e o nome `valor_reais` deixa a unidade errada explícita. Vence a skill por ser rule de domínio, não é uma escolha do dbt.

**Correção:**
```sql
cast(round(valor * 100) as bigint) as valor_centavos,
```
Se a origem operacional (`bilhetagem_app.recargas.valor`) já guardar centavos como inteiro, a conversão é só o cast, sem `* 100` — confirme o tipo real da coluna fonte antes de aplicar; o ponto inegociável é o tipo de saída (`bigint`) e o sufixo `_centavos`.

### 2. [BLOQUEANTE] A-10 — mart lendo `source()` direto — `fct_recargas.sql:3`
```sql
select * from {{ source('app', 'recargas') }}
```
O mart pula inteiramente o `stg_recargas` que já existe no projeto — a limpeza (cast de tipo, rename) fica duplicada e diverge assim que uma mudar sem a outra. `stg_recargas.sql` fica órfão do jeito que está.

**Correção:** ler do `ref()` da staging, não da fonte.

### 3. [BLOQUEANTE] A-12 — `SELECT *` em mart — `fct_recargas.sql:3`
Mesma linha do achado 2. Coluna nova na origem aparece sem aviso no BI; coluna removida quebra o consumidor em silêncio.

**Correção (achados 2+3 juntos, `fct_recargas.sql` completo):**
```sql
{{ config(
    materialized='incremental',
    unique_key='recarga_id',
    incremental_strategy='merge',
    contract={'enforced': true}
) }}

select
    recarga_id,
    tenant_id,
    cartao_id,
    operadora_id,
    valor_centavos,
    criado_em
from {{ ref('stg_recargas') }}
{% if is_incremental() %}
where criado_em > (select max(criado_em) from {{ this }})
{% endif %}
```
Troquei também `materialized='table'` por incremental com `unique_key`, já que o grão é o mesmo da staging (recarga) e reprocessar a tabela inteira a cada run tem custo de bytes varridos sem necessidade — ver achado 9. Se o volume for pequeno e a simplicidade valer mais, manter `table` é aceitável, mas aí a leitura via `ref()` e a lista de colunas continuam obrigatórias.

### 4. [BLOQUEANTE] A-08 — incremental sem `unique_key` nem lookback — `stg_recargas.sql:1,12`
```sql
{{ config(materialized='incremental') }}
...
where criado_em > (select max(criado_em) from {{ this }})
```
Sem `unique_key`, a carga incremental só acrescenta (vira `append`): se o job rodar duas vezes na mesma janela, ou se a fonte reenviar uma linha já processada, `recarga_id` duplica no grão. Sem lookback, uma recarga que chega atrasada (latência de replicação, retry da aplicação) nunca entra porque o filtro usa só o máximo já carregado.

**Correção:**
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
    cast(round(valor * 100) as bigint) as valor_centavos,
    criado_em
from {{ source('app', 'recargas') }}
{% if is_incremental() %}
where criado_em > (select max(criado_em) from {{ this }}) - interval '3 days'
{% endif %}
```
A janela de `3 days` é um ponto de partida — ajuste ao SLA real de atraso da fonte operacional (`bilhetagem_app`); quem tem esse número é o time de dados, não este parecer.

### 5. [BLOQUEANTE] A-14 — `invalidate_hard_deletes` legado — `snap_passageiro.yml:8`
```yaml
invalidate_hard_deletes: true
```
Substituído por `hard_deletes` a partir do dbt 1.9 (confirmado agora no context7, doc oficial dbt-labs/docs.getdbt.com/snapshots — `invalidate_hard_deletes` segue funcionando mas é config legada; `hard_deletes: invalidate` reproduz o mesmo comportamento com o campo atual).

**Correção:**
```yaml
hard_deletes: invalidate
```

### 6. [BLOQUEANTE] A-16 — SCD2 rastreando atributo pessoal — `snap_passageiro.yml:7`
```yaml
check_cols: [nome, email, telefone, categoria_tarifaria]
```
`nome`, `email` e `telefone` são dado pessoal (LGPD) numa dimensão SCD2: cada alteração do titular vira uma linha nova que fica permanentemente no histórico, e a eliminação do titular (A-15) passa a exigir apagar N linhas em N versões, multiplicado ainda pelo time travel da tabela. `categoria_tarifaria` é atributo de negócio e pode continuar rastreado sem problema.

**Correção mínima (remove o atributo pessoal do rastreio):**
```yaml
snapshots:
  - name: snap_passageiro
    relation: source('app', 'passageiros')
    config:
      unique_key: passageiro_id
      strategy: check
      check_cols: [categoria_tarifaria]
      hard_deletes: invalidate
```
`nome`, `email`, `telefone` continuam disponíveis na fonte/num modelo SCD1 mutável e elimináveis por chave (`passageiro_id`), fora do histórico. Se o time de dados/DPO tiver base legal e prazo registrados para reter histórico desses três campos, o rastreio pode ficar — mas isso é decisão de negócio com dono, não default deste modelo, e o registro dessa exceção não é deste especialista (checklist do agente: "SCD2 sem atributo pessoal, A-16" é bloqueado por padrão).

### 7. [ALTO] A-11 — nenhum teste de grão encontrado
Não há `schema.yml` com `unique`/`not_null` em `recarga_id` (staging ou mart) nem em `passageiro_id`. Sem eles, uma duplicata no grão só aparece quando o usuário do dashboard reclamar.

**Correção:** adicionar `analytics/models/marts/_marts.yml` (ou equivalente) com:
```yaml
models:
  - name: fct_recargas
    columns:
      - name: recarga_id
        tests: [unique, not_null]
```
e o mesmo para `stg_recargas.recarga_id` e para `passageiro_id` no snapshot.

### 8. [ALTO] A-09 — mart público sem contrato
`fct_recargas` alimenta BI (é o consumo declarado na tarefa) mas não tem `contract: enforced: true`. Incluí o contrato na correção do achado 3; falta ainda o `data_type` de cada coluna no `schema.yml` para o contrato pegar — sem isso `contract: enforced: true` sozinho não valida tipo.

### 9. [MÉDIO] Grão não declarado — `fct_recargas.sql`
Nenhum arquivo do PR declara processo de negócio e grão de `fct_recargas` (checklist: "grão declarado por fato"). Pelo `select *` atual o grão parece ser "uma linha por recarga", igual à staging — mas isso precisa estar escrito (docstring do modelo ou `description` no `schema.yml`), não inferido de olhar o `SELECT`.

### 10. [INFORMATIVO] Isolamento multi-tenant
`tenant_id` está presente em `stg_recargas` e sobrevive na correção do mart. Não dá para confirmar pelos arquivos do PR se o warehouse compartilhado tem RLS por `tenant_id` nessas tabelas (`data-governance.md` exige RLS para store multi-tenant compartilhado) — fica registrado como item de revisão para quem tem visibilidade do warehouse físico, fora do escopo destes quatro arquivos.

## Verificação executada (transparência de auditabilidade)

- `bash .forge/scripts/check-data-governance.sh --path analytics` → `FAIL data-governance/universo-vazio` (0 arquivos examinados). Não é aprovação nem achado: o verificador só lê `.go .kt .ts .rego .py .md`; um projeto dbt (`.sql`/`.yml`) fica fora do universo dele por desenho. O inventário de dado pessoal (achado 6) foi feito por leitura manual do `snap_passageiro.yml`, cruzando os nomes de coluna com o padrão do catálogo (`cpf|email|telefone|nome|endereco|data_nasc`), como o protocolo pede quando o scanner não cobre o caso.
- `bash .forge/skills/data-analytical-practices/scripts/scan.sh --root analytics` → **não executável neste ambiente**: a árvore de trabalho deste eval projeta `.forge/rules`, `.forge/scripts`, `.forge/schemas` etc., mas não `.forge/skills/`, e o hook `data-agent-bash-guard.sh` só aceita o caminho relativo literal `.forge/skills/data-analytical-practices/scripts/scan.sh` (nega qualquer variação, inclusive apontar para o `scan.sh` do template fora da árvore). Os achados A-08, A-10, A-12 e A-14 acima — que o `scan.sh` detectaria estaticamente — foram então por julgamento manual via `Read`, citando eu mesmo `arquivo:linha`, sem a confirmação independente do scanner. O veredito esperado é o mesmo (o padrão de texto é inequívoco nos quatro casos), mas a lacuna de auditabilidade do ambiente fica registrada, não escondida.
- `mcp__context7__query-docs` (dbt-labs/docs.getdbt.com) confirmou a sintaxe atual de `hard_deletes` (achado 5) e de `unique_key`/`incremental_strategy: merge`/lookback (achados 3 e 4) antes de eu afirmar esses defaults.

## Antipatterns do catálogo citados

A-08, A-09, A-10, A-11, A-12, A-14, A-16 — `.forge/skills/data-analytical-practices/references/antipatterns.md` (lido do template, já que a instância local do eval não a projeta).
