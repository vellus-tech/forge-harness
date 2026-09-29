# Transcript — eval-borda-delta-50gb-particao-e-path-sem-sql / without_skill / run-1

## Tarefa recebida

> A tabela gold.viagens no Databricks (Delta, uns 50 GB hoje, cresce uns 2 GB por mês) está lenta
> no dashboard, que filtra quase sempre por data de validação e operadora. O DDL está em
> lakehouse/gold/viagens.sql. Troca o particionamento para ficar por dia e por operadora, que deve
> resolver. Aproveita e confere também services/validador, que é quem grava as viagens.

## Passos, em ordem

1. Preparei o workspace do caso via `setup.sh` (fixture do forge-harness, sem skills/agentes —
   baseline `without_skill`).
2. Li `lakehouse/gold/viagens.sql`: `CREATE TABLE gold.viagens (...) USING DELTA PARTITIONED BY
   (operadora_id, linha_id)`. Colunas: `viagem_id, tenant_id, operadora_id, linha_id, cartao_sk,
   tarifa_centavos, validado_em (TIMESTAMP)`. Sem coluna de data derivada.
3. Li `services/validador/main.go`: stub de ~8 linhas, só `fmt.Println("validador")`. Comentário
   no arquivo diz que o serviço grava cada viagem validada no tópico `viagens.validadas`
   (aparenta ser fila/Kafka), não há código de escrita no Delta neste arquivo.
4. Avaliei o pedido literal (particionar por dia + operadora) contra o volume informado (~50 GB,
   +2 GB/mês). Com meu conhecimento de Delta Lake/Databricks: partição por dia neste volume tende
   a gerar partições muito pequenas (small-file problem), especialmente combinada com
   `operadora_id` como segundo nível — risco de piorar a performance do dashboard em vez de
   melhorar. Decidi implementar o que foi pedido (é uma instrução explícita, não uma pergunta
   aberta) mas documentar a ressalva e as alternativas (partição mensal + ZORDER, ou só ZORDER sem
   partição física) para decisão humana antes de rodar em produção — não apliquei nenhuma
   alternativa sem confirmação.
5. Escrevi `outputs/viagens.sql`: DDL revisado, com coluna gerada `data_validacao DATE GENERATED
   ALWAYS AS (CAST(validado_em AS DATE))` e `PARTITIONED BY (data_validacao, operadora_id)` — data
   primeiro (grão mais grosso) e operadora em segundo, alinhado ao padrão de filtro do dashboard
   (quase sempre por data primeiro).
6. Escrevi `outputs/migration.sql`: Delta não suporta `ALTER TABLE` para trocar colunas de
   partição in-place, então documentei e escrevi a migração via `CREATE OR REPLACE TABLE ... AS
   SELECT` (CTAS), com pré-requisitos (congelar escritores, espaço em disco para pico de reescrita,
   medir em staging antes de produção) e passos pós-migração (`OPTIMIZE`,
   `ANALYZE TABLE ... COMPUTE STATISTICS`).
7. Revisei `services/validador/main.go` quanto a path/partição hardcoded: não há nada a mudar,
   porque o arquivo é um stub sem lógica de escrita no Delta. Sinalizei como ponto em aberto que a
   escrita real provavelmente acontece em um componente fora deste repositório (o job que consome
   `viagens.validadas`), que eu não localizei e que seria o lugar certo para checar paths/partições
   hardcoded antes do corte em produção. Não editei `main.go` — não havia lógica de particionamento
   nele para revisar.
8. Escrevi `outputs/ANALISE.md` consolidando o raciocínio, a ressalva técnica, as duas alternativas
   recomendadas e os próximos passos não executados (fora do escopo desta rodada: rodar
   `DESCRIBE DETAIL`/`DESCRIBE HISTORY` reais, testar em staging, confirmar se há leitura por path
   físico em vez de tabela registrada).

## Entregáveis

- `outputs/viagens.sql` — DDL revisado com particionamento por `(data_validacao, operadora_id)`.
- `outputs/migration.sql` — script de migração (CTAS) com pré-requisitos e pós-passos.
- `outputs/ANALISE.md` — análise completa, ressalva técnica sobre small-file problem, alternativas
  e achados sobre `services/validador`.
- `outputs/transcript.md` — este arquivo.

## Não executado (fora do escopo/regras desta rodada de eval)

- Nenhum comando real contra Databricks (sem acesso ao workspace real; script SQL é entregável,
  não execução).
- Nenhuma alteração em `services/validador/main.go` (nada a mudar nele).
- Nenhum `git commit`/push — a árvore de trabalho fica como está, entregáveis só em `outputs/`.
