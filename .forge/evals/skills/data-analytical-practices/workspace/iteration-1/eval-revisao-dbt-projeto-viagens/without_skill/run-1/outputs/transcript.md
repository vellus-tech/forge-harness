# Transcript — eval `revisao-dbt-projeto-viagens` / `without_skill` / run-1

Condição: baseline sem skill/agente do harness. Nenhum artefato em `template/.forge/skills`, `template/.forge/agents`, `plugin/` ou `.forge/evals` foi lido — revisão feita só com conhecimento próprio de engenharia de dados/dbt.

## Passos executados

1. Verifiquei bootstrap do diretório de trabalho designado (`cd` + `pwd` + `git branch --show-current`) — confirmado antes de qualquer ação.
2. Gravei `.t0` (`date +%s`) para medição de tempo.
3. Criei `work/` e rodei `fixtures/revisao-dbt-projeto-viagens/setup.sh work/` para materializar o projeto fixture dentro de `work/`.
4. Listei a árvore de `work/analytics` (`staging`, `intermediate`, `marts`, `snapshots`, `ddl`, `dbt_project.yml`).
5. Li o conteúdo integral de cada arquivo relevante:
   - `dbt_project.yml`
   - `ddl/gold_receita_linha.sql`, `ddl/silver_embarques.sql`
   - `models/intermediate/int_validacoes.sql`, `models/intermediate/int_viagens_diarias.sql`
   - `models/marts/dim_linha.sql`, `models/marts/fct_viagens.sql`
   - `models/staging/_sources.yml`, `models/staging/stg_linhas.sql`, `models/staging/stg_viagens.sql`
   - `snapshots/snap_linhas.yml`
6. Busquei se havia `profiles.yml` ou README de projeto adicional em `work/` (não havia; só `.gitignore`, `.gitattributes` e o `AGENTS.md` gerado pelo harness, sem informação específica do warehouse alvo) — registrei essa lacuna como observação de escopo no relatório em vez de assumir um adapter.

## Decisões analíticas (linha de raciocínio)

- **Modelagem**: tracei o grafo de dependências manualmente (`ref`/`source` de cada modelo) e constatei que `fct_viagens` não depende de nenhum modelo de staging — lê a source diretamente. Isso é o achado mais grave de modelagem, porque quebra o propósito da camada de staging e duplica lógica de cast.
- **Incremental**: chequei se cada modelo `materialized='incremental'` declarava `unique_key`. Nenhum declarava. Como o domínio é bilhetagem/receita, tratei isso como P0 (risco de duplicação financeira), não como estilo.
- **Marts**: verifiquei se `fct_viagens` e `dim_linha` tinham testes de integridade referencial — nenhum `schema.yml` existe em nenhuma das três camadas, então tratei ausência total de testes como achado único de alta severidade (P0) em vez de espalhar em vários itens redundantes.
- **Snapshots**: revisei a config de `snap_linhas` (`strategy: check`, `check_cols`, `invalidate_hard_deletes: true`) — config em si é correta; o único ponto observado foi o acoplamento do snapshot ao modelo de staging em vez da source bruta, classificado como P2 por ser baixo risco dado que `stg_linhas` é apenas rename/cast.
- **Particionamento**: comparei as duas tabelas do lakehouse (`ddl/silver_embarques.sql` usa partição nativa Iceberg `days(ts_embarque)`; `ddl/gold_receita_linha.sql` usa uma coluna `dt STRING` derivada manualmente) — sinalizei a inconsistência de estratégia de particionamento entre as duas tabelas do mesmo lakehouse.
- **Duplicidade de métrica**: notei que `gold_receita_linha.sql` recalcula receita por linha fora do dbt (script Spark SQL com data hardcoded), o que cria uma segunda fonte de verdade para a mesma métrica de receita que `fct_viagens` também poderia derivar. Elevei isso a P0 porque duas fontes de receita divergentes é um risco direto de decisão de negócio errada.
- **Modelos órfãos**: busquei ocorrências de `ref('int_viagens_diarias')` e `ref('int_validacoes')` em todo o projeto — nenhuma. Classifiquei como P1 (dívida de manutenção), não P0, porque não corrompe dado já publicado, só custa manutenção.
- Não apliquei nenhuma correção nos arquivos do projeto — a tarefa pediu só diagnóstico.

## Entregáveis

- `work/docs/revisao-analitico.md` — relatório de revisão pedido pelo usuário, salvo no path exato solicitado dentro do projeto fixture.
- `outputs/revisao-analitico.md` — cópia do mesmo relatório, para o harness de eval.
- `outputs/transcript.md` — este arquivo.

## Timing

Ver `timing.json` no diretório do run (gravado após este transcript, junto com `.t0`/`date +%s` finais).
