# Revisão analítica — projeto dbt de bilhetagem (`analytics/`)

Revisão pré-PR de modelagem, incremental, marts, snapshots e particionamento, contra o catálogo de antipatterns `data-analytical-practices` (A-01 a A-16). Diagnóstico apenas — nenhum arquivo em `analytics/` foi alterado.

## Sumário executivo

O projeto tem 5 achados confirmados pela varredura estática (2 de severidade alta, 3 de aviso) e mais 5 achados de revisão manual que o scanner não cobre, incluindo um risco de duplicação de receita no incremental de viagens e uma inconsistência de tipo monetário no mart final (`fct_viagens` converte centavos para `numeric`, quebrando a convenção de inteiro-em-centavos que as duas DDLs do lakehouse seguem corretamente). Nenhum antipattern de eliminação de titular (A-15/A-16) foi encontrado — as colunas pessoais buscadas (nome, cpf, email, telefone, endereço, data de nascimento) não aparecem no projeto; `id_cartao` é um identificador pseudonímico e está marcado como ponto de atenção, não como achado do catálogo.

## Escopo

- `analytics/models/staging/` — `stg_viagens.sql`, `stg_linhas.sql`, `_sources.yml` (source `bilhetagem`: `viagens`, `linhas`, `validacoes`).
- `analytics/models/intermediate/` — `int_viagens_diarias.sql`, `int_validacoes.sql`.
- `analytics/models/marts/` — `dim_linha.sql`, `fct_viagens.sql`.
- `analytics/snapshots/` — `snap_linhas.yml` (SCD2 de `stg_linhas`).
- `analytics/ddl/` — `silver_embarques.sql` (Iceberg), `gold_receita_linha.sql` (Spark/parquet, Hive metastore).

Grão declarado por fato/tabela:

| Modelo | Grão declarado | Observação |
|---|---|---|
| `fct_viagens` | uma linha por viagem (comentário explícito no arquivo) | grão coerente com as colunas selecionadas |
| `int_viagens_diarias` | não declarado; nome sugere grão diário | conteúdo é por viagem individual, sem `GROUP BY` — ver achado R-1 |
| `dim_linha` | uma linha por linha (`cod_linha`) | chave natural, sem substituta |
| `snap_linhas` | uma versão por `cod_linha` por vigência (SCD2, estratégia `check`) | não referenciado por nenhum mart — ver achado R-2 |
| `gold_receita_linha` (DDL) | uma linha por `cod_linha` por dia | agregação diária real (`GROUP BY cod_linha`) |

## Detecção — `scripts/scan.sh --root analytics`

| Regra | Resultado | Ocorrências |
|---|---|---|
| A-06 — partição Hive à mão | **FOUND** [aviso] | 2 — `ddl/gold_receita_linha.sql:9,11` |
| A-08 — incremental sem `unique_key`/microbatch | **FOUND** [aviso] | 1 — `models/intermediate/int_viagens_diarias.sql:1` |
| A-10 — mart lendo `source()` direto | **FOUND** [alto] | 1 — `models/marts/fct_viagens.sql:10` |
| A-12 — `SELECT *` em mart | **FOUND** [aviso] | 1 — `models/marts/dim_linha.sql:3` |
| A-14 — snapshot com `invalidate_hard_deletes` legado | **FOUND** [alto] | 1 — `snapshots/snap_linhas.yml:9` |

`check-data-governance.sh --path analytics` voltou `universo-vazio` (0 arquivos no escopo dele) — não verificado, não é achado.

`silver_embarques.sql:9` (`PARTITIONED BY (days(ts_embarque))`) **não** é achado — é particionamento oculto do Iceberg (transformação `days()`), o padrão recomendado pelo catálogo (A-06).

## Achados confirmados pela varredura (julgamento)

### A-10 [alto] — `fct_viagens` lê `source()` direto, pula staging
`analytics/models/marts/fct_viagens.sql:10` — `from {{ source('bilhetagem', 'viagens') }} v`. O mart final pula `stg_viagens`, onde a limpeza e a renomeação já estão centralizadas; qualquer ajuste futuro de schema da fonte precisa ser replicado em dois lugares (`stg_viagens` e `fct_viagens`) e diverge com o tempo. Correção: trocar por `{{ ref('stg_viagens') }}` — ou, melhor, por `{{ ref('int_viagens_diarias') }}` se o grão diário for realmente o que o mart quer expor (ver R-1).

### A-14 [alto] — snapshot com sintaxe legada de hard delete
`analytics/snapshots/snap_linhas.yml:9` — `invalidate_hard_deletes: true`. Desde o dbt 1.9 essa chave foi substituída por `hard_deletes: invalidate | new_record | ignore`. Não é apenas estilo: em versões recentes do dbt as duas chaves não podem coexistir sem aviso de depreciação, e `hard_deletes: new_record` passa a existir como opção (grava uma linha `dbt_is_deleted` em vez de fechar a vigência) — vale decidir explicitamente qual comportamento se quer para uma linha excluída na origem. Correção: `hard_deletes: invalidate` (equivalente ao comportamento atual) e remover a chave antiga.

