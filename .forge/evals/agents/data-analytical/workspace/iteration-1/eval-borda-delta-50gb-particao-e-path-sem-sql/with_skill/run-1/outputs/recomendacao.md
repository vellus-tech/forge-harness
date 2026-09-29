# Recomendação — particionamento de gold.viagens (Delta/Databricks)

## Resposta direta

Não troque `PARTITIONED BY (operadora_id, linha_id)` por `PARTITIONED BY (data_validacao, operadora_id)` (ou qualquer variação por dia). Numa tabela Delta de ~50 GB, crescendo ~2 GB/mês, **nenhum particionamento manual é indicado** — nem o atual, nem o proposto. O limiar do Databricks é não particionar abaixo de 1 TB; liquid clustering é a recomendação padrão para tabelas gerenciadas, inclusive abaixo desse limiar. A tabela já está abaixo do limiar hoje (A-06/A-05 do catálogo) e criar partição por dia pioraria o quadro, não resolveria.

## Por que particionar por dia é o problema, não a solução

- Grão diário sobre 50 GB (crescendo a ~2 GB/mês) produz partições físicas pequenas — na faixa de dezenas a poucas centenas de MB cada, dependendo de quantas operadoras e quanto volume por dia. Multiplicar por operadora nas mesmas partições agrava: cada combinação (dia × operadora) vira um diretório próprio, e o Delta grava um arquivo por partição por writer/microbatch. É o cenário canônico de superparticionamento (A-05): metadado explode, o planejamento da consulta fica mais lento que a execução, e o small-file problem derruba o throughput de leitura que o dashboard depende.
- `PARTITIONED BY` no DDL já é particionamento Hive declarado à mão (A-06): o scanner confirmou o achado na linha atual (`lakehouse/gold/viagens.sql:13`). Trocar as colunas de partição não remove o antipattern, só desloca onde ele dói.
- Delta não suporta `ALTER TABLE ... PARTITIONED BY` para mudar colunas de partição de uma tabela populada. Repartição física exige reescrever todos os dados: `CREATE TABLE AS SELECT` para uma tabela nova (com o layout final) seguido de `REPLACE TABLE` / troca de nome, ou um job de backfill com `INSERT OVERWRITE` reparticionado. Numa tabela de 50 GB isso é uma migração com custo de I/O e crédito não trivial, janela de escrita concorrente do pipeline de validação a coordenar, e risco de leitura inconsistente durante o corte — não é uma mudança de DDL "de graça".
- O DDL não declara `LOCATION`: é tabela gerenciada, path do Unity Catalog/metastore. Isso é bom (evita o antipattern de path hardcoded fora do Catalog) mas significa que qualquer swap de tabela (CTAS + rename) precisa ser feito pelo mecanismo do Catalog (`REPLACE TABLE`/rename atômico), não por manipulação direta de diretório — reforça que a migração é uma operação orquestrada, não um `ALTER`.

## O que resolve o problema real (latência do dashboard filtrando por data de validação e operadora)

1. **Liquid clustering** em vez de partição manual: `CREATE TABLE gold.viagens (...) USING DELTA CLUSTER BY (validado_em, operadora_id)` (ou `ALTER TABLE gold.viagens CLUSTER BY (validado_em, operadora_id)` se a tabela for recriada/já suportar liquid clustering). O motor faz pruning por essas colunas sem exigir que o consumidor — nem o pipeline de escrita — conheça o layout de diretório, sem multiplicar arquivos pequenos, e sem o antipattern A-06.
2. Se a tabela for migrada para liquid clustering, isso ainda é uma reescrita física (mesma ordem de custo de uma repartição) — mas resolve o problema de fato, ao contrário de trocar uma partição Hive por outra.
3. `OPTIMIZE gold.viagens` (compactação) e, se liquid clustering, `OPTIMIZE` também reorganiza pelos clustering keys — programar como manutenção periódica, não como evento único.
4. Medir antes de aplicar: `DESCRIBE DETAIL gold.viagens` para confirmar tamanho médio de arquivo atual e contagem de arquivos; isso valida se o sintoma é de fato pruning ruim (resolvido por clustering) ou outra causa (estatísticas desatualizadas, shape de consulta do dashboard, falta de `OPTIMIZE`/`ANALYZE`).

## services/validador — fora do escopo de particionamento da tabela

`services/validador/main.go` é um stub (`fmt.Println("validador")`); não há lógica de escrita a `gold.viagens` no código hoje, nem path, nem partição hardcoded para revisar. O comentário do arquivo diz que o serviço "grava cada viagem validada no tópico `viagens.validadas`" — ou seja, pelo texto disponível, o validador publica num tópico de mensageria, não escreve diretamente na tabela Delta; quem materializa `gold.viagens` a partir desse tópico é outro componente (pipeline/job), fora do que este código mostra. Duas consequências:

- Não há achado de particionamento/path a reportar em `services/validador` — nada a examinar além do stub.
- Se o objetivo é auditar o pipeline que efetivamente escreve em `gold.viagens` (consumidor do tópico, coalescência de writes, path/partição usados na escrita), esse componente não está neste diretório; é `data-streaming` quem cobre o desenho de ingestão por tópico até a materialização — este agente (`data-analytical`) responde pela tabela final, não pelo pipeline de ingestão.

## Checklist (data-analytical)

- Grão: `viagem_id` como grão único da fato — sem indício de grão misto (A-01). Não verificado por teste de unicidade em runtime (fora do escopo estático).
- Money: `tarifa_centavos BIGINT` — já em centavos, nome com sufixo correto (`money-as-cents.md`), sem violação.
- Multi-tenant: `tenant_id` presente na fato. A rule de governança (`data-governance.md`) só nomeia mecanismo para PostgreSQL/MongoDB/Redis; não há mecanismo de isolamento lakehouse (row filter/RLS do Unity Catalog) declarado — não é conflito bloqueante (a rule não cobre lakehouse), mas é lacuna a registrar: recomendo row filter por `tenant_id` no Catalog se o warehouse for compartilhado entre tenants.
- Dado pessoal: sem `data-classification.json` no projeto (não encontrado); colunas da fato são `viagem_id`, `tenant_id`, `operadora_id`, `linha_id`, `cartao_sk`, `tarifa_centavos`, `validado_em` — `cartao_sk` é chave substituta (BIGINT), não PAN/CPF em claro; sem coluna de nome/e-mail/CPF na fato. Não verificado contra classificação formal — fica com a revisão manual, como o protocolo exige quando o arquivo de classificação não existe.
- Particionamento: **A-06 encontrado** (`scan.sh`, `lakehouse/gold/viagens.sql:13`) na partição atual; a mudança pedida (dia + operadora) mantém o antipattern e adiciona risco de A-05 (superparticionamento). Recomendação: liquid clustering, não repartição Hive.
