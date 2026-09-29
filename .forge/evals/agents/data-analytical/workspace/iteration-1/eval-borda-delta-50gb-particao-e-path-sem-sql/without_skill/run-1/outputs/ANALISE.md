# Análise — reparticionamento de gold.viagens

## Contexto observado

- `lakehouse/gold/viagens.sql`: tabela Delta, hoje particionada por `(operadora_id, linha_id)`.
- Tamanho atual ~50 GB, crescimento ~2 GB/mês (~24 GB/ano).
- Dashboard filtra quase sempre por data de validação (`validado_em`) e operadora (`operadora_id`).
- `services/validador/main.go` é o gravador da tabela — hoje é um stub (`fmt.Println("validador")`)
  sem lógica de escrita implementada; o comentário do arquivo diz que ele grava no tópico
  `viagens.validadas` (aparenta ser Kafka/fila), não diretamente no Delta. Não há, portanto,
  código de escrita no Delta para revisar quanto a partição neste serviço — provavelmente a
  escrita real acontece em um job de streaming/batch a jusante, fora do que está neste
  repositório. Sinalizado como ponto em aberto abaixo.

## O que foi pedido vs. ressalva técnica

O pedido foi trocar o particionamento para `(dia, operadora_id)`. Implementei exatamente isso
(`outputs/viagens.sql`), mas registro uma ressalva antes de considerar isso "resolvido":

**Particionar Delta por dia em uma tabela de ~50 GB que cresce ~2 GB/mês tende a piorar, não
melhorar, a performance**, por causa do small-file problem:

- ~2 GB/mês de dados novos, divididos por dia, dá ~65-70 MB/dia em média — e a query mais comum
  do domínio (bilhetagem) tem volume concentrado em dias úteis/horário de pico, então a
  distribuição real por dia é ainda mais desigual que a média.
- Combinado com `operadora_id` como segundo nível de partição, cada partição de dia se divide de
  novo por operadora. Se há múltiplas operadoras (típico em bilhetagem metropolitana — o schema
  tem `operadora_id` e `tenant_id` separados, sugerindo multi-operadora por tenant), o resultado é
  um número grande de partições muito pequenas (frequentemente < 10-50 MB cada).
- Partições Delta muito pequenas aumentam overhead de metadata (arquivo por partição, listagem do
  log de transação) e podem tornar os filtros mais lentos, não mais rápidos, além de aumentarem
  custo de `OPTIMIZE`/compactação recorrente.
- Regra prática usada no mercado para Delta/Databricks: particionamento físico só compensa quando
  cada partição tende a ficar na casa de centenas de MB a alguns GB; abaixo disso, prefira manter
  a tabela sem partição fina (ou particionada por um grão mais grosso, ex. mês) e usar
  `ZORDER BY` (ou Liquid Clustering, se a versão do Databricks Runtime suportar) nas colunas de
  filtro (`validado_em`, `operadora_id`) para data skipping, sem multiplicar arquivos pequenos.

## Recomendação

Duas alternativas ao pedido literal, para decisão humana (não apliquei nenhuma das duas sem
confirmação, porque o pedido foi explícito sobre "por dia"):

1. **Particionar por mês + ZORDER**: `PARTITIONED BY (data_validacao_mes)` (coluna gerada,
   `date_trunc('month', validado_em)` ou `DATE_FORMAT(validado_em, 'yyyy-MM')`) e
   `OPTIMIZE gold.viagens ZORDER BY (operadora_id, validado_em)`. Mantém partições na casa de
   ~2 GB/mês (saudável) e ainda dá pruning eficiente por operadora e por data dentro do mês.
2. **Sem partição física, só ZORDER/clustering**: em 50 GB, Databricks recomenda avaliar se vale a
   pena particionar. `OPTIMIZE gold.viagens ZORDER BY (operadora_id, validado_em)` (ou
   `CLUSTER BY (operadora_id, validado_em)` com Liquid Clustering, se disponível) costuma superar
   partição por dia neste volume, e simplifica manutenção (sem explosão de diretórios).

Implementei o pedido original (dia + operadora) em `outputs/viagens.sql` e `outputs/migration.sql`
porque foi uma instrução explícita e não uma pergunta aberta, mas a ressalva acima deveria ir para
quem pediu antes do corte em produção — o risco é trocar um problema de performance por outro, e a
migração (CTAS reescrevendo 50 GB) tem custo real para reverter se a escolha se mostrar ruim.

## services/validador — achados

- `main.go` é um stub sem lógica de escrita, storage, ou path do Delta. Não há nada no serviço que
  precise mudar por causa do reparticionamento — reparticionar uma tabela Delta gerenciada por
  `PARTITIONED BY` não exige mudança no escritor quando a escrita é via Spark/SQL padrão (o motor
  decide o arquivo/partição de destino a partir dos valores das colunas, não de um path hardcoded
  no cliente).
- Ponto em aberto: o comentário do arquivo (linha 5) diz que o validador grava no tópico
  `viagens.validadas`, sugerindo que a escrita em `gold.viagens` acontece em outro componente
  (job de streaming Spark/DLT lendo desse tópico), que não está neste repositório. Não encontrei
  esse componente para revisar. Se ele existir e usar `INSERT`/`MERGE` com paths ou partições
  hardcoded (em vez de deixar o Delta/Spark resolver a partição pelos valores da linha), essa é a
  peça que realmente precisaria de revisão antes do corte — recomendo localizar esse job antes de
  aplicar a migração em produção.
- Nenhuma mudança de código foi feita em `services/validador` — não havia lógica relacionada ao
  particionamento para ajustar.

## O que eu faria a seguir (não executado, fora do escopo desta rodada)

- Rodar `DESCRIBE DETAIL gold.viagens` e `DESCRIBE HISTORY gold.viagens` reais para confirmar
  distribuição atual de tamanho de arquivo por partição, em vez de estimar a partir do DDL.
- Rodar a migração primeiro em staging com uma amostra, medindo tempo e tamanho de arquivo
  resultante por partição, antes de aplicar em produção.
- Confirmar com o time se existe SLA de retenção/tempo real (streaming) que dependa do path atual
  de partição (ex.: jobs downstream que fazem `read.format("delta").load(".../operadora_id=X")`
  direto no path físico em vez de via tabela registrada — comum em ambientes legados e que quebra
  silenciosamente com reparticionamento).
