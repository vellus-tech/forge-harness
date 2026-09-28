# Transcript — eval-borda-delta-50gb-particao-e-path-sem-sql (with_skill, run-1)

Papel assumido: `data-analytical` (agente consultivo do Forge, definição em `template/.forge/agents/data/data-analytical.md`), seguindo o Protocolo do arquivo, passo a passo, com a skill `data-analytical-practices` carregada (fonte em `template/.forge/skills/data-analytical-practices/`, pois o `setup.sh` da fixture removeu `.forge/skills`/`.forge/agents` do work dir para não contaminar o baseline — esta rodada é a que "reinstala" a skill).

## 1. Escopo

Paths afetados pelo pedido do usuário: `lakehouse/gold/viagens.sql` (DDL da tabela Delta) e `services/validador` (serviço apontado como escritor da fato). Lido o DDL:

```sql
CREATE TABLE IF NOT EXISTS gold.viagens (
  viagem_id STRING NOT NULL, tenant_id STRING NOT NULL, operadora_id STRING NOT NULL,
  linha_id STRING NOT NULL, cartao_sk BIGINT NOT NULL, tarifa_centavos BIGINT NOT NULL,
  validado_em TIMESTAMP NOT NULL
) USING DELTA PARTITIONED BY (operadora_id, linha_id);
```

Grão: uma linha por `viagem_id` (fato de viagem validada). Sem `LOCATION` — tabela gerenciada.

Lido `services/validador/main.go` e `go.mod`: stub sem lógica de escrita (`fmt.Println("validador")`); comentário indica que o serviço publica em tópico `viagens.validadas`, não escreve Delta diretamente.

## 2. Rules e decisões do projeto

Lidos (work dir): `.forge/rules/domain/money-as-cents.md`, `.forge/rules/data/data-governance.md`, `.forge/rules/data/data-config-sql.md` (não aplicável — é regra de PostgreSQL relacional), `.forge/rules/architecture/internal-grpc-communication.md` (não relevante ao pedido — não há integração de serviço em jogo). Nenhum ADR do projeto encontrado (`.forge/product/current/adr/` sem entradas específicas de lakehouse). Nenhum `data-classification.json` no repositório (`find` não retornou nada).

`tarifa_centavos BIGINT` já respeita `money-as-cents.md` — sem violação. `data-governance.md` não nomeia mecanismo de isolamento multi-tenant para lakehouse (só PostgreSQL/MongoDB/Redis) — sem conflito bloqueante, mas lacuna anotada na resposta.

Nenhuma divergência entre rule/ADR do projeto e a recomendação da skill: não há bloco `CONFLITO` a devolver. A divergência é entre o pedido do usuário e a prática da skill (limiar de particionamento do Databricks) — tratada como achado/recomendação na resposta, não como conflito de governança.

## 3. Dado sensível

Comando (contrato do protocolo: só dois comandos permitidos pelo hook do agente):

```
$ bash .forge/scripts/check-data-governance.sh --path lakehouse/gold/viagens.sql
FAIL data-governance/universo-vazio — 0 arquivo(s) examinado(s) — exit 1
```

Interpretação pelo protocolo: `universo-vazio` é "não verificado" (o gate só lê `.go .kt .ts .rego .py .md`; `.sql` fica fora) — não é aprovação nem achado. PAN/PII em `viagens.sql` fica com a revisão manual do scanner e desta resposta.

```
$ bash .forge/scripts/check-data-governance.sh --path services/validador
OK data-governance/universo — 1 arquivo(s) examinado(s)
OK data-governance (0 .md, 1 código, no divergence) — exit 0
```

Sem achado de governança em `services/validador`.

## 4. Varredura

