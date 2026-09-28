# Transcript — eval-dim-passageiro-historico-delta / with_skill / run-1

## 1. Bootstrap

- `cd .../evals-100 && pwd && git branch --show-current` — confirmou diretório e branch `chore/evals-skills-agentes` esperados.
- `date +%s > .t0` gravado.
- `mkdir -p work outputs` no diretório de run.

## 2. Preparação da fixture

- `bash fixtures/dim-passageiro-historico-delta/setup.sh work` — rodou `node forge.mjs init` + overlay do projeto analítico + `git init`/commit dentro de `work/` (script da fixture, isolado do repo real). Saída limpa, exit 0.
- Inventariei `work/analytics/` e `work/docs/`: `snapshots/snap_passageiro.sql`, `ddl/gold_fct_recargas.sql`, `models/marts/fct_recargas.sql`, `docs/contexto-lakehouse.md`.

## 3. Leitura da skill carregada

- Li `template/.forge/skills/data-analytical-practices/SKILL.md` (protocolo: escopo → rules do projeto → detecção → julgamento → relatório).
- Li `references/antipatterns.md` (catálogo A-01 a A-16) e `references/best-practices.md` inteiros.
- Li `work/.forge/rules/data/data-governance.md` e `work/.forge/rules/domain/money-as-cents.md` (não achei rule analítica específica no projeto além da governança transversal; `valor_centavos BIGINT` no DDL já está de acordo com money-as-cents).

## 4. Leitura dos artefatos do usuário

- `snap_passageiro.sql`: snapshot `dbt` estratégia `check` rastreando `nome, email, telefone, cpf, bairro, categoria_tarifaria` com `invalidate_hard_deletes=True`.
- `gold_fct_recargas.sql`: `CREATE TABLE ... USING DELTA PARTITIONED BY (data_recarga)`.
- `docs/contexto-lakehouse.md`: Databricks/Delta, `gold.fct_recargas` ~300 GB (+8 GB/mês), `gold.dim_passageiro` ~4M passageiros, réplica no BigQuery da parceira (~40 GB), prazo de 15 dias do DPO para eliminação.

## 5. Detecção

- `bash .forge/scripts/check-data-governance.sh --path work` → `OK` (sem conflito de rule; escopo desses dois arquivos não toca isolamento multi-tenant).
- `bash .../data-analytical-practices/scripts/scan.sh --root work` →
  - `FOUND A-06 [aviso]` em `analytics/ddl/gold_fct_recargas.sql:10` (`PARTITIONED BY (data_recarga);`).
  - `FOUND A-14 [alto]` em `analytics/snapshots/snap_passageiro.sql:7` (`invalidate_hard_deletes=True`).
  - A-08, A-10, A-12 limpos.
- Revisão manual (não é regra do scanner, é item de revisão do catálogo): `snap_passageiro.sql` rastreia `nome/email/telefone/cpf/bairro` numa dimensão SCD2 → **A-16**.

## 6. Julgamento e decisões

1. **A-16 (dimensão SCD2 com atributo pessoal):** só `categoria_tarifaria` é o que a análise de migração precisa como histórico. Decisão: tirar os campos pessoais do snapshot; eles continuam em `stg_passageiros` (SCD1 mutável, já existente como source do snapshot) — nenhuma tabela nova precisou ser criada para isso.
2. **SCD2 strategy:** trocar `check` por `timestamp` com `updated_at=atualizado_em` — a base recomenda `timestamp` por robustez a colunas novas/removidas, e `atualizado_em` já estava sendo selecionado mas não usado como `updated_at`. `check` só se justificaria sem `updated_at` confiável, que não é o caso aqui.
3. **A-14:** `invalidate_hard_deletes=True` → `hard_deletes: invalidate` (sintaxe dbt 1.9+).
4. **A-06/A-05 no Databricks:** 300 GB está abaixo do limiar de 1 TB para particionar no Databricks — troquei `PARTITIONED BY (data_recarga)` por `CLUSTER BY (data_recarga, cod_canal)` (liquid clustering, recomendado para toda tabela gerenciada, nas colunas que o BI já filtra).
5. **A-02 (chave substituta):** identificado como pendência — a fato ainda liga por `id_passageiro` natural, e com a dimensão virando SCD2 isso volta a expor o A-02. Decidi **não** alterar `models/marts/fct_recargas.sql` nem a coluna do DDL nesta rodada, por ser mudança de lógica de carga fora dos dois arquivos que o usuário pediu para ajustar — registrei como próximo passo explícito no design doc, com a fórmula de resolução por vigência (`dbt_valid_from`/`dbt_valid_to`).
6. **BigQuery — particionamento diário pedido pela parceira:** os limiares são por produto e não se transferem. Com ~40 GB total no BigQuery, particionar por dia provavelmente cai bem abaixo do limiar de ~10 GB/partição do BigQuery (A-05 no destino, mesmo corrigindo no Databricks). Decidi **não aplicar silenciosamente** nem a literalidade do pedido nem a correção — documentei as duas opções (diário + clustering compensador vs. mensal + clustering) com recomendação (mensal) e a ressalva de que precisa alinhar com o time de BI da parceira antes, porque muda a granularidade de poda que eles esperam. Nenhum DDL de BigQuery foi criado — o pedido foi cobrir o desenho, não gerar o script.

## 7. Escrita

- Editei `work/analytics/snapshots/snap_passageiro.sql` (comentário explicando a exclusão de PII + `strategy: timestamp` + `hard_deletes: invalidate`).
- Editei `work/analytics/ddl/gold_fct_recargas.sql` (comentário do grão/limiar + `CLUSTER BY` no lugar de `PARTITIONED BY`).
- Criei `work/docs/design-dim-passageiro.md` com: (1) desenho da dimensão com histórico e separação PII/atributo de negócio, chave substituta e eliminação do titular; (2) particionamento Databricks vs. BigQuery, com a divergência do pedido da parceira explicitada; (3) tabela dos achados do scanner.
- Copiei os três arquivos para `outputs/` preservando os paths relativos (`analytics/snapshots/`, `analytics/ddl/`, `docs/`).

## 8. Não fiz (fora do escopo desta rodada, registrado no design doc)

- Não toquei `models/marts/fct_recargas.sql` (resolução de chave substituta fica pendente, documentada).
- Não criei DDL de BigQuery (documento cobre o desenho, não o script).
- Não rodei `git commit`/`push` nem qualquer comando de escrita externa — nada além dos scripts de detecção de leitura (`check-data-governance.sh`, `scan.sh`) e edição de arquivos dentro de `work/`.