### A-08 [aviso, mas com impacto de negócio direto] — `int_viagens_diarias` incremental sem `unique_key`
`analytics/models/intermediate/int_viagens_diarias.sql:1-10`. O filtro incremental é `where ts_embarque > (select max(ts_embarque) from this)`, sem `unique_key`. Dois problemas reais, não hipotéticos, para este domínio: (1) sem `unique_key`, um reprocessamento (`--full-refresh` parcial, replay de uma partição, correção de um dia) duplica linhas no grão de viagem — e esse modelo alimenta receita a jusante; (2) o filtro por `max(ts_embarque)` não tem lookback — um evento de embarque que chega atrasado (device offline, sincronização em lote) com `ts_embarque` anterior ao máximo já processado nunca entra no modelo, porque a próxima rodada só busca `ts_embarque > max` do estado atual. Note que `int_validacoes.sql`, no mesmo diretório, já resolve os dois problemas corretamente com `incremental_strategy='microbatch'` + `event_time` + `lookback=3` — vale replicar o mesmo padrão em `int_viagens_diarias` em vez de inventar uma segunda estratégia incremental no projeto.

### A-06 [aviso] — partição Hive manual na tabela gold
`analytics/ddl/gold_receita_linha.sql:2-14`. Tabela Spark/parquet com `PARTITIONED BY (dt)` e `INSERT OVERWRITE ... PARTITION (dt='2026-09-27')` — estilo Hive clássico: quem consulta precisa conhecer o layout de partição e escrever o predicado certo, e um formato de data diferente do declarado (`dt` é `STRING`, não há validação de formato) dá resultado silenciosamente incorreto sem erro. Como o `dt` grava `'2026-09-27'` como string literal por linha do `INSERT`, também depende de disciplina externa (orquestrador) para não duplicar partição em reprocesso. Correção: migrar `gold_receita_linha` para Iceberg com partição oculta por transformação (`PARTITIONED BY (days(dt_referencia))`), no mesmo padrão que `silver_embarques` já usa — elimina a dependência de disciplina manual e mantém o formato de partição sempre correto.

### A-12 [aviso] — `SELECT *` em `dim_linha`
`analytics/models/marts/dim_linha.sql:3`. Propaga qualquer coluna nova ou removida de `stg_linhas` direto para o mart consumido por BI. Correção: listar as colunas (`cod_linha, nome_linha, operadora, modal`) explicitamente.

## Achados de revisão manual (fora do que o scanner cobre)

### R-1 — grão de `int_viagens_diarias` não corresponde ao nome do modelo
`analytics/models/intermediate/int_viagens_diarias.sql`. O modelo se chama "viagens diárias" mas não agrega nada — é uma linha por viagem individual com a data extraída (`cast(ts_embarque as date) as data_viagem`), sem `GROUP BY`. Isso por si não é incorreto, mas o nome promete um grão que o modelo não entrega, e é exatamente o tipo de ambiguidade que A-01 cataloga: um consumidor que junte esse modelo com uma dimensão esperando "uma linha por dia" vai duplicar. Correção: renomear para `int_viagens` (grão por viagem, mantendo o que já existe) e, se o grão diário agregado for realmente necessário a jusante, criar um modelo separado e explícito (`int_viagens_por_linha_dia`, com `GROUP BY cod_linha, data_viagem`) — não sobrecarregar o mesmo nome para dois grãos.

### R-2 — `snap_linhas` (SCD2) existe mas não é consumido; `dim_linha` não tem chave substituta
`analytics/snapshots/snap_linhas.yml` historiza `nome_linha`, `operadora` e `modal` por `cod_linha`, mas nenhum modelo em `models/marts` referencia `{{ ref('snap_linhas') }}` — o histórico existe e não é usado. Ao mesmo tempo, `dim_linha` seleciona direto de `stg_linhas` (chave natural `cod_linha`, sem `linha_sk` nem `valid_from`/`valid_to`), e `fct_viagens` junta implicitamente por `cod_linha` (chave natural, não substituta). Isso é o cenário do A-02: se uma linha trocar de operadora, não há como recuperar "qual operadora operava a linha X na data da viagem" — `dim_linha` só reflete o estado atual, e o snapshot que teria essa resposta está órfão. Correção: decidir se a dimensão de linha precisa de histórico (troca de operadora/modal é algo que o negócio quer analisar retroativamente); se sim, `dim_linha` passa a ler de `{{ ref('snap_linhas') }}`, expõe `linha_sk` (chave substituta) e `fct_viagens` resolve `linha_sk` pela vigência na carga; se não, remover o snapshot em vez de manter um artefato morto no projeto.