```
$ bash .forge/skills/data-analytical-practices/scripts/scan.sh --root lakehouse/gold/viagens.sql --root services/validador
INFO data-analytical-practices motor=rg raizes=2 universo=sql yml
FOUND A-06 [aviso] 1 ocorrência(s) — partição estilo Hive declarada à mão em tabela
  lakehouse/gold/viagens.sql:13: PARTITIONED BY (operadora_id, linha_id);
OK A-08 / A-10 / A-12 / A-14 — nenhuma ocorrência
ARQUIVOS-VARRIDOS 1
```

(rodado a partir do source da skill em `template/.forge/skills/data-analytical-practices/scripts/scan.sh`, já que o diretório correspondente não existe no work dir da fixture, pelo motivo do cabeçalho acima.)

## 5. Julgamento

- A-06 no `PARTITIONED BY` **atual** é achado real: não é transformação Iceberg (`days(`, `bucket(` etc.) que ficaria fora do escopo do detector — é Hive puro em Delta. A pergunta do usuário propõe trocar as colunas, não remover o padrão Hive; o julgamento (best-practices.md #1: "não particionar abaixo de 1 TB, liquid clustering recomendado para todas as tabelas gerenciadas" no Databricks) é que a correção não é trocar as colunas de partição, é sair de partição manual para liquid clustering — a tabela (~50 GB) está bem abaixo do limiar de 1 TB citado pela skill.
- Julgamento adicional sobre o pedido: particionar por dia sobre 50 GB/~2 GB por mês tende a gerar partições pequenas (soma-se a granularidade por operadora) — candidato a A-05 (superparticionamento), mesmo sem detector estático para isso (é limiar de tamanho físico, verificação de runtime, não estática).
- Delta não suporta `ALTER TABLE ... PARTITIONED BY` em tabela populada — mudança de partição é sempre reescrita física (CTAS/REPLACE TABLE ou INSERT OVERWRITE), custo relevante numa tabela de 50 GB; isso vale tanto para a proposta do usuário quanto para a recomendação de liquid clustering — mas só a segunda resolve o problema de origem.
- `services/validador`: nada a julgar — stub sem lógica de escrita Delta; o comentário aponta publicação em tópico, então o escritor real da tabela (se existe hoje) não está neste diretório. Fora do escopo do `data-analytical` decidir o desenho de ingestão por tópico — isso é `data-streaming`.

## 6. Resposta

Grava-se em `outputs/recomendacao.md`: recomendação de não seguir o particionamento por dia+operadora proposto, migrar para liquid clustering (`CLUSTER BY (validado_em, operadora_id)`), explicação do porquê (A-06/A-05, limiar do Databricks, mecânica de reescrita do Delta, ausência de `LOCATION`), achado sobre `services/validador` (stub, fora de escopo de particionamento; ingestão por tópico pertence a `data-streaming`), e checklist do agente (grão, money, multi-tenant, dado pessoal, particionamento).

Nenhum `Write`/`Edit` foi aplicado à árvore de trabalho do usuário (`lakehouse/gold/viagens.sql` e `services/validador` permanecem como a fixture entregou) — o agente `data-analytical` não escreve DDL/código na árvore ("uma árvore, um escritor"); a aplicação caberia ao agente de engenharia ou ao `task-coder`, fora do escopo desta rodada de eval.

## Nota sobre restrições da rodada

Nenhum subagente foi spawnado (a tarefa do harness pede simulação/registro, não execução real); não houve necessidade de despachar outro especialista porque o próprio `data-analytical` cobre modelagem/particionamento/tabela, e o achado sobre `services/validador` foi resolvido por leitura direta (stub sem lógica), sem exigir `data-streaming` nesta rodada — a resposta apenas nomeia esse especialista como dono do pipeline de ingestão por tópico, caso o usuário queira revisá-lo. Nenhum `git commit`/`push`/`checkout`/`stash`, `npm test`, `docker`, `ledger-ops.sh`, `liaison-ops.sh` ou `gh` (escrita) foi executado nesta rodada, além do `git init`/`commit` interno do `setup.sh` da fixture (passo 2 do mandato, script do harness, não ação livre deste agente).
