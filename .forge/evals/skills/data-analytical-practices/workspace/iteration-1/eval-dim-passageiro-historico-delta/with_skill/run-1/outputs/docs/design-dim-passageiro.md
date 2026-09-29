# Desenho — histórico de categoria tarifária do passageiro e particionamento de fct_recargas

Contexto: `docs/contexto-lakehouse.md`. Objetivo do time de analytics: histórico do cadastro do passageiro para analisar migração de categoria tarifária, com `fct_recargas` (grão: uma linha por recarga confirmada) replicada para o BigQuery da parceira.

## 1. Dimensão com histórico (`snap_passageiro` → `dim_passageiro`)

**Decisão central: separar o que tem histórico do que é dado pessoal.** O rascunho original rastreava `nome`, `email`, `telefone`, `cpf`, `bairro` e `categoria_tarifaria` juntos num `dbt snapshot` SCD2. Isso é o antipattern A-16 do catálogo (`data-analytical-practices/references/antipatterns.md`): uma dimensão SCD2 com atributo pessoal multiplica o problema de eliminação do titular — cada alteração de nome, e-mail ou telefone vira uma linha nova e permanente, e a LGPD (art. 16, art. 18 VI) pede eliminação, não uma linha marcada como não corrente.

Como só a **categoria tarifária** é o que a análise de migração precisa histórico, o `snap_passageiro.sql` ajustado rastreia só ela:

- `unique_key: id_passageiro`, `strategy: timestamp` com `updated_at: atualizado_em` — trocado de `strategy: check`. A base (`references/best-practices.md`, seção SCD) recomenda `timestamp` por ser robusta a coluna nova ou removida na origem; `check` só se justifica sem `updated_at` confiável, e aqui `atualizado_em` já existe e não estava sendo usado.
- `hard_deletes: invalidate` no lugar de `invalidate_hard_deletes=True` — sintaxe legada, substituída no dbt 1.9 (antipattern A-14, achado pelo `scan.sh`).
- Dado pessoal (`nome`, `email`, `telefone`, `cpf`, `bairro`) sai do snapshot e continua em `stg_passageiros` (SCD1, mutável): `UPDATE`/`DELETE` resolve o pedido de eliminação do DPO diretamente, sem tocar no histórico de categoria. Se algum desses campos precisar de histórico no futuro, isso é uma decisão separada, com base legal e prazo de retenção próprios — não decido isso aqui.

**Chave substituta (A-02).** Hoje `fct_recargas` (rascunho) referencia `id_passageiro` como chave natural. Com `dim_passageiro` virando SCD2 por categoria, ligar a fato pela chave natural volta a expor o mesmo problema do A-02: uma recarga antiga, ao ser rejuntada com a dimensão, pode casar com a categoria *atual* do passageiro em vez da categoria vigente *na data da recarga*. A correção correta é resolver uma chave substituta (`id_passageiro_sk`, por exemplo o `dbt_scd_id` do snapshot ou um hash de `id_passageiro` + `dbt_valid_from`) na carga da fato, pela vigência (`data_recarga BETWEEN dbt_valid_from AND COALESCE(dbt_valid_to, '9999-12-31')`), e guardar essa chave na fato — não a natural.

**Isto não foi aplicado ao `models/marts/fct_recargas.sql` nem ao `gold_fct_recargas.sql` nesta rodada** — o pedido do usuário foi ajustar os dois arquivos citados (snapshot e DDL) e desenhar a dimensão; resolver a chave substituta na carga da fato é mudança de lógica do mart, fora do escopo dos dois arquivos tocados. Fica registrado aqui como próximo passo antes de `dim_passageiro`/`fct_recargas` irem para produção — sem ele, o histórico de categoria existe mas a fato não consegue consultá-lo corretamente por vigência.

**Eliminação do titular (A-15).** Quando o DPO pedir eliminação: `DELETE`/`UPDATE` em `stg_passageiros` (SCD1, imediato); o histórico de categoria em `snap_passageiro` não guarda dado pessoal, então não precisa de ação adicional ali. Isso vale só para as colunas do lakehouse Delta tratadas aqui — o prazo de 15 dias do DPO e o `VACUUM`/time travel da própria `stg_passageiros` (se ela for Delta) não foram cobertos porque não estavam no escopo desta mudança; se `stg_passageiros` for tabela Delta com histórico de versão, o mesmo raciocínio do A-15 (retenção de time travel menor que o prazo acordado) se aplica a ela.