### R-3 — `fct_viagens` quebra a convenção de dinheiro em centavos que as duas DDLs seguem
`analytics/models/marts/fct_viagens.sql:9` — `cast(v.valor_tarifa_centavos as numeric(12,2)) / 100 as valor_tarifa`. As duas DDLs do lakehouse (`silver_embarques.valor_tarifa_centavos BIGINT`, `gold_receita_linha.receita_centavos BIGINT`) e os modelos staging/intermediate (`stg_viagens`, `int_viagens_diarias`) mantêm o valor como inteiro em centavos até esse ponto — consistente com a regra do repositório de nunca propagar `decimal`/`float` em valor monetário e converter só na camada de apresentação. O mart final é o único lugar que faz essa conversão, e é justamente o ponto onde BI/dashboard costuma consumir direto — arredondamento de ponto flutuante voltando a aparecer bem na borda de consumo é o cenário que a regra existe para evitar (soma de muitas linhas de `numeric(12,2)` acumula erro de forma diferente de somar `BIGINT` e dividir uma vez no fim). Correção: manter `valor_tarifa_centavos` (BIGINT) como coluna do mart e fazer a conversão para reais apenas na camada de apresentação (BI/semantic layer), com nome de coluna explícito (`valor_tarifa_centavos`), como o resto do projeto já faz.

### R-4 — nenhum teste de unicidade/not-null na chave de grão de nenhum modelo
Não há nenhum arquivo `schema.yml`/`properties.yml` com `tests: [unique, not_null]` em `models/staging`, `models/intermediate` ou `models/marts` — só existe teste (implícito) de mudança em `snap_linhas` via `check_cols`. Sem `unique` + `not_null` em `id_viagem` (`fct_viagens`) e `cod_linha` (`dim_linha`, `stg_linhas`), uma quebra de grão (duplicata) só aparece quando alguém nota o dashboard errado. Correção: adicionar `models/marts/marts.yml` com os testes de chave em `fct_viagens.id_viagem` e `dim_linha.cod_linha`, e o mesmo em staging.

### R-5 — `fct_viagens` e `dim_linha` são marts públicos sem contrato
Nenhum modelo declara `contract: {enforced: true}` nem `access: public`. Como esses dois marts alimentam BI (consumo externo ao projeto dbt), uma mudança de tipo ou remoção de coluna passa sem aviso para quem consome. Correção: declarar `access: public` + `contract: enforced: true` nos dois marts, com `data_type` explícito por coluna nas configs do schema.yml — e versionar o modelo (`v1`, `latest_version`) quando uma mudança for breaking.

## Observações (não são achados do catálogo)

- **`id_cartao`** trafega sem máscara por `stg_viagens`, `fct_viagens` e `int_validacoes`. Não bate com o padrão de busca de dado pessoal do catálogo (nome/cpf/email/telefone/endereço/data de nascimento), mas é identificador de cartão de bilhetagem — se for rastreável até um titular (associação cartão↔pessoa existir em outro sistema), vale confirmar com o DPO se é dado pessoal sob a LGPD e se precisa de pseudonimização/tokenização antes de chegar ao mart. Nenhum `data-classification.json` do projeto foi encontrado no repositório para confirmar a classificação — está fora do escopo desta revisão confirmar isso sozinho.
- **DDLs desconectadas do fluxo dbt:** `analytics/ddl/silver_embarques.sql` e `gold_receita_linha.sql` usam sintaxe Spark/Iceberg e nomes de tabela (`lake.silver.embarques`, `lake.gold.receita_linha`) que não aparecem em nenhum `source()` nem `ref()` dos modelos dbt revisados — os modelos dbt leem de `source('bilhetagem', ...)` (schema `raw_bilhetagem`), um pipeline aparentemente separado do que as DDLs descrevem. Se as DDLs forem o destino real dos dados que os modelos dbt processam (ex.: um adaptador fora do dbt materializa lá), vale documentar essa ponte explicitamente no PR — do jeito que está, um revisor não tem como confirmar que os dois pipelines representam o mesmo grão e os mesmos números.
- **`money-as-cents.md`** (regra do repositório) tem `applies_to: [backend-dotnet, frontend-react, android-kotlin]` — não lista `analytics`/dbt explicitamente. Trato R-3 acima como divergência de princípio a decidir com o time (o valor do achado não depende do `applies_to` listar a camada de dados), não como `CONFLITO` formal de `conflict-handling.md`, porque a rule não reivindica esse escopo. Se o time confirmar que a intenção é valer para todo dado monetário persistido, vale estender `applies_to`.

## Referências

- `.forge/skills/data-analytical-practices/references/antipatterns.md` — catálogo A-01–A-16.
- `.forge/skills/data-analytical-practices/references/best-practices.md`.
- `.forge/rules/domain/money-as-cents.md`.
- Saída bruta de `scripts/scan.sh --root analytics` e `scripts/check-data-governance.sh --path analytics` — ver `outputs/scan-output.txt` no diretório de eval desta revisão.