## 2. Particionamento de `fct_recargas`

Os limiares de particionamento são por produto e não se transferem entre eles (regra do especialista analítico) — por isso Databricks e BigQuery são tratados separado, mesmo sendo a mesma tabela replicada.

### Databricks (fonte, Delta)

`gold.fct_recargas` está em ~300 GB hoje, crescendo ~8 GB/mês (`docs/contexto-lakehouse.md`). O limiar do Databricks é **não particionar abaixo de 1 TB**; liquid clustering é recomendado para todas as tabelas gerenciadas, inclusive abaixo desse limiar. O rascunho tinha `PARTITIONED BY (data_recarga)` — estilo Hive declarado à mão, exatamente o antipattern A-06 que o `scan.sh` encontrou (arquivo:linha no achado abaixo) e também um caso de superparticionamento prematuro (A-05), já que 300 GB fica bem abaixo de 1 TB.

Ajustei o DDL para `CLUSTER BY (data_recarga, cod_canal)` — as duas colunas que o BI já usa como filtro — sem `PARTITIONED BY`. Em ritmo de +8 GB/mês, a tabela levaria mais de 7 anos para cruzar 1 TB nesse crescimento linear; o ponto de revisão é quando ela se aproximar desse limiar, não uma data fixa.

### BigQuery (réplica da parceira)

O pedido do time de BI da parceira foi "o mesmo particionamento diário" que o Databricks usa. Aqui está o ponto de atenção que não dá para responder só copiando a decisão da fonte: o limiar do BigQuery é diferente (preferir clustering quando o particionamento deixaria menos de ~10 GB por partição) e a réplica no BigQuery é **~40 GB no total** (`docs/contexto-lakehouse.md`), não 300 GB. Se esses 40 GB cobrem um histórico de mais de poucas semanas — o que é o caso normal para uma fato de recarga acumulada — particionar por dia deixaria cada partição na casa de dezenas ou centenas de MB, muito abaixo do limiar de ~10 GB: isso é o mesmo antipattern A-05 (superparticionamento), só que no BigQuery em vez do Databricks.

Não decidi isso sozinho porque é uma divergência do que a parceira pediu — registro as duas opções para a conversa com o time de BI dela, em vez de simplesmente atender o pedido literal ou simplesmente recusar:

1. **Particionar por dia mesmo assim** (`PARTITION BY DATE(data_recarga)`) + `CLUSTER BY (cod_canal)` como compensador. Atende o pedido literal e mantém o mesmo mental model de partição diária que a parceira já usa nos dashboards dela, ao custo de ficar abaixo do limiar recomendado — vale medir o tamanho médio por partição no `INFORMATION_SCHEMA.PARTITIONS` depois da carga real para confirmar o quão abaixo fica.
2. **Particionar por mês** (`PARTITION BY DATE_TRUNC(data_recarga, MONTH)`) + `CLUSTER BY (data_recarga, cod_canal)`. Fica mais perto do limiar de ~10 GB/partição com o volume atual, mas diverge do "particionamento diário" pedido — precisa alinhar com o time de BI da parceira antes, porque muda a poda esperada nas consultas deles (predicado por dia ainda funciona, só a granularidade da partição em si que muda).

Minha recomendação é a opção 2, com a ressalva explícita para a parceira do porquê (volume atual não sustenta partição diária sem multiplicar metadado); mas como envolve o consumo dela, é decisão para alinhar, não para aplicar sem conversar. Nenhuma DDL de BigQuery foi criada nesta rodada — o pedido do usuário foi cobrir o desenho no documento, não gerar o DDL do BigQuery.

## 3. Achados do scanner (`scan.sh`, escopo `analytics/`)

```
FOUND A-06 [aviso] 1 ocorrência — analytics/ddl/gold_fct_recargas.sql:10 (PARTITIONED BY (data_recarga);) — corrigido nesta mudança
FOUND A-14 [alto]  1 ocorrência — analytics/snapshots/snap_passageiro.sql:7 (invalidate_hard_deletes=True) — corrigido nesta mudança
```

`check-data-governance.sh` não achou conflito (nenhuma regra do projeto sobre isolamento multi-tenant/store se aplica a este par de arquivos). A-16 (SCD2 com atributo pessoal) foi achado por revisão manual, não pelo scanner — o próprio catálogo documenta que inventário de campo pessoal é item de revisão, não regra estática.
